# BI-Monitoring

---

**NOTE ABOUT THIS PROJECT**
This project was originally set up to monitor data pipelines, databases and batch scripts that were running in a Business Intelligence context - and you will find most of the documentation in this project reflects that purpose.
However, this project can be adapted to set up centralized monitoring for any purpose.

---

## What is this project?
The BI Monitoring project includes all resources necessary to monitor applications, databases, data pipelines, etc. with a deployment of Prometheus, Prometheus Push Gateway, Grafana, and Nginx.

## Initial setup + configuration

### Choosing a deployment
This project is separated into separate 'deployments' which reflect different ways to get the application up-and-running. Most of these reflect simpler versions which are useful for testing.

**The** `reverse-proxy-portainer` **deployment reflects the current production version of this application**

Each deployment subdirectory contains the code necessary to deploy that version of the application. For example, the `local` deployment contains a `docker-compose.yaml` file for local deployment. Azure deployments will contain templates (e.g., ARM templates) for deploying related Azure resources.

**Please see the individual `README.md` files within these deployment folders for details on how to use or reconfigure that particular deployment.**

---

### Adding a custom domain with Azure DNS
Creating a custom domain (e.g., `bi-monitoring.mydomain.com`) makes it easier to access your application than an IP address, and additionally allows easier migration of your application (since connecting applications can still reference the same domain, which now might point to a new IP address).

To do this, you need to create a custom domain with a DNS service (e.g., Azure DNS Zones) and add the appropriate IP mappying.

If you're deploying in some Azure resources (e.g., Container Apps), you may need to use the 'Custom Domains' menu to add this custom domain as well, and add additional records to the DNS service (e.g., a TXT record for the verification token).

---

## Additional notes

### Persistent file storage for Container App deployments
The Azure Container Apps by default have only ephemeral storage - any data (e.g., dashboards, metrics) they collect during their lifecycle is lost upon re-deployment or failure of the Container App.
Since we want data to survive through redeployments or failures, persistent storage is needed.

To achieve that, the Storage Account ARM template included in the most current deployment of this system sets up the necessary Azure File Shares upon deployment - which can be used by the Container Apps for persistent storage.

If you are setting this system up manually or otherwise can't use the provided ARM template, see the step-by-step instructions for setting this up as [documented here](https://learn.microsoft.com/en-us/azure/container-apps/storage-mounts-azure-files?tabs=bash).

---

### Note: File storage for specific applications

> Which applications need persistent storage?
> - **nginx (reverse proxy deployment only): YES.** Nginx needs access to configuration and password authentication files.
>
> - **Prometheus Push Gateway: NO.** The push gateway is just a simple web server that accepts data pushed from external sources and exposes that data to Prometheus. Prometheus scrapes this data often, so as long as we persist Prometheus data, these metrics will be saved.
>
> - **Prometheus: YES.** Prometheus scrapes metrics and stores them locally. If we lose these data, we lose our history of metrics, which is valuable for analysis.
>
> - **Grafana: YES.** Grafana will be configured with dashboards, data sources and alerts. In the case of app failure, it's important these can be re-loaded. However, Grafana also offers *provisioning* - allowing a Grafana instance to load in configurations at startup as a way to persist data, rather than relying on backups of existing resources.


#### Prometheus
For our Prometheus application, we want to persist metrics data. Where Prometheus stores its data can be configured, but at the time of this documentation, it was stored at `/prometheus`.

For more information on Prometheus storage see [the documentation](https://prometheus.io/docs/prometheus/latest/storage/).

---

#### Grafana
For our Grafana application, we want to persist dashboards, alerts, and data sources so that Grafana can be reconfigured quickly in the case of failure. However, for some reason, Grafana can have difficulty setting up and using its SQLite database when its mounted on an external file store (likely due to file permissions).

Therefore, it was decided that rather than using the file share to *back up* Grafana data, we would instead use it to *provision* Grafana. In other words, specify what data sources, alerts, and dashboards we wanted in Grafana by provisioning these as template files as described in [this documentation](https://grafana.com/docs/grafana/latest/administration/provisioning/).


## Future upgrades
Ideally, this monitoring system will be upgraded in the future to allow for the following upgrades:
- Scaling & auto-reboot (e.g., as enabled when deploying on tools like Kubernetes)
- Log storage and analysis (e.g., as achieved with services like Grafana's "Loki")