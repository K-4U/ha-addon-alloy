#!/usr/bin/env bash
# Runs inside the add-on image (tests/ mounted at /tests, an options file at /data/options.json):
# pushes sample journal lines through the rendered loki.process "journal" block and checks the
# level label Alloy gives each one.
set -uo pipefail

alloy-collector check >/dev/null 2>&1
config=/run/alloy-collector/config/main.alloy

# The rendered loki.process "journal" block, sending to loki.echo instead of Loki
{
  awk '/^loki.process "journal" \{/{p=1} p{print} p&&/^\}/{exit}' "$config" |
    sed 's/forward_to = \[loki.write.default.receiver\]/forward_to = [loki.echo.out.receiver]/'
  cat <<'EOF'

loki.source.api "in" {
  http {
    listen_address = "127.0.0.1"
    listen_port    = 3501
  }
  forward_to = [loki.process.journal.receiver]
}

loki.echo "out" {}
EOF
} >/tmp/levels.alloy

alloy run /tmp/levels.alloy --server.http.listen-addr=127.0.0.1:12398 --storage.path=/tmp/levels-storage >/tmp/alloy.log 2>&1 &
for _ in $(seq 50); do
  curl -s -o /dev/null http://127.0.0.1:3501/ready && break
  sleep 0.2
done

push() { # push <labels json> <line>
  curl -s -XPOST http://127.0.0.1:3501/loki/api/v1/push -H 'Content-Type: application/json' \
    -d "$(jq -nc --argjson l "$1" --arg line "$2" '{streams: [{stream: $l, values: [[(now * 1e9 | floor | tostring), $line]]}]}')"
}
push '{"container":"homeassistant","t":"1"}' $'\e[33m2026-10-11 00:26:24.334 WARNING (MainThread) [homeassistant.components.camera] Updating camera took longer\e[0m'
push '{"container":"hassio_supervisor","t":"2"}' '2026-10-11 00:26:24.334 INFO (MainThread) [supervisor.api] something about an error'
push '{"container":"app_core_mosquitto","t":"3"}' '2026-10-11 00:26:24: New connection from 172.30.32.1'
push '{"container":"app_local_x","t":"4"}' '[00:26:24] ERROR: Something failed'
push '{"service":"systemd-journald","level":"notice","t":"5"}' 'Journal started'
push '{"container":"app_b9845f46_govee2mqtt","t":"6"}' $'[2026-10-11T00:27:56 \e[32mINFO \e[0m govee::commands::serve] Querying API'
push '{"container":"app_45df7312_zigbee2mqtt","t":"7"}' $'[2026-10-11 01:07:31] \e[32minfo\e[39m: \tz2m:mqtt: MQTT publish: topic \'zigbee2mqtt/Valje\''
push '{"container":"app_45df7312_zigbee2mqtt","t":"8"}' '[2026-10-11 01:07:31] error: 	z2m: Failed to ping Kitchen'
push '{"container":"app_77b740e0_alloy_collector","t":"9"}' 'ts=2026-10-10T22:23:16.77Z level=info msg="ERROR is just a word here" component_id=x'
push '{"container":"app_core_openthread_border_router","t":"10"}' '2d.18:45:17.668 [W] P-RadioSpinel-: Handle transmit done failed: ChannelAccessFailure'
push '{"container":"app_core_mosquitto","t":"11"}' '2026-10-11 00:31:26: Client 172.30.32.2 disconnected: connection error: timeout'

failures=0
expect() { # expect <t> <expected level, or "none">
  local line
  for _ in $(seq 25); do
    line="$(grep "component_id=loki.echo.out" /tmp/alloy.log | grep "t=\\\\\"$1\\\\\"")" && break
    sleep 0.2
  done
  if [[ "$2" == none ]]; then
    if [[ -n "$line" && "$line" != *'level=\"'* ]]; then echo "ok    line $1: no level"; return; fi
  elif [[ "$line" == *"level=\\\"$2\\\""* ]]; then
    echo "ok    line $1: level=$2"; return
  fi
  echo "FAIL  line $1: expected level $2, got: ${line:-nothing}"
  failures=$((failures + 1))
}
expect 1 warning # HA core WARNING, despite colour codes
expect 2 info    # INFO line that mentions "error"
expect 3 none    # no level word: Loki detects it
expect 4 error
expect 5 notice  # not from a container: journal priority kept
expect 6 info    # level word right after a colour code (govee2mqtt)
expect 7 info    # Zigbee2MQTT, lowercase after the timestamp, with colour codes
expect 8 error   # Zigbee2MQTT error
expect 9 info    # logfmt level wins over a capitalised word in the message
expect 10 warning # OpenThread one-letter level
expect 11 none   # lowercase "error" inside a sentence doesn't count

exit $((failures > 0))
