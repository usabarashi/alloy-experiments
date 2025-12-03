#!/usr/bin/env bash
set -euo pipefail
MODEL=${1:-model.als}
if [[ ! -f "$MODEL" ]]; then
  echo "Model file not found: $MODEL" >&2
  exit 1
fi
cmd_list=$(mktemp)
trap 'rm -f "$cmd_list"' EXIT
alloy6 commands "$MODEL" > "$cmd_list"

declare -a CMD_IDX=()
declare -a CMD_NAME=()
declare -a CMD_KIND=()

while read -r idx dot kind name _; do
  [[ $idx =~ ^[0-9]+$ ]] || continue
  case "$kind" in
    Run)   CMD_KIND+=("run") ;;
    Check) CMD_KIND+=("check") ;;
    *)     continue ;;
  esac
  CMD_IDX+=("$idx")
  CMD_NAME+=("$name")
done < "$cmd_list"

if [[ ${#CMD_IDX[@]} -eq 0 ]]; then
  echo "No commands defined in $MODEL"
  exit 1
fi

status=0

run_command() {
  local idx=$1 name=$2
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    rm -rf "$tmpdir"
    printf '  [%02d] %-30s ✗ failed to execute\n' "$idx" "$name"
    status=1
    return
  fi
  local solution_count
  solution_count=$(jq -r --arg name "$name" '(.commands[$name].solution // []) | length' "$tmpdir/receipt.json")
  if [[ $solution_count -gt 0 ]]; then
    printf '  [%02d] %-30s ✓ SAT (%s instances)\n' "$idx" "$name" "$solution_count"
  else
    printf '  [%02d] %-30s ✗ UNSAT\n' "$idx" "$name"
    status=1
  fi
  rm -rf "$tmpdir"
}

check_command() {
  local idx=$1 name=$2
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    rm -rf "$tmpdir"
    printf '  [%02d] %-30s ✗ failed to execute\n' "$idx" "$name"
    status=1
    return
  fi
  local solution_count
  solution_count=$(jq -r --arg name "$name" '(.commands[$name].solution // []) | length' "$tmpdir/receipt.json")
  if [[ $solution_count -eq 0 ]]; then
    printf '  [%02d] %-30s ✓ No counterexample\n' "$idx" "$name"
  else
    printf '  [%02d] %-30s ✗ COUNTEREXAMPLE FOUND (%s instances)\n' "$idx" "$name" "$solution_count"
    alloy6 exec -c "$idx" -r 1 -o - -t text "$MODEL"
    status=1
  fi
  rm -rf "$tmpdir"
}

printed_run=0
for i in "${!CMD_IDX[@]}"; do
  if [[ ${CMD_KIND[$i]} == "run" ]]; then
    if [[ $printed_run -eq 0 ]]; then
      echo "=== Running Run Commands (Satisfiability) ==="
      printed_run=1
    fi
    run_command "${CMD_IDX[$i]}" "${CMD_NAME[$i]}"
  fi
done

printed_check=0
for i in "${!CMD_IDX[@]}"; do
  if [[ ${CMD_KIND[$i]} == "check" ]]; then
    if [[ $printed_check -eq 0 ]]; then
      echo
      echo "=== Running Check Commands (Assertions) ==="
      printed_check=1
    fi
    check_command "${CMD_IDX[$i]}" "${CMD_NAME[$i]}"
  fi
done
if [[ $status -eq 0 ]]; then
  echo
  echo "✓ All tests passed"
else
  echo
  echo "✗ Some tests failed"
  exit 1
fi
