#!/usr/bin/env bash
# Runs inside the add-on image (an options file at /data/options.json): applies the rendered
# loki.relabel "journal" rules to fake journal entries and checks container, service and level.
# discovery.relabel uses the same relabel engine, and shows its result in Alloy's API.
set -uo pipefail

alloy-collector check >/dev/null 2>&1
rules="$(awk '/^loki.relabel "journal" \{/{p=1; next} p&&/^\}/{exit} p&&!/forward_to/{print}' /run/alloy-collector/config/main.alloy)"
cat >/tmp/relabel.alloy <<EOF
discovery.relabel "t" {
  targets = [
    {case = "1", __journal_container_name = "homeassistant", __journal__systemd_unit = "docker.service", __journal_priority_keyword = "err"},
    {case = "2", __journal_container_name = "app_core_mosquitto", __journal_priority_keyword = "info"},
    {case = "3", __journal_container_name = "app_45df7312_zigbee2mqtt", __journal_priority_keyword = "err"},
    {case = "4", __journal_container_name = "hassio_supervisor", __journal_priority_keyword = "err"},
    {case = "5", __journal__systemd_unit = "systemd-journald.service", __journal_syslog_identifier = "systemd-journald", __journal_priority_keyword = "notice"},
    {case = "6", __journal_syslog_identifier = "kernel", __journal_priority_keyword = "warning"},
  ]
$rules
}
EOF
alloy run /tmp/relabel.alloy --server.http.listen-addr=127.0.0.1:12397 --storage.path=/tmp/relabel-storage >/tmp/alloy.log 2>&1 &
for _ in $(seq 50); do
  out="$(curl -s http://127.0.0.1:12397/api/v0/web/components/discovery.relabel.t 2>/dev/null)" && [[ "$out" == *exports* ]] && break
  sleep 0.2
done
results="$(echo "$out" | jq -c '.exports[] | select(.name == "output") | .value.value[] | [.value[] | {(.key): .value.value}] | add | {case, container, service, level}')"

failures=0
expect() { # expect <case> <container> <service> <level>; "-" = label absent
  local got want
  got="$(jq -r --arg c "$1" 'select(.case == $c) | [.container // "-", .service // "-", .level // "-"] | join(" ")' <<<"$results")"
  want="$2 $3 $4"
  if [[ "$got" == "$want" ]]; then echo "ok    case $1: $want"; else echo "FAIL  case $1: expected '$want', got '$got'"; failures=$((failures + 1)); fi
}
expect 1 homeassistant homeassistant -                 # stderr "err" priority is not used
expect 2 app_core_mosquitto mosquitto -
expect 3 app_45df7312_zigbee2mqtt zigbee2mqtt -
expect 4 hassio_supervisor supervisor -
expect 5 - systemd-journald notice                     # not a container: journal priority kept
expect 6 - kernel warning

exit $((failures > 0))
