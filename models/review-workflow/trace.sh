#!/usr/bin/env bash
set -euo pipefail

MODEL=${1:-model.als}
OUTPUT=${2:-traces.md}

if [[ ! -f "$MODEL" ]]; then
  echo "Model file not found: $MODEL" >&2
  exit 1
fi

RUN_CMDS=()
while read -r idx dot kind name _; do
  [[ $idx =~ ^[0-9]+$ ]] || continue
  [[ $kind == "Run" ]] || continue
  RUN_CMDS+=("$idx:$name")
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
  rows=$(jq -r --arg cmd "$name" '
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
    ' "$tmpdir/receipt.json")
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

mv "$tmpfile" "$OUTPUT"
echo "Traces saved to $OUTPUT"
