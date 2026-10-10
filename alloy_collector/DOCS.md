# Alloy Collector

Sends Home Assistant's logs and metrics to Loki and Prometheus, using [Grafana Alloy](https://grafana.com/docs/alloy/latest/).

## What it collects

| What | Where it goes | Needs |
|---|---|---|
| The host journal: Home Assistant, the Supervisor, every add-on and the OS | Loki | `loki_url` |
| Host metrics (`node_*`): CPU, memory, disks, network of the Home Assistant machine | Prometheus | `prometheus_url`; protection mode off for complete metrics |
| Container metrics (`ha_container_*`): CPU, memory, network and disk usage of Home Assistant, the Supervisor, its plugins and every started add-on | Prometheus | `prometheus_url` |

### Protection mode

With protection mode **on**, everything works, but host metrics only cover what the add-on's own container can see. CPU, memory, disk I/O and network are still the host's. Filesystems are limited to the ones mounted into the add-on, and process counts to the add-on's own.

With protection mode **off**, the add-on runs in the host's process namespace and reads the host's root filesystem, so every mount and process is included. The add-on log says which mode it's in when it starts.

## Labels

Every log line and metric gets:

- `host`: the **Host label** option, or Home Assistant's hostname when that's empty
- `owner`: the **Owner label** option; left out when that's empty

Logs also get:

- `container`: the raw container name, e.g. `homeassistant`, `hassio_supervisor`, `addon_core_mosquitto`
- `service`: a clean name. The container name without its prefix (`mosquitto`, `supervisor`, `homeassistant`), or the systemd unit without `.service` (`docker`), or the program name (`kernel`)
- `level`: the journal priority, e.g. `error`, `warning`, `info`
- `job`: `systemd-journal`

Container metrics get the same `container` and `service` labels, so one dashboard filter works for both.

## Options

- **Loki URL / Prometheus URL**: the servers to send logs and metrics to, e.g. `http://10.42.1.2:3100` and `http://10.42.1.2:9090`. The add-on adds the push paths itself (`/loki/api/v1/push` and `/api/v1/write`). Leave one empty to not send that kind of data.
- **Username / password**: basic auth, optional.
- **CA certificate, client certificate, client key**: TLS, optional. Put the files in Home Assistant's `ssl` folder and use paths like `/ssl/ca.pem`.
- **Skip TLS verification**: accept any certificate. Only for testing.
- **Collect logs / host metrics / container metrics**: turn each collector on or off.
- **Scrape interval**: how often metrics are collected, in seconds.
- **Log level**: Alloy's own log level.
- **Alloy UI port**: exposes Alloy's web UI on that port of the Home Assistant host. It shows every component and its health, which helps with debugging. Leave empty to keep it private.

## Extra configuration

Every `*.alloy` file in the add-on's config folder (`/addon_configs/<id>_alloy_collector/` from the Samba or SSH add-on) is loaded next to the add-on's own config. They can use the add-on's writers:

- `loki.write.default.receiver`, if a Loki URL is set
- `prometheus.remote_write.default.receiver`, if a Prometheus URL is set

For example, to also scrape an exporter running on the network:

```alloy
prometheus.scrape "my_exporter" {
  targets    = [{__address__ = "192.168.1.50:9100"}]
  forward_to = [prometheus.remote_write.default.receiver]
}
```

If the extra files don't validate, the add-on starts without them, so your logs and metrics keep flowing, and logs the errors. Restart the add-on after changing them.
