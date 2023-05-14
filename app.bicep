param name string = 'giants-saturday-003'
param location string = resourceGroup().location

// Network stuff
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'api-management'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsgAPIMgmt.id
          }
        }
      }
      {
        name: 'app-gateway'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsgAppGateway.id
          }
        }
      }
      {
        name: 'app-service'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

resource nsgAppGateway 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'app-gateway'
  location: location
  properties: {
  }
}

resource nsgRuleAPPGatewayIngressPrivate 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
  name: 'appgw-in'
  parent: nsgAppGateway
  properties: {
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '65200-65535'
    sourceAddressPrefix: 'GatewayManager'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 100
    direction: 'Inbound'
  }
}

// Remove once  Front door is in place
resource nsgRuleAPPGatewayIngressPublic 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
  name: 'appgw-in-internet'
  parent: nsgAppGateway
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 110
    direction: 'Inbound'
  }
}

resource nsgAPIMgmt 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'api-mgmt'
  location: location
  properties: {
  }
}

resource nsgRuleAPIManagement 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
  name: 'ManagementEndpointForAzurePortalAndPowershellInbound'
  parent: nsgAPIMgmt
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '3443'
    sourceAddressPrefix: 'ApiManagement'
    destinationAddressPrefix: 'VirtualNetwork'
    access: 'Allow'
    priority: 120
    direction: 'Inbound'
  }
}

resource nsgRuleAPIClient 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
  name: 'SecureClientCommunicationToAPIManagementInbound'
  parent: nsgAPIMgmt
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: ('Internet')
    destinationAddressPrefix: 'VirtualNetwork'
    access: 'Allow'
    priority: 210
    direction: 'Inbound'
  }
}

// Add NSG for App Service

// App stuff
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: name
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
  name: name
  location: location
  properties: {
    serverFarmId: appServicePlan.id
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

resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
  name: 'web'
  parent: webApplication
  properties: {
    repoUrl: 'https://github.com/neilpeterson/api-management-ramp'
    branch: 'main'
    isManualIntegration: true
  }
}

// Private endpoint for App Service
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: 'app-service'
  location: location
  properties: {
    customNetworkInterfaceName: 'nic-app-service'
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: webApplication.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    subnet: {
      id: '${virtualNetwork.id}/subnets/app-service'
    }
  }
}

// TODO - need to understand this beetter
resource dnsNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: privateDnsZones
  name: name
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateEndpointDNS 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: privateDnsZones.id
        }
      }
    ]
  }
}

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

// TODO Add a record for the api management instance
resource privateDnsZonesApp 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: privateDnsZones
  name: name
  properties: {
    ttl: 10
    aRecords: [
      {
        ipv4Address: '10.0.0.4'
      }
    ]
  }
}

// DO I need this once Front door is in place - for management maybe?
resource publicIPAddressAPIMgmt 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${name}-api-mgmt'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${name}-api-mgmt'
    }
  }
}

// DO I need this once Front door is in place - for management maybe?
resource publicIPAddressAPPGateway 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${name}-app-gateway'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${name}-app-gateway'
    }
  }
}

resource apiManagementInstance 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: name
  location: location
  sku:{
    capacity: 1
    name: 'Developer'
  }
  properties:{
    virtualNetworkType: 'Internal'
    publisherEmail: 'nepeters@microsoft.com'
    publisherName: 'nepeters.com'
    virtualNetworkConfiguration: {
      subnetResourceId: '${virtualNetwork.id}/subnets/api-management'
    }
    publicIpAddressId: publicIPAddressAPIMgmt.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// resource apiSumBackend 'Microsoft.ApiManagement/service/backends@2022-08-01' = {
//   parent: apiManagementInstance
//   name: name
//   properties: {
//     description: 'api-mgmt-ramp-001'
//     url: 'https://api-mgmt-ramp-002.azurewebsites.net'
//     protocol: 'http'
//     resourceId: 'https://management.azure.com/subscriptions/7dba16b0-223a-47ee-961c-35f04590c547/resourceGroups/api-mgmt-ramp-002/providers/Microsoft.Web/sites/api-mgmt-ramp-002'
//   }
// }

// resource apiSum 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
//   parent: apiManagementInstance
//   name: name
//   properties: {
//     displayName: 'api-mgmt-ramp-001'
//     apiRevision: '1'
//     subscriptionRequired: false
//     protocols: [
//       'https'
//     ]
//     authenticationSettings: {
//       oAuth2AuthenticationSettings: []
//       openidAuthenticationSettings: []
//     }
//     subscriptionKeyParameterNames: {
//       header: 'Ocp-Apim-Subscription-Key'
//       query: 'subscription-key'
//     }
//     isCurrent: true
//     path: webApplication.properties.defaultHostName
//   }
// }

// resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
//   name: '${name}-01'
//   location: location
//   properties: {
//     enabledForDeployment: false
//     enabledForTemplateDeployment: false
//     enabledForDiskEncryption: false
//     tenantId: subscription().tenantId
//     publicNetworkAccess: 'Disabled'
//     accessPolicies: [
//       {
//         objectId: apiManagementInstance.identity.principalId
//         permissions: {
//           secrets: [
//             'get'
//             'list'
//           ]
//         }
//         tenantId: subscription().tenantId
//       }
//     ]
//     sku: {
//       name: 'standard'
//       family: 'A'
//     }
//   }
// }
