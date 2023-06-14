// - APIM Custom Domain Issue
// https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-use-managed-service-identity#requirements-for-key-vault-firewall
// https://stackoverflow.com/questions/68830195/azure-api-managment-user-assigned-identity-custom-domain-keyvault

// TODO - integrate with OneCert for SSL certificate
// TODO - Front door HTTPS
// TODO - Diagnostic configurations

@description('')
param baseName string

@secure()
@description('')
param appGatewayTrustedRootCert string

@description('')
param deployAppService bool

@description('')
param location string = resourceGroup().location

// @description('')
// param customDomainNameAPI string

@description('')
param keyVaultName string

@description('')
param keyVaultResourceGroup string

// @description('')
// param kayVaultCertificateURI string

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

// resource nsgRuleAPIClient 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
//   name: 'SecureClientCommunicationToAPIManagementInbound'
//   parent: nsgAPIMgmt
//   properties: {
//     protocol: 'Tcp'
//     sourcePortRange: '*'
//     destinationPortRange: '443'
//     sourceAddressPrefix: ('Internet')
//     destinationAddressPrefix: 'VirtualNetwork'
//     access: 'Allow'
//     priority: 210
//     direction: 'Inbound'
//   }
// }

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

// resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
//   name: '${baseName}-api-mgmt'
//   location: location
// }

// module kvRoleAssignment './bicep-modules/vault-access.bicep' = {
//   name: 'vault-access'
//   scope: resourceGroup(keyVaultResourceGroup)
//   params: {
//     managedIdentityId: managedIdentity.properties.principalId
//     namestring: baseName
//     keyVaultName: keyVaultName
//   }
// }

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
    // hostnameConfigurations: [
    //   {
    //     type: 'Proxy'
    //     hostName: customDomainNameAPI
    //     keyVaultId: kayVaultCertificateURI
    //     identityClientId: managedIdentity.properties.clientId
    //   }
    // ]
    publicIpAddressId: publicIPAddressAPIMgmt.id
  }
  // identity: {
  //   type: 'UserAssigned'
  //   userAssignedIdentities: {
  //     '${managedIdentity.id}': {}
  //   }
  // }
  identity: {
    type: 'SystemAssigned'
  }
}

module kvRoleAssignmentSA './bicep-modules/vault-access.bicep' = {
  name: 'vault-access'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    managedIdentityId: apiManagementInstance.identity.principalId
    namestring: baseName
    keyVaultName: keyVaultName
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
// resource nsgRuleAPPGatewayIngressPublic 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
//   name: 'appgw-in-internet'
//   parent: nsgAppGateway
//   properties: {
//     protocol: 'Tcp'
//     sourcePortRange: '*'
//     destinationPortRange: '443'
//     sourceAddressPrefix: 'Internet'
//     destinationAddressPrefix: '*'
//     access: 'Allow'
//     priority: 110
//     direction: 'Inbound'
//   }
// }

// TODO - remove once Front Door has been added?
// resource nsgRuleAPPGatewayIngressPublic80 'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
//   name: 'appgw-in-internet-80'
//   parent: nsgAppGateway
//   properties: {
//     protocol: 'Tcp'
//     sourcePortRange: '*'
//     destinationPortRange: '80'
//     sourceAddressPrefix: 'Internet'
//     destinationAddressPrefix: '*'
//     access: 'Allow'
//     priority: 200
//     direction: 'Inbound'
//   }
// }

resource nsgRuleAPPGatewayIngress'Microsoft.Network/networkSecurityGroups/securityRules@2019-11-01' = {
  name: 'appgw-in-FrontDoor'
  parent: nsgAppGateway
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443,80'
    sourceAddressPrefix: 'AzureFrontDoor.Backend'
    destinationAddressPrefix: 'VirtualNetwork'
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
// - Start Front Door Premium Deployment
// ------------------------------------
resource frontDoor 'Microsoft.Cdn/profiles@2022-11-01-preview' = {
  name: baseName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdendpoints@2022-11-01-preview' = {
  parent: frontDoor
  name: baseName
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/origingroups@2022-11-01-preview' = {
  parent: frontDoor
  name: 'default-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    sessionAffinityState: 'Disabled'
  }
}

resource frontDoorOrigin 'Microsoft.Cdn/profiles/origingroups/origins@2022-11-01-preview' = {
  parent: frontDoorOriginGroup
  name: 'default-origin'
  properties: {
    hostName: publicIPAddressAPPGateway.properties.ipAddress
    httpPort: 80
    httpsPort: 443
    originHostHeader: publicIPAddressAPPGateway.properties.ipAddress
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdendpoints/routes@2022-11-01-preview' = {
  parent: frontDoorEndpoint
  name: 'default-route'
  properties: {
    customDomains: []
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    ruleSets: []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/'
    ]
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Disabled'
    enabledState: 'Enabled'
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
