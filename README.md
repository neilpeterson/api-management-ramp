# Azure API Managemnt Ramp

Deploys Front Door > APP Gateway > API Managament > and conditionally an API running in a Pyton Flask Web App.

![](/images/arch-diagram.png)

## Pre-requisites

Before deploying the ARM template, create a Key Vault, Self Signed SSL Certificate, and upload these to the Key Vault.

Create the Key Vault.

```
az group create --name ci-full-002 --location eastus
az deployment group create --template-file ./bicep-modules/key-vault.bicep --resource-group ci-full-002
```

Next, create self signed certificate. Note - Key vault generated self signed certificates do not work ([link to related issue](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-backend-health-troubleshooting#the-intermediate-certificate-was-not-found)). 

Here is a procediur for dooing so using `openssl`. These steps are detailed here ([link](https://learn.microsoft.com/en-us/azure/application-gateway/self-signed-certificates)). When prompted, enter the requested information. For the Common Name (CN), enter the custom domain name that will be configured for the API Management instance. This same name will be entered when deploying the solution ARM template.

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

Upload the .pfx file to Azure Key Vault.

```
# Debug - manually doing this for now
az keyvault certificate import --vault-name ci-full-002 -n api.nepeters-api.com -f ./api-management-lab.pfx
```

Export .cer from .pfx file.

```
openssl pkcs12 -in domain.name.pfx -clcerts -nokeys -out domain.name.crt
```

Create a Key Vault secret named `appGatewayTrustedRootCert` and add the content of the domain.name.crt file as the secret value.

## Solution deployment

## Post deployment steps

Due to a known issue with API Management traversing the Key Vault firewall with a user assigned managed identity, the custom domain must be manually configured. The issue is documented here and here. There are things we could do to work around so that this is configured at deployment time (deployment script), I may revisit at some point.

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