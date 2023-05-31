param name string = 'nepeters-api-lab-004'
param location string = resourceGroup().location
@secure()
param adminPassword string
param adminUserName string = 'azureadmin'

param bastionHost object = {
  name: 'AzureBastionHost'
  publicIPAddressName: 'pip-bastion'
  subnetName: 'AzureBastionSubnet'
  nsgName: 'nsg-hub-bastion'
  subnetPrefix: '10.0.4.0/29'
}

// Network + NSG for App, API Management, and App Gateway
resource nsgAPIMgmt 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'api-mgmt'
  location: location
  properties: {}
}

resource nsgAppGateway 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'app-gateway'
  location: location
  properties: {}
}

resource nsgAppService 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'app-service'
  location: location
  properties: {}
}

resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: 'nsgbastion'
  location: location
  properties: {
    securityRules: [
      {
        name: 'bastion-in-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'bastion-control-in-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'bastion-in-host'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'bastion-vnet-out-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'bastion-azure-out-allow'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'bastion-out-host'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'bastion-out-deny'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgVirtualMachines 'Microsoft.Network/networkSecurityGroups@2020-08-01' = {
  name: 'nsgVirtualMachines'
  location: location
  properties: {
    securityRules: [
      {
        name: 'bastion-in-vnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: bastionHost.subnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// VNET with subnet for App, API Management, App Gateway, Virtual Machines, and Bastion
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
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
          networkSecurityGroup: {
            id: nsgAppService.id
          }
        }
      }
      {
        name: 'virtual-machine'
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: nsgVirtualMachines.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.4.0/29'
          networkSecurityGroup: {
            id: nsgBastion.id
          }
        }
      }
    ]
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: 'bastionhost'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconf'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/${bastionHost.subnetName}'
          }
          publicIPAddress: {
            id: pipBastion.id
          }
        }
      }
    ]
  }
}

resource pipBastion 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: 'bastionpip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nicVirtualMachine 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${name}-vm'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${virtualNetwork.id}/subnets/virtual-machine'
          }
        }
      }
    ]
  }
}

resource ubuntuVM 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_A2_v2'
    }
    osProfile: {
      computerName: name
      adminUsername: adminUserName
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '16.04-LTS'
        version: 'latest'
      }
      osDisk: {
        name: name
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVirtualMachine.id
        }
      ]
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource linuxVMGuestConfigExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  name: 'AzurePolicyforLinux'
  parent: ubuntuVM
  location: location
  properties: {
    publisher: 'Microsoft.GuestConfiguration'
    type: 'ConfigurationForLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// App Gateway Start - NSG Rules
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

resource pipAppGateway 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: 'AppGateway'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
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

// App Service + Web App + Source Controll
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

// Private DNS ZONE + Link to VNET + DNS Records Set
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

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
  name: '${name}-api'
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

// Private DNS ZONE + Link to VNET + DNS Records Set
resource privateDnsZonesAPI 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'azure-api.net'
  location: 'global'
}

resource dnsNetworkLinkAPI 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: privateDnsZonesAPI
  name: name
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDnsZonesAPIRecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: apiManagementInstance.name
  parent: privateDnsZonesAPI
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: apiManagementInstance.properties.privateIPAddresses[0]
      }
    ]
  }
}

// Application Gateway Things
resource ApplicationGatewayWAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: name
  location: location
  properties: {
    customRules: []
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Detection'
      requestBodyInspectLimitInKB: 128
      fileUploadEnforcement: true
      requestBodyEnforcement: true
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
      ]
      exclusions: []
    }
  }
}


// resource APIManagementPortalSettings 'Microsoft.ApiManagement/service/portalsettings@2022-09-01-preview' = {
//   name: 'delegation'
//   parent: apiManagementInstance
//   properties: {
//     subscriptions: {
//       enabled: false
//     }
//     userRegistration: {
//       enabled: false
//     }
//   }
// }

// TODO Add a record for the api management instance (Does this work, might have to update with module to pass URL too)
// resource privateDnsZonesApp 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
//   parent: privateDnsZones
//   name: apiManagementInstance.name
//   properties: {
//     ttl: 10
//     aRecords: [
//       {
//         ipv4Address: apiManagementInstance.properties.privateIPAddresses[0]
//       }
//     ]
//   }
// }

// Maybe put back in
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

// Put back in at some point

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${name}-01'
  location: location
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    publicNetworkAccess: 'Disabled'
    accessPolicies: [
      {
        objectId: apiManagementInstance.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
        tenantId: subscription().tenantId
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}
