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

Next, create self signed certificate. Note - Key vault generated self signed certificates do not work ([link to related issue](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-backend-health-troubleshooting#the-intermediate-certificate-was-not-found)). 

Here is a procediur for dooing so using `openssl`. These steps are detailed here ([link](https://learn.microsoft.com/en-us/azure/application-gateway/self-signed-certificates)). When prompted, enter the requested information. For the Common Name (CN), enter the custom domain name that will be configured for the API Management instance.

```
openssl ecparam -out contoso.key -name prime256v1 -genkey
openssl req -new -sha256 -key contoso.key -out contoso.csr
openssl x509 -req -sha256 -days 365 -in contoso.csr -signkey contoso.key -out contoso.crt
openssl ecparam -out fabrikam.key -name prime256v1 -genkey
openssl req -new -sha256 -key fabrikam.key -out fabrikam.csr
openssl x509 -req -in fabrikam.csr -CA  contoso.crt -CAkey contoso.key -CAcreateserial -out fabrikam.crt -days 365 -sha256
```

Generae a .pfx file from the .crt and .key files, which will be uploaded to Azure Key Vault.

```
openssl pkcs12 -export -out api-management-lab.pfx -inkey fabrikam.key -in fabrikam.crt
```

Upload the .pfx file to Azure Key Vault. The following command can be used, but requires entering the password, which is done in clear text + stored in the shell history. The certificate can also be manually uploaded to avoid this.

```
az keyvault certificate import --vault-name ci-lab-full-001 -n nepeters-api -f ./api-management-lab.pfx --password "replace"
```

Export .cer from .pfx file.

```
openssl pkcs12 -in api-management-lab.pfx  -clcerts -nokeys -out domain.name.crt
```

Create a Key Vault secret named `appGatewayTrustedRootCert` and add the content of the domain.name.crt file as the secret value.

```
cat ./domain.name.crt
```

## Solution deployment

Update the app.json file with the follling things.

| Property | Description |
| --- | --- |
| `baseName` | The base name for the resources created. |
| `deployAppService` | Set to `true` to deploy the API. |
| `appGatewayTrustedRootCertSecretName` | Update the ID with the Key Vault ID where the appGatewayTrustedRootCert secret has been created. |
| `keyVaultName` | The name of the Key Vault created in the pre-requisites. |
| `keyVaultResourceGroup` | The name of the resource group where the Key Vault was created. |

```

```

## Post deployment steps

Due to a known issue, the custom domain must be manually configured. The issue is documented [here](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-use-managed-service-identity#requirements-for-key-vault-firewall) and [here](https://stackoverflow.com/questions/68830195/azure-api-managment-user-assigned-identity-custom-domain-keyvault). There are things we could do to work around so that this is configured at deployment time (deployment script), I may revisit at some point.

### Manually configure custom domain

### Optionally Add API to API Management

## Validate deployment

![](/images/backend-health.png)

curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://thur-full-006-app-gateway.eastus.cloudapp.azure.com/sum

## Apendex 1 - API local build

The following commands can be used to build and test the API on your development machine.

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum
```