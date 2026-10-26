# Dependabot bumps this line; a changed Alloy version triggers an automatic release
FROM grafana/alloy:v1.21.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /
RUN chmod +x /usr/local/bin/alloy-collector /usr/local/bin/supervisor-stats /usr/local/bin/frigate-targets

ENTRYPOINT ["/usr/local/bin/alloy-collector"]
CMD ["run"]

LABEL \
    org.opencontainers.image.title="Home Assistant App: Alloy Collector" \
    org.opencontainers.image.description="Ships Home Assistant logs and metrics to Loki and Prometheus with Grafana Alloy" \
    org.opencontainers.image.source="https://github.com/K-4U/ha-addon-alloy" \
    org.opencontainers.image.licenses="MIT"
