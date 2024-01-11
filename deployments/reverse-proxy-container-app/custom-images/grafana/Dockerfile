FROM grafana/grafana:10.2.0

ENV GF_DEFAULT_APP_MODE development
ENV GF_LOG_LEVEL debug
#Note: the root URL defined below (particularly the subpath)
#must be aligned with the nginx reverse proxy path for Grafana:
ENV GF_SERVER_ROOT_URL http://bi-monitoring.mydomain.com/grafana
ENV GF_SERVER_SERVE_FROM_SUB_PATH true