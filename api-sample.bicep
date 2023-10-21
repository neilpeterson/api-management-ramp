@description('')
param baseName string

@description('')
param location string = 'eastus'

// @description('')
// param virtualNetworkName string = 'vnet-sce-api-gateway'

// resource nsgAppService 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
//   name: 'app-service'
//   location: location
//   properties: {}
// }

// resource apiVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
//   name: virtualNetworkName
// }

// resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
//   parent: apiVirtualNetwork
//   name: 'app-service'
//   properties: {
//     addressPrefix: '10.1.2.16/28'
//     networkSecurityGroup: {
//       id: nsgAppService.id
//     }
//   }
// }

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: baseName
  location: location
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    size: 'P1v3'
    family: 'Pv3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: baseName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'PYTHON|3.9'
      acrUseManagedIdentityCreds: false
      alwaysOn: true
      http20Enabled: false
      functionAppScaleLimit: 0
      minimumElasticInstanceCount: 0
    }
  }
}

resource srcControl 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
  name: 'web'
  parent: webApplication
  properties: {
    repoUrl: 'https://github.com/neilpeterson/api-management-ramp'
    branch: 'west-us-return-westus'
    isManualIntegration: true
  }
}

// resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
//   name: 'app-service'
//   location: location
//   properties: {
//     customNetworkInterfaceName: 'nic-app-service'
//     privateLinkServiceConnections: [
//       {
//         name: baseName
//         properties: {
//           privateLinkServiceId: webApplication.id
//           groupIds: [
//             'sites'
//           ]
//         }
//       }
//     ]
//     subnet: {
//       id: '${apiVirtualNetwork.id}/subnets/app-service'
//     }
//   }
// }

// resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
//   name: 'privatelink.azurewebsites.net'
//   location: 'global'
// }

// resource dnsNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
//   parent: privateDnsZones
//   name: baseName
//   location: 'global'
//   properties: {
//     registrationEnabled: false
//     virtualNetwork: {
//       id: apiVirtualNetwork.id
//     }
//   }
// }

// resource privateEndpointDNS 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = {
//   name: 'default'
//   parent: privateEndpoint
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'privatelink-azurewebsites-net'
//         properties: {
//           privateDnsZoneId: privateDnsZones.id
//         }
//       }
//     ]
//   }
// }

//curl --header "Content-Type: application/json" --request POST --data '{"num1": 5, "num2": 7}' https://pef-lab-premimum-guarhfaqeydme7ht.z01.azurefd.net/sum
