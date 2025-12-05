#!/usr/bin/env bash
set -euo pipefail

MODEL=${1:-model.als}
OUTPUT=${2:-traces.md}

if [[ ! -f "$MODEL" ]]; then
  echo "Model file not found: $MODEL" >&2
  exit 1
fi

extract_rows() {
  local receipt=$1
  local cmd=$2
  jq -r --arg cmd "$cmd" '
      def first_value($field):
        if has($field) then
          .[$field] as $val |
          if ($val | type) == "array" and ($val | length) > 0 then
            $val[0] as $first |
            if ($first | type) == "array" and ($first | length) > 0 then $first[0] else $first end
          else "-"
          end
        else "-"
        end;
      def clean:
        if . == "-" then "-" else sub("\\$[0-9]+$";"") end;
      .commands[$cmd].solution[0].instances
      | select(. != null)
      | to_entries[]
      | . as $entry
      | ($entry.value.values
         | to_entries
         | map(select(.key|test("^Request\\$[0-9]+$")))
         | first?
         | .value) as $req
      | select($req != null)
      | {
          step: ($entry.value.state // $entry.key),
          status: ($req | first_value("status") | clean),
          event: ($req | first_value("lastEvent") | clean),
          assignee: ($req | first_value("assignedTo") | clean)
        }
      | "| \(.step) | \(.status) | \(.event) | \(.assignee) |"
    ' "$receipt"
}

render_table() {
  local title=$1
  local level=$2
  local rows=$3
  local heading
  printf -v heading '%*s' "$level" ''
  heading=${heading// /#}
  {
    printf "%s %s\n" "$heading" "$title"
    echo
    echo "| Step | Status | Event | Assigned To |"
    echo "|------|--------|-------|-------------|"
    if [[ -n "$rows" ]]; then
      printf "%s\n" "$rows"
    else
      echo "| - | - | - | - |"
    fi
    echo
  } >> "$tmpfile"
}

collect_commands() {
  while read -r idx token kind name _; do
    idx=${idx%.}
    [[ $idx =~ ^[0-9]+$ ]] || continue
    local actual_kind=$kind
    local actual_name=$name
    if [[ "$token" != "." ]]; then
      actual_kind=$token
      actual_name=$kind
    fi
    case "$actual_kind" in
      Run)   RUN_CMDS+=("$idx:$actual_name") ;;
      Check) CHECK_CMDS+=("$idx:$actual_name") ;;
      *)     continue ;;
    esac
  done < <(alloy6 commands "$MODEL")
}

execute_run() {
  local idx=$1 name=$2
  echo "  - Executing $name (command #$idx)..."
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    echo "    ✗ Failed to execute $name" >&2
    rm -rf "$tmpdir"
    return
  fi
  local rows
  rows=$(extract_rows "$tmpdir/receipt.json" "$name")
  render_table "$name" 2 "$rows"
  rm -rf "$tmpdir"
}

execute_check() {
  local idx=$1 name=$2
  echo "  - Checking $name for counterexamples (command #$idx)..."
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    echo "    ✗ Failed to execute $name" >&2
    rm -rf "$tmpdir"
    return
  fi
  local solution_count
  solution_count=$(jq -r --arg cmd "$name" '(.commands[$cmd].solution // []) | length' "$tmpdir/receipt.json")
  if [[ $solution_count -eq 0 ]]; then
    rm -rf "$tmpdir"
    echo "    ✓ No counterexample found"
    return
  fi
  local rows
  rows=$(extract_rows "$tmpdir/receipt.json" "$name")
  rm -rf "$tmpdir"
  counterexamples_written=1
  render_table "$name" 3 "$rows"
  echo "    → Counterexample appended to markdown"
}

RUN_CMDS=()
CHECK_CMDS=()
collect_commands

if [[ ${#RUN_CMDS[@]} -eq 0 ]]; then
  echo "No Run commands defined in $MODEL" >&2
  exit 1
fi

echo "Generating markdown traces from ${#RUN_CMDS[@]} Run commands..."

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

{
  echo "# ReviewWorkflow Run Traces"
  echo
  echo "_Generated from $(basename "$MODEL") on $(date -u +"%Y-%m-%d %H:%M:%SZ")_"
  echo
} > "$tmpfile"

for entry in "${RUN_CMDS[@]}"; do
  IFS=: read -r idx name <<< "$entry"
  execute_run "$idx" "$name"
done

if [[ ${#CHECK_CMDS[@]} -gt 0 ]]; then
  echo >> "$tmpfile"
  echo "## Assertion Counterexamples" >> "$tmpfile"
  echo >> "$tmpfile"
  counterexamples_written=0
  for entry in "${CHECK_CMDS[@]}"; do
    IFS=: read -r idx name <<< "$entry"
    execute_check "$idx" "$name"
  done
  if [[ $counterexamples_written -eq 0 ]]; then
    {
      echo "_No assertion counterexamples found within the explored scope._"
      echo
    } >> "$tmpfile"
  fi
fi

mv "$tmpfile" "$OUTPUT"
echo "Traces saved to $OUTPUT (with assertion counterexamples when present)"
