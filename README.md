# Azure API Managemnt Ramp

## TODO

- Create basic API
- Integrate OPenAPI spec
- Host API on Azure Web App, Container App, and AKS
- Integrate API Management for all hosting applications
- Integrate Security controlls
- Integration Observability
- Create IaC for all components
- Integrate Azure Front Door

## API Development

```
python3 -m venv .venv
./.venv/bin/Activate.ps1
pip install -r requirements.txt
python app.py
```

curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' http://localhost:5000/sum