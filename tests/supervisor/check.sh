#!/usr/bin/env bash
# Runs inside the add-on image (tests/ mounted at /tests): one supervisor-stats cycle against the
# canned Supervisor responses in tests/supervisor/api, then checks the output and parses it with
# the unix exporter's textfile collector.
set -uo pipefail

export PATH="/tests/supervisor/bin:$PATH"
out=/tmp/textfile
mkdir -p "$out"

supervisor-stats "$out" 3600 2>/tmp/stats-errors.txt &
for _ in $(seq 50); do
  [[ -f "$out/supervisor.prom" ]] && break
  sleep 0.2
done
kill %1 2>/dev/null

failures=0
has() { if grep -qxF "$1" "$out/supervisor.prom"; then echo "ok    has: $1"; else echo "FAIL  missing: $1"; failures=$((failures + 1)); fi; }
lacks() { if grep -q "$1" "$out/supervisor.prom"; then echo "FAIL  unexpected: $1"; failures=$((failures + 1)); else echo "ok    lacks: $1"; fi; }

# Running add-on: info, up and stats, with container/service/name labels
has 'ha_container_info{container="app_core_mosquitto",service="mosquitto",name="Mosquitto broker",state="started",version="6.4.1"} 1'
has 'ha_container_up{container="app_core_mosquitto",service="mosquitto",name="Mosquitto broker"} 1'
has 'ha_container_memory_usage_bytes{container="app_core_mosquitto",service="mosquitto",name="Mosquitto broker"} 20000000'
has 'ha_container_disk_write_bytes_total{container="app_core_mosquitto",service="mosquitto",name="Mosquitto broker"} 400'
# System container: version from its /info, fixed human name
has 'ha_container_info{container="homeassistant",service="homeassistant",name="Home Assistant Core",state="started",version="2026.10.1"} 1'
has 'ha_container_cpu_percent{container="homeassistant",service="homeassistant",name="Home Assistant Core"} 3.2'
# Stopped add-on: only info (quotes in the name escaped), no up and no stats
has 'ha_container_info{container="app_5c53de3b_esphome",service="esphome",name="ESPHome \"Device\" Builder",state="stopped",version="2026.9.0"} 1'
lacks 'ha_container_up{container="app_5c53de3b_esphome"'
lacks 'ha_container_cpu_percent{container="app_5c53de3b_esphome"'
# Running add-on whose stats call fails: up 0, no stats
has 'ha_container_up{container="app_local_broken",service="broken",name="Broken"} 0'
lacks 'ha_container_cpu_percent{container="app_local_broken"'
# Plugins without canned responses: up 0
has 'ha_container_up{container="hassio_audio",service="audio",name="Audio"} 0'

# The textfile collector must parse the file without errors
cat >/tmp/parse.alloy <<EOF
prometheus.exporter.unix "t" {
  set_collectors = ["textfile"]
  textfile {
    directory = "$out"
  }
}
EOF
alloy run /tmp/parse.alloy --server.http.listen-addr=127.0.0.1:12399 --storage.path=/tmp/parse-storage >/dev/null 2>&1 &
for _ in $(seq 50); do
  metrics="$(/usr/bin/curl -s http://127.0.0.1:12399/api/v0/component/prometheus.exporter.unix.t/metrics 2>/dev/null)" && [[ -n "$metrics" ]] && break
  sleep 0.2
done
if grep -qx 'node_textfile_scrape_error 0' <<<"$metrics"; then
  echo "ok    textfile collector parses the output"
else
  echo "FAIL  textfile collector could not parse the output"
  failures=$((failures + 1))
fi

exit $((failures > 0))
