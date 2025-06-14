
# API Management Demo Application

## Run Container Image Locally

```bash
docker run -p 5010:5000 crnepeterstmesbox.azurecr.io/sample-toolbox:v1
docker run -it crnepeterstmesbox.azurecr.io/sample-toolbox:v1 /bin/bash
```

## Build Container Image

```bash
az acr build --image sample-toolbox:v1 --registry crnepeterstmelab1 --file Dockerfile .
```

## HTTPS Configuration (Application Gateway)

Create certificate in Azure Key Vaut and create DNS record to the Applicaton Gateway.

Add certificate to the Application Gateway Listener.

```
$certName="aks-tme-lab-one"
$vaultName="akv-tme-lab-one"
$appgwName="appgw-aks-cluster-tme-lab-one"
$resgp="rg-aks-cluster-tme-lab-one"
$versionedSecretId=$(az keyvault certificate show -n $certName --vault-name $vaultName --query "sid" -o tsv)
$unversionedSecretId=$($versionedSecretId -replace '/[^/]+$')

## To list the existing cert secretes on AppGW
az network application-gateway ssl-cert list --gateway-name $appgwName --resource-group $resgp

## To add secrete to appgw
az network application-gateway ssl-cert create -n $certName --gateway-name $appgwName --resource-group $resgp --key-vault-secret-id $unversionedSecretId

## To delete the secrete from frontend AppGW
az network application-gateway ssl-cert delete -n $certName --gateway-name $appgwName --resource-group $resg
```

## Workload Identity Configuration

1. Retrieve the OIDC Issuer URL

```bash
export AKS_OIDC_ISSUER="$(az aks show --name aks-cluster-tme-lab-one --resource-group rg-aks-cluster-tme-lab-one --query "oidcIssuerProfile.issuerUrl" --output tsv)"
```

2. Create a Managed Identity
3. Create Kubernetes Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nepeters-sa
  annotations:
    azure.workload.identity/client-id: 978d7e2d-257a-49aa-8387-74a3e1662436
    azure.workload.identity/tenant-id: 70a036f6-8e4d-4615-bad6-149c02e7720d # TME TENANT ID
```

4. Create the Federated Identity Credential

```bash
az identity federated-credential create `
    --name fedcredential332 `
    --identity-name mi-workload-identity-tme-lab-one `
    --resource-group rg-workload-identity-tme-lab-one `
    --issuer https://centralus.oic.prod-aks.azure.com/70a036f6-8e4d-4615-bad6-149c02e7720d/89c6bb0f-ddbe-47db-a007-c9fc8f49b0f5/ `
    --subject system:serviceaccount:"https-app-one":"nepeters-sa" `
    --audience api://AzureADTokenExchange
```

## CSI Driver Configuration

1. Assign the managed identity to the AKS VMSS instances (seems weird but works.)
2. Create the SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-cert
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: 978d7e2d-257a-49aa-8387-74a3e1662436
    keyvaultName: akv-tme-lab-one
    objects: |
      array:
        - |
          objectName: aks-tme-lab-one
          objectType: secret
    tenantId: 70a036f6-8e4d-4615-bad6-149c02e7720d
```

Cosume the secret in the pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nepeters-app
  labels:
    app: nepeters-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nepeters-app
  template:
    metadata:
      labels:
        app: nepeters-app
        azure.workload.identity/use: "true"
    spec:
      volumes:
      - name: cert-volume
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: azure-kv-cert
      containers:
      - name: nepeters-app
        image: crnepeterstmelab1.azurecr.io/sample-toolbox:v4
        imagePullPolicy: Always
        ports:
        - containerPort: 8443
        env:
        volumeMounts:
        - name: cert-volume
          mountPath: "/mnt/secrets-store"
          readOnly: true
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      serviceAccountName: nepeters-sa
```

## Private Ingress Configuration Issue

```
ignoring Ingress https-app/nepeters-app-ingress as it requires Application Gateway 'appgw-aks-cluster-tme-lab-one' to have a private IP address. Either add a private IP to Application Gateway or remove 'appgw.ingress.kubernetes.io/use-private-ip' from the ingress.
```

## Reference Commands

```bash
# Access the application
https://aks-tme-lab-one.tme.supplychainplatform.microsoft.com/

# Access pod shell
kubectl exec -it nepeters-app-6f9cb48b84-5flpt -n https-app-one -- /bin/sh

# Check mounted secrets
kubectl exec nepeters-app-6f9cb48b84-5flpt -n https-app-one -- ls /mnt/secrets-store
```