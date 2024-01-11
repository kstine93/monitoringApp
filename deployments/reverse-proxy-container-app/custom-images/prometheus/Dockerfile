FROM prom/prometheus:v2.47.2
ADD prometheus.yml /etc/prometheus

ENTRYPOINT [ "prometheus", \
    "--config.file=/etc/prometheus/prometheus.yml", \
    "--storage.tsdb.path=/prometheus", \
    "--web.external-url=/prometheus/", \
    "--web.route-prefix=/prometheus/", \
    "--storage.tsdb.no-lockfile" ]