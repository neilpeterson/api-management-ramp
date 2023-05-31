$domain = "nepeters-api.com"
$apimServiceName = "nepeters-api-001"       # API Management service instance name, must be globally unique
$apimOrganization = "nepeters-api"         # Organization name
$apimAdminEmail = "admin@nepeters-api.com" # Administrator's email address

$apimService = New-AzApiManagement -ResourceGroupName $resGroupName -Location $location -Name $apimServiceName -Organization $apimOrganization `
    -AdminEmail $apimAdminEmail -VirtualNetwork $apimVirtualNetwork -VpnType "Internal" -Sku "Developer" -PublicIpAddressId $apimPublicIpAddressId.Id
