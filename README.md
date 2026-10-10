# Alloy Collector for Home Assistant

A Home Assistant app (add-on) that sends Home Assistant's logs and metrics to Loki and Prometheus, using [Grafana Alloy](https://grafana.com/docs/alloy/latest/).

- **Logs:** the host journal, which covers Home Assistant, the Supervisor, every add-on and the OS
- **Host metrics:** CPU, memory, disks and network of the Home Assistant machine
- **Container metrics:** CPU, memory, network and disk usage of Home Assistant, the Supervisor and every add-on

Every log line and metric gets a `host` label and, optionally, an `owner` label. Logs and container metrics also get `container` and `service` labels, so one Grafana dashboard can filter both.

New Grafana Alloy versions are picked up automatically: each Alloy update is validated, merged and released as a new add-on version.

## Installation

1. In Home Assistant, go to **Settings → Apps → App store**. Open the **⋮** menu → **Repositories** and add `https://github.com/K-4U/ha-addon-alloy`.
2. Install **Alloy Collector**.
3. In the **Configuration** tab, set at least the **Loki URL** and/or the **Prometheus URL**.
4. Start it and check the **Log** tab.

Options, labels and extra configuration are described in [alloy_collector/DOCS.md](alloy_collector/DOCS.md), which is also shown in the app's **Documentation** tab.

Supported: Home Assistant OS on `amd64` and `aarch64`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
