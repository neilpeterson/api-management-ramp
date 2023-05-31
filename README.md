# Azure API Managemnt Ramp

Deploys a basic API (sum two numbers) to an Azure web app which is connected to a Azure VNET with a private end point. Additionallu, a VM running Ubuntu can also be deployed, into the same VNET, and will have internal access to the web app. 

Trying to now figure out how to host this behind an API Management instance.

## TODO

- Create basic API - done
- Integrate OPenAPI spec - not started
- Host API on Azure web app - done
- Integrate API Management instance - done manually with public network access, still working on private access + IaC
- Integrate Security controlls
- Integration Observability
- Create IaC for all components - in progress
- Integrate Azure Front Door

## API local build

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum
```

## Deploy to Azure

```
az group create --name webapp-sammamish-001 --location eastus
az deployment group create --template-file ./app.bicep --resource-group webapp-sammamish-001  


# This will fail unless run from the vm. 
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' https://common-infra-002.azurewebsites.net/sum
```

## API Management Integration

Configured manually at this point. When exposed to the public internet, the API can be called with the following command. Working on internal only access.

```
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' https://giants-saturday-006.azure-api.net/sum
```

## Front Door Integration

```
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' https://giants-saturday-003.azure-api.net/sum
```

## TODO

- Add subnet for app gateway, associate with app gateway NSG
- Add WAF Policy
- PIP for App Gateway
- ** Perhaps I cannot connect app gateway to api managemrnt private endpoint, new sku to enable
- Add API to API Manangement instance (looks like there is a controll on the app service resource??)
- Add App Gateway
- Add Front Door

https://techcommunity.microsoft.com/t5/azure-paas-blog/integrating-api-management-with-app-gateway-v2/ba-p/1241650

https://medium.com/@jw_ng/using-azure-application-gateway-with-api-management-service-f9b9b2cd1731


curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://giants-saturday-003-app-gateway.eastus.cloudapp.azure.com/sum