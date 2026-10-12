#!/usr/bin/env bash
# Runs inside the add-on image (tests/ mounted at /tests): one frigate-targets cycle against the
# canned Supervisor responses in tests/supervisor/api, then checks the target file.
set -uo pipefail

export PATH="/tests/supervisor/bin:$PATH"
file=/tmp/frigate-targets.json

frigate-targets "$file" 3600 2>/tmp/frigate-errors.txt &
for _ in $(seq 50); do
  [[ -f "$file" ]] && break
  sleep 0.2
done
kill %1 2>/dev/null

expected='[{"targets":["172.30.33.4:5000"],"labels":{"container":"app_ccab4aaf_frigate-fa","service":"frigate-fa"}}]'
# Only the started Frigate add-on: not the stopped one, nor an add-on that merely has frigate in its slug
if [[ "$(cat "$file")" == "$expected" ]]; then
  echo "ok    frigate targets"
else
  echo "FAIL  frigate targets: got $(cat "$file")"
  exit 1
fi
