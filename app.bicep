@description('')
param baseName string

@secure()
@description('')
param adminPassword string

@secure()
@description('')
param appGatewayTrustedRootCert string

@description('')
param deployAppService bool

@description('')
param virtualMachine object

@description('')
param bastionHost object

@description('')
param location string = resourceGroup().location

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: baseName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      // - Subnets are all nested .vs child resources - related issue.
      // - This is unfortunate, removes conditional subnet deployment
      // - Will revisit and also remove non esential components (VM and Bastion + network goo)
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

resource nsgAPIMgmt 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'api-mgmt'
  location: location
  properties: {}
}

resource nsgAppGateway 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'app-gateway'
  location: location
  properties: {
    securityRules: [
      {
        // - Nested this one vs. child resoure.. for some reason it was breaking subsequent (idempotent) deployments as a child.
        name: 'app-gateway-in-allow'
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
    ]
  }
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

// ------------------------------------
// - Start Virtual Machine Deployment - remove at some point
// - This is used for troubleshooting within the VNET
// - Bastion, VM, PIP, NIC, and extensions are conditionally deployed
// - Subnet and NSG are always deployed due to this issue - https://github.com/Azure/bicep/issues/4653
// ------------------------------------
resource bastion 'Microsoft.Network/bastionHosts@2020-06-01' = if (virtualMachine.deploy) {
  name: bastionHost.name
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

resource pipBastion 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (virtualMachine.deploy) {
  name: bastionHost.name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nicVirtualMachine 'Microsoft.Network/networkInterfaces@2021-05-01' = if (virtualMachine.deploy) {
  name: '${baseName}-vm'
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

resource ubuntuVM 'Microsoft.Compute/virtualMachines@2020-12-01' = if (virtualMachine.deploy) {
  name: baseName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_A2_v2'
    }
    osProfile: {
      computerName: baseName
      adminUsername: virtualMachine.adminUserName
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
        name: baseName
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

resource linuxVMGuestConfigExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = if (virtualMachine.deploy) {
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

// ------------------------------------
// - Start App Service Plan and Web App Deployment - remove at some point
// - This is used for E2E API validaton
// - App Service Plan, Web App, Source Controll, and Private endpoint things are conditionally deployed
// - Subnet and NSG are always deployed due to this issue - https://github.com/Azure/bicep/issues/4653
// ------------------------------------
resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = if (deployAppService) {
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

resource webApplication 'Microsoft.Web/sites@2021-01-15' = if (deployAppService)  {
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

resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = if (deployAppService)  {
  name: 'web'
  parent: webApplication
  properties: {
    repoUrl: 'https://github.com/neilpeterson/api-management-ramp'
    branch: 'main'
    isManualIntegration: true
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = if (deployAppService)  {
  name: 'app-service'
  location: location
  properties: {
    customNetworkInterfaceName: 'nic-app-service'
    privateLinkServiceConnections: [
      {
        name: baseName
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

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = if (deployAppService)  {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
}

resource dnsNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = if (deployAppService)  {
  parent: privateDnsZones
  name: baseName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateEndpointDNS 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = if (deployAppService)  {
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

// ------------------------------------
// - Start API Management Deployment
// ------------------------------------
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

resource publicIPAddressAPIMgmt 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${baseName}-api-mgmt'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${baseName}-api-mgmt'
    }
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${baseName}-api-mgmt'
  location: location
}

module kvRoleAssignment './bicep-modules/vault-access.bicep' = {
  name: 'vault-access'
  // TODO - need to generalize
  scope: resourceGroup('ci-full-002')
  params: {
    managedIdentityId: managedIdentity.properties.principalId
    namestring: baseName
  }
}

resource apiManagementInstance 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: '${baseName}-api'
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
    hostnameConfigurations: [
      {
        type: 'Proxy'
        // - This needs to be generalized
        hostName: 'api.nepeters-api.com'
        // - This needs to be generalized
        keyVaultId: 'https://ci-full-002.vault.azure.net/secrets/nepeters-api'
        identityClientId: managedIdentity.properties.clientId
      }
    ]
    publicIpAddressId: publicIPAddressAPIMgmt.id
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}

resource privateDnsZonesAPI 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'nepeters-api.com'
  location: 'global'
}

resource dnsNetworkLinkAPI 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: privateDnsZonesAPI
  name: baseName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDnsZonesAPIRecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  name: 'api'
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

// ------------------------------------
// - Start Application Gateway Deployment
// ------------------------------------
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

// TODO - remove once Front Door has been added?
resource nsgRuleAPPGatewayIngressPublic80 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
  name: 'appgw-in-internet-80'
  parent: nsgAppGateway
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '80'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 200
    direction: 'Inbound'
  }
}

resource publicIPAddressAPPGateway 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${baseName}-app-gateway'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${baseName}-app-gateway'
    }
  }
}

resource ApplicationGatewayWAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: baseName
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

resource applicationGateway 'Microsoft.Network/applicationGateways@2022-11-01' = {
  name: baseName
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/app-gateway'
          }
        }
      }
    ]
    trustedRootCertificates: [
      {
        name: 'apim-trusted-root-cert'
        properties: {
          data: appGatewayTrustedRootCert
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressAPPGateway.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'apim-backend-pool'
        properties: {
          backendAddresses: [
            {
              ipAddress: apiManagementInstance.properties.privateIPAddresses[0]
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'apim-gateway-https-setting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: 'api.nepeters-api.com'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', baseName, 'apim-gateway-probe')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', baseName, 'apim-trusted-root-cert')
            }
          ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'apim-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', baseName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', baseName, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'apim'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', baseName, 'apim-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', baseName, 'apim-backend-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', baseName, 'apim-gateway-https-setting')
          }
        }
      }
    ]
    probes: [
      {
        name: 'apim-gateway-probe'
        properties: {
          protocol: 'Https'
          path: '/status-0123456789abcdef'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
    ]
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    firewallPolicy: {
      id: ApplicationGatewayWAFPolicy.id
    }
  }
}

// ------------------------------------
// - Stat Front Door Deployment
// ------------------------------------
resource frontDoor 'Microsoft.Network/frontdoors@2021-06-01' = {
  name: baseName
  location: 'Global'
  properties: {
    routingRules: [
      {
        name: 'rule'
        properties: {
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'HttpOnly'
            backendPool: {
              id: resourceId('Microsoft.Network/frontdoors/BackendPools/', baseName, baseName)
            }
          }
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontdoors/FrontendEndpoints/', baseName, baseName)
            }
          ]
          acceptedProtocols: [
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          enabledState: 'Enabled'
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: baseName
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
          additionalLatencyMilliseconds: 0
        }
      }
    ]
    healthProbeSettings: [
      {
        name: baseName
        properties: {
          path: '/'
          protocol: 'Http'
          intervalInSeconds: 30
          enabledState: 'Enabled'
          healthProbeMethod: 'Head'
        }
      }
    ]
    backendPools: [
      {
        name: baseName
        properties: {
          backends: [
            {
              address: publicIPAddressAPPGateway.properties.ipAddress
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
              backendHostHeader: publicIPAddressAPPGateway.properties.ipAddress
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontdoors/LoadBalancingSettings/', baseName, baseName)
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontdoors/HealthProbeSettings/', baseName, baseName)
          }
        }
      }
    ]
    frontendEndpoints: [
      {
        name: baseName
        properties: {
          hostName: '${baseName}.azurefd.net'
          sessionAffinityEnabledState: 'Disabled'
          sessionAffinityTtlSeconds: 0
        }
      }
    ]
    backendPoolsSettings: {
      enforceCertificateNameCheck: 'Enabled'
      sendRecvTimeoutSeconds: 30
    }
    enabledState: 'Enabled'
    friendlyName: baseName
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


// resource apiSumBackend 'Microsoft.ApiManagement/service/backends@2022-08-01' = {
//   parent: apiManagementInstance
//   name: baseName
//   properties: {
//     description: baseName
//     url: 'https://${webApplication.properties.defaultHostName}'
//     protocol: 'http'
//     resourceId: 'https://${webApplication.id}'
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
