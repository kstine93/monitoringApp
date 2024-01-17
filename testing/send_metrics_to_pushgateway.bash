#!/bin/bash

#------------
# This script is a demonstration of how to push metrics to the Prometheus push gateway using curl
#------------

#----------
#--CONFIG--
#----------
URL=https://bi-monitoring.cloudrizon.com/pushgateway

#Credentials for accessing the Prometheus Push Gateway:
PROM_USER=admin
PROM_PASSWORD='<<FIND PASSWORD IN 1PASSWORD'

#Name and job of the metric we want to push
JOB_NAME=my-batch-script-1
METRIC_NAME=error_count

#Metric Type and value:
#Read more about metric types here: https://prometheus.io/docs/concepts/metric_types/
METRIC_TYPE=gauge #counter / histogram / summary
METRIC_VALUE=3

METRIC_DESCRIPTION='Last reported number of errors from my batch script #1'

#--------
#--MAIN--
#--------
# Sending the metrics to the Prometheus Push Gateway:
# Note that the push gateway expects a binary data package. This can be created
# from a document, or from using `<<EOF` to create an inline document like this:
# More documentation: https://github.com/prometheus/pushgateway
cat <<EOF | curl -u $PROM_USER:$PROM_PASSWORD --data-binary @- $URL/metrics/job/$JOB_NAME
# TYPE $METRIC_NAME $METRIC_TYPE
# HELP $METRIC_NAME $METRIC_DESCRIPTION
$METRIC_NAME $METRIC_VALUE
EOF