# Reverse Proxy Container App deployment

This deployment of the BI monitoring tool uses a single Azure Container App instance to run the following applications:
- nginx (reverse proxy)
- prometheus
- grafana
- prometheus push gateway

This deployment uses a reverse proxy (routed through nginx) to allow access to the individual applications, while only exposing a single port on the Container App (which routes to nginx).

## How to deploy
Steps to deploy the 'Reverse Proxy' version of teh BI monitoring tool.

### 1. Make an Azure Resource Group
Make an Azure Resource Group. This can be easily done with the Azure web interface. Leave the settings as the default.

### 2. Create the Azure Container Registry
Within this directory you will find ARM templates for Azure resources. Find and deploy the ARM template for the Azure Container Registry into the Azure Resource Group you just created.

### 3. Add custom images to the Azure Container Registry
This monitoring application requires custom images of 4 applications to run. To build and push the images to the Azure Container Registry, you can use the `image-builder.bash` script included alongside this code.

Follow these steps:
1. Check within the `image-builder.bash` script that the `AZUREREGISTRY` variable reflects the name of the Azure Container Registry you are using.
2. Push a custom image to the Azure Registry using the code below as a guide (note that image names must align with those in the Container App ARM template):
```bash
#Grafana:
bash image-builder.bash deployments/reverse-proxy-container-app/custom-images/grafana grafana-custom:latest

#Prometheus:
bash image-builder.bash deployments/reverse-proxy-container-app/custom-images/prometheus prometheus-custom:latest

#Prometheus Push Gateway
bash image-builder.bash deployments/reverse-proxy-container-app/custom-images/prom-pushgateway prom-pushgateway-custom:latest

#Nginx
bash image-builder.bash deployments/reverse-proxy-container-app/custom-images/nginx nginx-custom:latest
```

### 4. Create the Azure Storage Account
Within this directory you will find ARM templates for Azure resources. Find and deploy the ARM template for the Azure Storage Account into the Azure Resource Group you just created.

### 5. Add secrets to Grafana provisioned datasources
Within the files in this deployment, you should find the file `/provisioning/grafana/alerting/default.yaml`.
This file holds information for Grafana about connecting to data sources.
Some of these data sources use authentication. You will need to add the passwords to this file before continuing to the next step.
```yaml
#-- EXAMPLE OF DATA SOURCE WITH AUTHENTICATION
  - name: PostgreSQL DB
    type: postgres
    url: my-postgres-instance.com:5432
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

### 6. Add Grafana provisioned resources to the Azure Storage Account
Navigate to the 'File shares' section of the Storage Account you just created. You should see a file share called `bi-monitoring-grafana`. Select this file share and add the following directories to it:
- `dashboards`
- `datasources`
- `alerting`

Within each of these directories, upload files for Grafana from the local directory `/provisioning/grafana`. The local directory structure should mirror the desired final structure of the directories in the file share (e.g., if the `dashboards` directory locally has subdirectories, these should be present in the file share too).

### 7. Add Nginx basic authentication to the Azure Storage Account
Navigate to the 'File shares' section of the Storage Account you just created. You should see a file share called `bi-monitoring-nginx`.
Nginx is (currently) configured to look within this file share for a file with user and password information and use this information to allow (or restrict) access to the application.

Upload a file to this file share with the name `.htpasswd`. The contents of the file should be at least one username and obscured password, and look something like this:
```
admin:$apr1$1/CpE2Vu$UarBXehWEQ6QV5jVAqkPH0
kevin:$apr1$KBcwrl450CPpplUc32MlcoFdsle$0Jm
```

To add additional passwords, you can install the `htpasswd` utility on a Linux machine, and then genrate a new `.htpasswd` file with a new password using these instructions:
```bash
apt-get install apache2-utils
htpasswd -c -b ./.htpasswd my-username my-password
```


### 8. Add secrets to the Container App ARM template
The Container App ARM template currently requires secrets to be able to access the Azure Container Registry and the Azure Storage Account that were created in the previous steps. You will need to edit the ARM template files to add these values before you deploy the ARM template.

For the Storage Account access, an **Access Key** from the Storage Account should be added to the `parameters.json` file next to the value `storageAccountKey`.
```json
...
"azureContainerRegistryUrl":{
    "value": "myregistry.azurecr.io/bi-monitoring/"
},
"storageAccountKey": {
    "value": "PUT YOUR STORAGE ACCOUNT ACCESS KEY HERE"
},
"prometheusFileShareName": {
    "value": "bi-monitoring-prometheus"
},
...
```

For the Container Registry access, a **password** from the Container Registry (stored under "Access Keys" submenu) should be added to the `parameters.json` file within the `secrets` section - as in the code below.

The password (and optionally, username) for Grafana should be similarly set this way.
```json
...
"secrets": {
    "value": {
        "arrayValue": [
            {
                "name": "reg-pswd-da21b024-8ced",
                "value": "<< PUT CONTAINER REGISTRY ACCESS KEY HERE >>"
            },
            {
                "name": "grafana-username",
                "value": "admin"
            },
            {
                "name": "grafana-password",
                "value": "<< PUT GRAFANA PASSWORD HERE >>"
            }
        ]
    }
}
...
```

### 9. Create the Azure Container App
Now that you have added the new secrets values to the Container App ARM template in the previous step, you can deploy this ARM template to the Resource Group.

---

## Troubleshooting & Notes:

### Dependencies between ARM templates
Note that the Azure resources deployed in this version depend on one another. You will need to ensure that values are all consistent across your ARM templates or the deployment could fail.
The following resources should be checked that they have the *same value* in all ARM templates:
- location
- storageAccountName
- prometheusFileShareName
- grafanaFileShareName
- nginxFileShareName

Additionally, for the **Container App ARM template**, these resource names should be double-checked:
- Azure subscription ID (alphanumeric code showing which Azure subscription you're deploying to)
- Resource Group (within connection string under 'environmentId')
- storageAccountKey (used for accessing Storage Account file share)
- The server, username and password of the Azure Container Registry

### Contention for Prometheus data with multiple replicas
Container Apps by default can scale to have multiple replicas. For the current application, only one replica of each application is needed, and in the case of Prometheus having more than one replica online can cause failure of one of the Prometheus images if both images reference the same File Share.

The reason for this is that Prometheus implements a 'lock' on its data to ensure the integrity of data writing and reading since multiple writers could cause data corruption.

**In conclusion, ensure that only one replica of Prometheus is running at any time; deprecate any unneeded replicas (or old Container App revisions) as needed."**

> **Additional Note:** When you deploy a new revision of the Container App, this can also (temporarily) cause multiple replicas of Prometheus to exist at the same time, since Azure typically ensures the new revision is fully running before deprecating the previous. Use the 'multiple revision' mode to override this behavior and immediately deprecate the previous revision when deploying a new revision. **Otherwise, the new revision may never boot up successfully due to Prometheus insances contending for control of the data**.