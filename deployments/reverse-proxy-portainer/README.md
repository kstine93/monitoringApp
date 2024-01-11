# Reverse Proxy Portainer deployment

This deployment of the BI monitoring tool uses Portainer to deploy and manage the following applications on a remote server:
- nginx (reverse proxy)
- prometheus
- grafana
- prometheus push gateway

This deployment uses a reverse proxy to allow access to the individual applications, while only exposing a single port to the internet (which routes to nginx).

## How to deploy
The deployment of resources on Portainer is relatively easy compared to deployment on Azure, for example. However, Portainer does not offer any Infrastructure-As-Code service beyond Docker Compose, so all configuration must be done manually. See the notes below for how to do this.

### 1. Log in to Portainer
Portainer is a tool for managing container-based applications running on external infrastructure (e.g., one of our Kubernetes clusters, or one of our remote Linux servers). It allows you to configure the Docker resources (e.g., Docker Compose) and volumes necessary for the deployment from its web interface.

### 2. Select which environment to deploy on
Portainer itself doesn't host your application - it deploys it on existing infrastructure that you have access to.

Currently, the BI Monitoring application is hosted on a remote Linux server. You can find currently-configured environments in Portainer listed on the Home page. Select this server to continue.

### 3. Add a new 'stack'
Stacks are groups of resources. Within the Portainer 'Stacks' menu (visible after selecting the environment in the previous step), create a new one using the 'Add stack' button. You will only need to paste or upload the Docker Compose file in this repo to complete the stack setup and deploy it.

Currently, the BI Monitoring tool stack is named `bi-monitoring` and uses the Docker Compose file found in this project repo.

> **IMPORTANT NOTE:** Grafana login credentials are set in Docker Compose. You may need to change this before deploying. Find the correct Grafana username and password in 1Password.

### 4. Add secrets to Grafana provisioned datasources
Within the files in this repo, you should find the file `grafana/datasources/default.yaml`.
This file holds information for Grafana about connecting to data sources.
Some of these data sources use authentication. You will need to add the passwords to this file before continuing to the next step.
```yaml
#-- EXAMPLE OF DATA SOURCE WITH AUTHENTICATION
  - name: PostgreSQL DB
    type: postgres
    url: postgres.mydomain.de:5432
    uid: fde92bf6-9372-492f-a833-4da6c019d9a6
    user: read_access_user
    secureJsonData:
      password: '<< PUT PASSWORD FOR DATA SOURCE HERE >>'
    jsonData:
      database: inhouse
      sslmode: 'disable' # disable/require/verify-ca/verify-full
      maxOpenConns: 10 # Grafana v5.4+
      maxIdleConns: 100 # Grafana v5.4+
      maxIdleConnsAuto: true # Grafana v9.5.1+
      connMaxLifetime: 14400 # Grafana v5.4+
      postgresVersion: 1300 # 903=9.3, 904=9.4, 905=9.5, 906=9.6, 1000=10
      timescaledb: false
```

### 5. Create Nginx authentication file with secure username and password
Nginx is (currently) configured to look for a `.htpasswd` file with user and password information - and use this information to allow (or restrict) access to parts of the application.

The application is currently using a username and password stored in 1Password under the name `BI Monitoring - Login - Prometheus + Push Gateway Basic Auth`.

---

This project repo has an `.htpasswd` file, but **the credentials stored in this file are only dummy credentials (username = 'admin', password = 'admin')**.
If you are deploying this project for the first time, you will need to create a new file with more secure credentials to use.

To do this, you can install the `htpasswd` utility on a Linux machine, and then genrate a new `.htpasswd` file with a new password using these instructions (replacing `my-username` and `my-password`):
```bash
apt-get install apache2-utils
htpasswd -c -b ./.htpasswd my-username my-password
```

The resulting file should look something like this:
```
admin:$apr1$1/CpE2Vu$UarBXehWEQ6QV5jVAqkPH0
kevin:$apr1$KBcwrl450CPpplUc32MlcoFdsle$0Jm
```

You can then upload this new `.htpasswd` file in the nginx volume in the following steps.

### 6. Add volumes
The BI Monitoring application relies on configuration files to work properly. Until you store these configuration files in the expected volumes, the application may not work as expected. You can add these within the Portainer web interface.

Using the Portainer menu, navigate to the 'Volumes' section of Portainer. There, you will see a list of currently-configured volumes for this environment.

The BI Monitoring tool currently uses 3 volumes (fewer are possible - 3 is just for organization purposes):
- `bi-monitoring-grafana` holds files which provision Grafana dashboards, data sources, and alerts
- `bi-monitoring-nginx` holds nginx configuration and password files (for redirecting and authenticating users)
- `bi-monitoring-prometheus` holds a Prometheus configuration file, as well as a subdirectory where Prometheus persists its metrics data

### 7. Creating volume subdirectories
Creating subdirectories is optional, but it's highly recommended that you do this to organize the files so that its easier to find and replace configuration files in the future as needed. Additionally, some Grafana features (like organizing dashboards) are only possible to do through this directory structure.

Portainer does not currently allow *direct creation* of subdirectories, but you can achieve this by specifying volumes in your Docker Compose.
For example, our `bi-monitoring-grafana` volume is mounted at `/var/lib/docker/volumes/bi-monitoring-grafana/_data`. We can create new directories within this volume by specifying them directly in the Docker compose like this:
```yaml
...
  #NOTE: THIS IS A TEMPORARY CONFIGURATION - NOT PRODUCTION-READY!!
  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana

    networks:
      - grafana
    volumes:
      - /var/lib/docker/volumes/bi-monitoring-grafana/_data/dashboards:/dummy-folder
...
```
By setting this configuration and updating the deployment, the new directory `dashboards` will be created within the volume. You can then remove this volume specification from the Docker Compose file and the directory will **not** disappear from the Portainer volume. Repeat this to create as many directories within the Portainer volumes as you like.

> Note: This is a strangely manual process and it's not currently clear why Portainer does not allow direct subdirectory creation in the volumes - this might be a new feature in Portainer in the future.

Currently, the BI Monitoring volumes have the current directory structure:
```
bi-monitoring-grafana/
├─ dashboards/
│  ├─ batch_script_monitoring/
│  ├─ data_pipelines/
│  ├─ databases/
├─ datasources/
├─ alerting/

bi-monitoring-nginx/
├─ auth/
├─ conf.d/
├─ html/

bi-monitoring-prometheus/
├─ prometheus/
```

For Grafana, the dashboards directory structure will reflect in how dashboards are organized within Grafana, but for the other applications, this organizational structure is less important.
*Note that the directory structure of this project repo is set up to mirror this Portainer volume directory structure to make organization easier.*

### 8. Add configuration files to the volumes
Once you have set up your volumes, you can add the configuration files for the application to these volumes.
In Portainer, this is as easy as selecting `browse` next to the volume name, navigating to the directory you want, and then clicking the upload file button.
The files are currently organized in this project repo according to which volume they should be in (and ideally, which subdirectory). For example, the file in this project repo at `reverse-proxy-portainer/nginx/conf.d/default.conf` should be uploaded to the nginx volume of Portainer, ideally under the subdirectory `conf.d`.

> **Note** - there is a direct relationship between how you store these volume files and what volume specifications you need to give in your Docker Compose. It's easy to retry if you misconfigure this, but keep in mind that if the application is not configured like you would expect, it's likely due to the application looking for the needed configuration file in the wrong place.

### 9. Redeploy the stack once volumes are fully set up
After you have added all of the configuration files to the volumes (and edited the volume specifications in the Docker Compose, if needed), you can redeploy the stack and the applications should be able to read their configuration files correctly.

You can edit the deployment anytime by editing the Docker Compose file and then updating the application.
Portainer also offers some handy tools for managing the individual containers for your application - including being able to individually restart the containers (handy if you change a configuration file for one of them) and seeing the logs of each container.

The application should now be reachable and function correctly through the exposed IP of the environment its running in.

### 10. Setting up HTTPS with the Nginx Proxy Manager
If the environment the application is running on does not offer a HTTPS-secured gateway, then you will need to set one up yourself (or accept that all of your communication with the application is unencrypted - which is not recommended). Your web browser should tell you clearly if the connection you have is secure or not.

There are ways to set up HTTPS yourself using the `certbot` application from LetsEncrypt, but its much easier to use a managed service like the Nginx Proxy Manager. Luckily, we already host this service - follow the next steps to set it up.

---

#### 10a. Set up a DNS record pointing to the Nginx Proxy Manager
For this step, you will need to have access to a DNS service that can assign a custom URL (e.g., `bi-monitoring.mydomain.com`) to your application's IP address. Azure offers a DNS service that can do this and this is how we currently sets up new DNS records for the `mydomain.com` domain.

Go to your DNS service and set up an `A`-type record so that your desired domain (e.g., `bi-monitoring.mydomain.com`) redirects to the IP address **of this Nginx Proxy Manager**. This allows traffic to your domain to go to the Nginx Proxy Manager. In the following steps, we will set up the Nginx Proxy Manager so that it redirects to your application.

---

#### 10b. Configure the Nginx Proxy Manager
1. Find the credentials for Nginx Proxy Manager.
2. Log in to the Nginx Proxy manager at this URL and using the 1Password credentials
3. Select 'Add proxy host' from the 'Proxy Hosts' page
4. In the 'Details' section of the pop-up window, configure these settings:
   1. Domain Names = `bi-monitoring.mydomain.com`
   2. Scheme = `http`
   3. Host = `XX.XX.XXX.XXX` (or the exposed IP of the environment your application is deployed on)
   4. Port = `80` (or whatever port you expect ingress to your application on)
   5. Turn on 'Block Common Exploits'
   6. Turn on 'Websockets Support'
5. In the 'SSL' section of the pop-up window, configure these settings:
   1. SSL Certificate = `Request a new SSL Certificate`
   2. Turn on 'Force SSL'
   3. Turn on 'HTTP/2 Support'
   4. Agree to the LetsEncrypt Terms of Service
6. Click 'Save' (note: if any required settings are blank, it will not allow you to save)

It might take a few seconds for the new proxy host to be created (as the Proxy Manager requests new certificates for your domain). After it's done, you should see your new proxy host as 'online'.


### 11. Test access
You have now set up the BI Monitoring tool on Portainer, and (hopefully) secured access with HTTPS.
You should now be able to access the tool via `bi-monitoring.mydomain.com` and, using the credentials in 1Password, access Grafana, Prometheus, and the Prometheus Push Gateway.

---

## How to monitor new systems using the BI-Monitoring tool

### With Prometheus
The BI Monitoring tool uses Prometheus to track metrics. Prometheus works by *pulling* metrics from a endpoint that your applications host. This typically means that applications need to run a sidecar webhost that exposes this endpoint, so that Prometheus can track them.
Since Prometheus is designed explicitly for this purpose, this is often the most powerful way to monitor - and which supports the most types of metrics.

There are [client libraries](https://prometheus.io/docs/instrumenting/clientlibs/) written in different languages for setting this up. These are your best resource for getting started with monitoring a new application.

However, It is not always possible or worth the time to set up a sidecar application in this way, so there are a few other tools for monitoring as well.

### With Prometheus Push Gateway
The Prometheus Push Gateway is a way for Prometheus to gather metrics from temporary processes (e.g., batch scripts).

The `testing` directory in the highest level of this project repo also offers some sample code.

### With Grafana
Grafana is not really set up for long-term monitoring in the way that Prometheus is (e.g., it doesn't support historical data storage), but it is a way to set up monitoring for applications where none of the other options are feasible - such as databases where we do not have direct access to the underlying OS to set up a monitoring endpoint.
In these cases, the entire configuration of how these applications are monitored exists only within Grafana, and can be found in the provisioned Grafana files in this project repo.

---

## How to set up alerting for monitored applications
Alerting when applications exhibit undesired behavior is probably the most useful feature of this monitoring application.
Currently, alerts are set up in Grafana. To set up a new alert, it's recommended that you first duplicate an existing alert within the Grafana web interface, then change it to suit your needs. See Grafana's official documentation for tips on configuring alerts.

>**WARNING:** for your new alert to persist if Grafana restarts, it **MUST** be added to the `default.yaml` file within the `alerting` directory (both in this project repo and in the Portainer volume).

---

## How to set up other Grafana resources
All Grafana dashboards, data sources, and alerts can be set up manually within the Grafana web interface, but in order for them to survive the container restarting, they **MUST** also be set up in the provisioned files.

- For dashboards, a new dashboard `.json` file must be created for each dashboard (and organized in the directory you want).
- For data sources, a new record must be added to the existing `default.yaml` file within the `datasources` directory.
- For alerts, a new record must be added to the existing `default.yaml` file within the `alerting` directory.