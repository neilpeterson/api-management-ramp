# Azure API Management Ramp

Deploys Front Door > APP Gateway > API Management> and conditionally an API running in a Python Flask Web App.

![](/images/arch-diagram.png)

## Pre-requisites

Before deploying the ARM template, create a Key Vault, and Self-Signed SSL Certificate, and upload these to the Key Vault.

Create the Key Vault.

```
az group create --name ci-lab-full-001 --location eastus
az deployment group create --template-file ./bicep-modules/key-vault.bicep --resource-group ci-lab-full-001 
```

## Solution Deployment

Update the app.json file with the following things.

| Property | Description |
| --- | --- |
| `baseName` | The base name for the resources created. |
| `deployAppService` | Set to `true` to deploy the API. |
| `customDomainNameAPIM` | Custom domain name for APIM, must match SSL certificate. |
| `keyVaultName` | The name of the Key Vault created in the pre-requisites. |
| `keyVaultResourceGroup` | The name of the resource group where the Key Vault was created. |

## Post-deployment steps

### Manually configure a custom domain

Select the APIM instance and select Custom Domains. Add the custom domain name and the SSL certificate.

![](/images/custom-domain.png)

Once done, click save. This seems to put APIM into a non-functional state where 'Service is being updated'. This is something to understand better.

### Optionally Add API to API Management

The Bicep templates include an optional API hosted in App Service. If deployed, add the API to APIM. Select the APIM instance, APIs, and then from the Add API menu, select App Service. Select the API and then create.

![](/images/api.png)

The sample API is not AAD integrated. For demo purposes only, uncheck the Require subscription check box.

![](/images/api-subscription.png)

## Validate deployment

Select the Application Gateway > Backend Health, and verify that the API is healthy.

![](/images/backend-health.png)

Run the following command against the front door URL to verify that the API GET operation works.

```
curl https://ci-lab-full-005-fve8ascudcdte9ds.z01.azurefd.net
```

Run the following command against the front door URL to verify that the API POST operation works.

```
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' https://ci-lab-full-005-fve8ascudcdte9ds.z01.azurefd.net/sum
```

## Apendex 1 - API local build

The following commands can be used to build and test the API on your development machine.

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum
```