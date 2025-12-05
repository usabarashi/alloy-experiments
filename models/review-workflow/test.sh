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

while read -r idx token kind name _; do
  idx=${idx%.}
  [[ $idx =~ ^[0-9]+$ ]] || continue
  actual_kind=$kind
  actual_name=$name
  if [[ "$token" != "." ]]; then
    actual_kind=$token
    actual_name=$kind
  fi
  case "$actual_kind" in
    Run)   CMD_KIND+=("run") ;;
    Check) CMD_KIND+=("check") ;;
    *)     continue ;;
  esac
  CMD_IDX+=("$idx")
  CMD_NAME+=("$actual_name")
done < "$cmd_list"

if [[ ${#CMD_IDX[@]} -eq 0 ]]; then
  echo "No commands defined in $MODEL"
  exit 1
fi

status=0

print_entry() {
  local status=$1
  local name=$2
  local detail=$3
  printf '  %s  %s\n' "$status" "$name"
  printf '        %s\n' "$detail"
}

print_trace() {
  local idx=$1
  local tmpfile
  tmpfile=$(mktemp)
  if alloy6 exec -c "$idx" -r 1 -o - -t text "$MODEL" > "$tmpfile"; then
    sed 's/^/        /' "$tmpfile"
  else
    echo "        (failed to capture counterexample trace)"
  fi
  rm -f "$tmpfile"
}

run_command() {
  local idx=$1 name=$2
  local status_label detail
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    rm -rf "$tmpdir"
    status_label="FAIL"
    detail="execution failed"
    print_entry "$status_label" "$name" "$detail"
    status=1
    return
  fi
  local solution_count
  solution_count=$(jq -r --arg name "$name" '(.commands[$name].solution // []) | length' "$tmpdir/receipt.json")
  if [[ $solution_count -gt 0 ]]; then
    status_label="PASS"
    detail=$(printf 'SAT (%s instance%s)' "$solution_count" "$([[ $solution_count -eq 1 ]] && echo "" || echo "s")")
  else
    status_label="FAIL"
    detail="UNSAT"
    status=1
  fi
  print_entry "$status_label" "$name" "$detail"
  rm -rf "$tmpdir"
}

check_command() {
  local idx=$1 name=$2
  local status_label detail
  local tmpdir
  tmpdir=$(mktemp -d)
  if ! alloy6 exec -c "$idx" -o "$tmpdir" -t json "$MODEL" > /dev/null 2>&1; then
    rm -rf "$tmpdir"
    status_label="FAIL"
    detail="execution failed"
    print_entry "$status_label" "$name" "$detail"
    status=1
    return
  fi
  local solution_count
  solution_count=$(jq -r --arg name "$name" '(.commands[$name].solution // []) | length' "$tmpdir/receipt.json")
  if [[ $solution_count -eq 0 ]]; then
    status_label="PASS"
    detail="No counterexample"
    print_entry "$status_label" "$name" "$detail"
  else
    status_label="FAIL"
    detail=$(printf 'Counterexample (%s instance%s)' "$solution_count" "$([[ $solution_count -eq 1 ]] && echo "" || echo "s")")
    print_entry "$status_label" "$name" "$detail"
    print_trace "$idx"
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
