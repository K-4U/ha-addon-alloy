#!/usr/bin/env bash
# Renders and validates the add-on's Alloy config for every fixture in tests/options,
# with and without host access, plus the extra-config handling.
#
#   tests/run.sh <image>
#
# Fixtures named fail-*.json must be rejected; every other fixture must validate.
set -uo pipefail

image="$1"
tests="$(cd "$(dirname "$0")" && pwd)"
failures=0

# On Git Bash for Windows, keep container paths like /data as they are,
# and give Docker Windows paths for the host side of mounts
export MSYS_NO_PATHCONV=1
host_path() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi; }

check() { # check <options.json> <host access> [extras dir]
  local args=(--rm
    -e ALLOY_COLLECTOR_HOSTNAME=ci
    -e "ALLOY_COLLECTOR_HOST_ACCESS=$2"
    -v "$(host_path "$1"):/data/options.json:ro")
  if [[ -n "${3:-}" ]]; then args+=(-v "$(host_path "$3"):/config:ro"); fi
  docker run "${args[@]}" "$image" check
}

pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }

for options in "$tests"/options/*.json; do
  name="$(basename "$options" .json)"
  for host_access in true false; do
    label="$name (host access: $host_access)"
    if output="$(check "$options" "$host_access" 2>&1)"; then
      if [[ "$name" == fail-* ]]; then fail "$label: was accepted"; else pass "$label"; fi
    else
      if [[ "$name" == fail-* ]]; then pass "$label: rejected"; else fail "$label"; echo "$output" | sed 's/^/      /'; fi
    fi
  done
done

# Extra .alloy files: a valid one loads, an invalid one is reported (exit code 2)
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/valid" "$work/invalid"
cp "$tests/extras/valid.alloy" "$work/valid/"
cp "$tests/extras/invalid.alloy" "$work/invalid/"

if output="$(check "$tests/options/defaults.json" true "$work/valid" 2>&1)"; then
  pass "valid extra config"
else
  fail "valid extra config"; echo "$output" | sed 's/^/      /'
fi

check "$tests/options/defaults.json" true "$work/invalid" >/dev/null 2>&1
code=$?
if [[ $code -eq 2 ]]; then pass "invalid extra config: reported"; else fail "invalid extra config: exit code $code, expected 2"; fi

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All checks passed"
