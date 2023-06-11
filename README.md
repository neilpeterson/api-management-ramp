# Azure API Managemnt Ramp

Deploys a basic API (sum two numbers) to an Azure web app which is connected to a Azure VNET with a private end point. Additionallu, a VM running Ubuntu can also be deployed, into the same VNET, and will have internal access to the web app. 

## Pre-requisites

Before deploying the ARM template, create a self-signed certificate and upload it to Azure Key Vault. First create a resource group and a key vault in that resource group.

```
az group create --name ci-full-002 --location eastus
az deployment group create --template-file ./bicep-modules/key-vault.bicep --resource-group ci-full-002
```

Next, create self signed certificates for API Management and Front Door. Bote - Key vault generated self signed certificates do not work ([link to related issue](https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-backend-health-troubleshooting#the-intermediate-certificate-was-not-found)). Here is a procediur for dooing so using `openssl`. These steps are detailed here ([link](https://learn.microsoft.com/en-us/azure/application-gateway/self-signed-certificates)).

When prompted, enter the requested information. For the Common Name (CN), enter the custom domain name that will be configured for the API Management instance. This same name will be entered when deploying the solution ARM template.

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
az keyvault certificate import --vault-name ci-full-002 -n api.nepeters-api.com -f ./api-management-lab.pfx
```

Export .cer from .pfx file.

```
openssl pkcs12 -in domain.name.pfx -clcerts -nokeys -out domain.name.crt
```



## Solution deployment

## Validate deployment

curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://thur-full-006-app-gateway.eastus.cloudapp.azure.com/sum

## API local build

The following commands can be used to build and test the API on your development machine.

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum
```