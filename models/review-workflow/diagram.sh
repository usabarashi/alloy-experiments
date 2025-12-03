#!/bin/bash
set -euo pipefail

MODEL_FILE="${1:-model.als}"
OUTPUT_DOT="diagram.dot"
OUTPUT_SVG="diagram.svg"

echo "Generating state transition diagram from Alloy model..."

# Dynamically detect Run commands defined in the model
echo "  1. Detecting Run commands..."
COMMANDS=()
while read -r idx dot kind name _; do
  if [[ "$idx" =~ ^[0-9]+$ ]] && [[ "$kind" == "Run" ]]; then
    COMMANDS+=("${idx}:${name}")
  fi
done < <(alloy6 commands "$MODEL_FILE")

if [ ${#COMMANDS[@]} -eq 0 ]; then
  echo "❌ No Run commands found in $MODEL_FILE. Add a run command (e.g., workflowSatisfiable) to extract transitions." >&2
  exit 1
fi

echo "     Detected commands: ${#COMMANDS[@]}"

echo "  2. Fetching transition scenarios from Alloy..."
echo "  3. Extracting state transitions..."

# Execute all commands, aggregate JSON, and transform to DOT with jq + awk
{
  for entry in "${COMMANDS[@]}"; do
    IFS=: read -r idx name <<< "$entry"
    echo "    - Executing $name (command #$idx)..." >&2
    alloy6 exec -c "$idx" -r 1 -o - -t json "$MODEL_FILE"
  done
} | jq -s -r '
def request_entries($values):
  ($values // {}) | to_entries | map(select(.key | test("^Request\\$")));
[ .[]
  | select(type == "object" and (.instances | length > 0))
  | (.instances | sort_by(.state)) as $states
  | reduce $states[] as $snapshot (
      {};
      reduce request_entries($snapshot.values)[]? as $req (
        .;
        .[$req.key] = ((.[$req.key] // []) + [{
          order: ($snapshot.state // 0),
          status: ($req.value.status[0][0]? // "Unknown"),
          event: ($req.value.lastEvent[0][0]? // "Unknown")
        }])
      )
    )
  | to_entries[]
  | .value as $timeline
  | ($timeline | sort_by(.order)) as $sorted
  | select(($sorted | length) > 1)
  | range(0; ($sorted | length) - 1) as $i
  | {
      from: $sorted[$i].status,
      to: $sorted[$i + 1].status,
      event: $sorted[$i + 1].event
    }
]
| unique_by("\(.from)_\(.to)_\(.event)")
| map({
    from: (.from | gsub("\\$[0-9]+"; "")),
    to: (.to | gsub("\\$[0-9]+"; "")),
    event: (.event | gsub("\\$[0-9]+"; ""))
  })
| .[]
| "\(.from)\t\(.to)\t\(.event)"
' | awk -F'\t' '
NF == 3 {
  edges[++edgeCount] = $0
  from = $1
  to = $2
  if (!seen[from]++) {
    states[++stateCount] = from
  }
  if (!seen[to]++) {
    states[++stateCount] = to
  }
}
END {
  print "digraph ReviewWorkflow {"
  print "  rankdir=LR;"
  print "  node [shape=box, style=rounded];"

  if (stateCount > 0) {
    printf "  "
    for (i = 1; i <= stateCount; ++i) {
      printf "%s%s", states[i], (i < stateCount ? "; " : ";")
    }
    print ""
    print ""
    print "  // Alloyから抽出された遷移"
    for (i = 1; i <= edgeCount; ++i) {
      split(edges[i], parts, "\t")
      from = parts[1]
      to = parts[2]
      event = parts[3]
      if (from == to) {
        printf "  %s -> %s [label=\"%s\", style=dotted];\n", from, to, event
      } else {
        printf "  %s -> %s [label=\"%s\"];\n", from, to, event
      }
    }
  } else {
    print ""
    print "  // No transitions extracted. Check Alloy run scopes or scenarios."
  }

  print "}"
}
' > "$OUTPUT_DOT"

if [ ! -s "$OUTPUT_DOT" ]; then
  echo "❌ Failed to generate DOT file" >&2
  exit 1
fi

echo "  4. Generating SVG image..."

# Generate SVG from DOT
if command -v dot >/dev/null 2>&1; then
  dot -Tsvg "$OUTPUT_DOT" -o "$OUTPUT_SVG"
  echo "✓ SVG generation completed: $OUTPUT_SVG"
else
  echo "⚠ Graphviz (dot) is not installed"
  echo "  DOT file generated: $OUTPUT_DOT"
  exit 1
fi

echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DOT" "$OUTPUT_SVG"
echo ""
echo "✓ State transition diagram generated from Alloy model"
