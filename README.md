# Azure API Managemnt Ramp

Deploys Front Door > APP Gateway > API Managament > and conditionally an API running in a Pyton Flask Web App.

![](/images/arch-diagram.png)

## Pre-requisites

Before deploying the ARM template, create a Key Vault, Self Signed SSL Certificate, and upload these to the Key Vault.

Create the Key Vault.

```
az group create --name ci-lab-full-001 --location eastus
az deployment group create --template-file ./bicep-modules/key-vault.bicep --resource-group ci-lab-full-001 
```

## Solution deployment

Update the app.json file with the follling things.

| Property | Description |
| --- | --- |
| `baseName` | The base name for the resources created. |
| `deployAppService` | Set to `true` to deploy the API. |
| `customDomainNameAPIM` | |
| `keyVaultName` | The name of the Key Vault created in the pre-requisites. |
| `keyVaultResourceGroup` | The name of the resource group where the Key Vault was created. |

## Post deployment steps

### Manually configure custom domain

### Optionally Add API to API Management

## Validate deployment

![](/images/backend-health.png)

curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' https://ci-lab-full-005-fve8ascudcdte9ds.z01.azurefd.net/sum

## Apendex 1 - API local build

The following commands can be used to build and test the API on your development machine.

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum
```