# Azure API Managemnt Ramp

Deploys a basic API (sum two numbers) to an Azure web app which is connected to a Azure VNET with a private end point. Additionallu, a VM running Ubuntu can also be deployed, into the same VNET, and will have internal access to the web app. 

## Pre-requisites

Before deploying the ARM template, create a self-signed certificate and upload it to Azure Key Vault.

```
$fileContentBytes = Get-Content 'path-to.pfx' -AsByteStream
[System.Convert]::ToBase64String($fileContentBytes) | Out-File 'pfx-bytes.txt'
```

## Solution deployment

## Validate deployment

curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://giants-saturday-003-app-gateway.eastus.cloudapp.azure.com/sum

## API local build

The following commands can be used to build and test the API on your development machine.

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum
```