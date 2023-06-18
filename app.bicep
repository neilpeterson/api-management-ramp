// - APIM Custom Domain Issue
// https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-use-managed-service-identity#requirements-for-key-vault-firewall
// https://stackoverflow.com/questions/68830195/azure-api-managment-user-assigned-identity-custom-domain-keyvault

// TODO - clean up and other generalizations
// TODO - Front door custom
// TODO - Diagnostic configurations

@description('')
param baseName string

@description('')
param customDomainNameAPIM string

@description('')
param deployAppService bool

@description('')
param location string = resourceGroup().location

@description('')
param keyVaultName string

@description('')
param keyVaultResourceGroup string

resource logAnalyticsWorkpace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: baseName
  location: location
}

resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2022-11-01' = {
  name: baseName
  location: location
}

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
    enableDdosProtection: true
    ddosProtectionPlan: {
      id: ddosProtectionPlan.id
    }
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

resource srcControl 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = if (deployAppService)  {
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
    publicIpAddressId: publicIPAddressAPIMgmt.id
  }
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
  name: customDomainNameAPIM
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

resource apimPortalSignup 'Microsoft.ApiManagement/service/portalsettings@2022-09-01-preview' = {
  parent: apiManagementInstance
  name: 'signup'
  properties: {
    enabled: false
    termsOfService: {
      enabled: false
      consentRequired: false
    }
  }
}

resource apimPortalDefault 'Microsoft.ApiManagement/service/portalconfigs@2022-09-01-preview' = {
  parent: apiManagementInstance
  name: 'default'
  properties: {
    enableBasicAuth: false
    signin: {
      require: false
    }
    signup: {
      termsOfService: {
        requireConsent: false
      }
    }
    delegation: {
      delegateRegistration: false
      delegateSubscription: false
    }
    cors: {
      allowedOrigins: []
    }
    csp: {
      mode: 'disabled'
      reportUri: []
      allowedSources: []
    }
  }
}

// ------------------------------------
// - Start Application Gateway Deployment
// ------------------------------------
resource nsgRuleAPPGatewayIngress'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'appgw-in-FrontDoor'
  parent: nsgAppGateway
  properties: {
    protocol: 'Tcp'
    sourcePortRange: '*'
    // TODO - fix this.
    destinationPortRanges: ['80', '443']
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

resource applicationGatewayWAFPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: baseName
  location: location
  properties: {
    customRules: []
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
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
          hostName: customDomainNameAPIM
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', baseName, 'apim-gateway-probe')
          }
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
      id: applicationGatewayWAFPolicy.id
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

resource frontDoorWAFPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = {
  name: 'wafPolicy'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: []
    }
  }
}

resource frontDoorSecurityPolicy 'Microsoft.Cdn/profiles/securitypolicies@2022-11-01-preview' = {
  parent: frontDoor
  name: 'testwaf'
  properties: {
    parameters: {
      wafPolicy: {
        id: frontDoorWAFPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
      type: 'WebApplicationFirewall'
    }
  }
}
