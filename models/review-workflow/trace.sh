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

RUN_CMDS=()
CHECK_CMDS=()
while read -r idx dot kind name _; do
  [[ $idx =~ ^[0-9]+$ ]] || continue
  case "$kind" in
    Run)   RUN_CMDS+=("$idx:$name") ;;
    Check) CHECK_CMDS+=("$idx:$name") ;;
    *)     continue ;;
  esac
done < <(alloy6 commands "$MODEL")

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
  echo "  - Executing $name (command #$idx)..."
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    echo "    ✗ Failed to execute $name" >&2
    rm -rf "$tmpdir"
    continue
  fi
  rows=$(extract_rows "$tmpdir/receipt.json" "$name")
  {
    echo "## $name"
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
  rm -rf "$tmpdir"
done

if [[ ${#CHECK_CMDS[@]} -gt 0 ]]; then
  echo >> "$tmpfile"
  echo "## Assertion Counterexamples" >> "$tmpfile"
  echo >> "$tmpfile"
  counterexamples_written=0
  for entry in "${CHECK_CMDS[@]}"; do
    IFS=: read -r idx name <<< "$entry"
    echo "  - Checking $name for counterexamples (command #$idx)..."
    tmpdir=$(mktemp -d)
    if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
      echo "    ✗ Failed to execute $name" >&2
      rm -rf "$tmpdir"
      continue
    fi
    solution_count=$(jq -r --arg cmd "$name" '(.commands[$cmd].solution // []) | length' "$tmpdir/receipt.json")
    if [[ $solution_count -eq 0 ]]; then
      rm -rf "$tmpdir"
      echo "    ✓ No counterexample found"
      continue
    fi
    rows=$(extract_rows "$tmpdir/receipt.json" "$name")
    rm -rf "$tmpdir"
    counterexamples_written=1
    {
      echo "### $name"
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
    echo "    → Counterexample appended to markdown"
  done
  if [[ $counterexamples_written -eq 0 ]]; then
    echo "_No assertion counterexamples found within the explored scope._" >> "$tmpfile"
    echo >> "$tmpfile"
  fi
fi

mv "$tmpfile" "$OUTPUT"
echo "Traces saved to $OUTPUT (including assertion counterexamples when present)"
