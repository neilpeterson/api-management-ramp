param location string
param name string
param vnetid string

// For the App Gateway front end (in public mode?)
resource publicIPAddressAppGateway 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${name}-api-mgmt'
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

resource ApplicationGatewayWebApplicationFirewallPolicies_giant_friday_004_name_resource 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: ApplicationGatewayWebApplicationFirewallPolicies_giant_friday_004_name
  location: 'eastus'
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
  name: name
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        id: '${applicationGateway.id}/gatewayIPConfigurations/appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${vnetid}/subnets/app-gateway'
          }
        }
      }
    ]
    sslCertificates: []
    trustedRootCertificates: []
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIpIPv4'
        id: '${applicationGateway.id}/frontendIPConfigurations/appGwPublicFrontendIpIPv4'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressAppGateway.id
          }
        }
      }
      {
        name: 'appGwPrivateFrontendIpIPv4'
        id: '${applicationGateway.id}/frontendIPConfigurations/appGwPrivateFrontendIpIPv4'
        properties: {
          privateIPAddress: '10.0.1.10'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${virtualNetworks_webapp_api_demo_002_externalid}/subnets/app-gateway'
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        id: '${applicationGateways_webapp_api_demo_name_resource.id}/frontendPorts/port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: applicationGateways_webapp_api_demo_name
        id: '${applicationGateways_webapp_api_demo_name_resource.id}/backendAddressPools/${applicationGateways_webapp_api_demo_name}'
        properties: {
          backendAddresses: [
            {
              ipAddress: '10.0.0.5'
            }
          ]
        }
      }
    ]
    loadDistributionPolicies: []
    backendHttpSettingsCollection: [
      {
        name: applicationGateways_webapp_api_demo_name
        id: '${applicationGateways_webapp_api_demo_name_resource.id}/backendHttpSettingsCollection/${applicationGateways_webapp_api_demo_name}'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    backendSettingsCollection: []
    httpListeners: [
      {
        name: 'AllowAnyCustom65200-65535Inbound'
        id: '${applicationGateways_webapp_api_demo_name_resource.id}/httpListeners/AllowAnyCustom65200-65535Inbound'
        properties: {
          frontendIPConfiguration: {
            id: '${applicationGateways_webapp_api_demo_name_resource.id}/frontendIPConfigurations/appGwPrivateFrontendIpIPv4'
          }
          frontendPort: {
            id: '${applicationGateways_webapp_api_demo_name_resource.id}/frontendPorts/port_80'
          }
          protocol: 'Http'
          hostNames: []
          requireServerNameIndication: false
        }
      }
    ]
    listeners: []
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: applicationGateways_webapp_api_demo_name
        id: '${applicationGateways_webapp_api_demo_name_resource.id}/requestRoutingRules/${applicationGateways_webapp_api_demo_name}'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: '${applicationGateways_webapp_api_demo_name_resource.id}/httpListeners/AllowAnyCustom65200-65535Inbound'
          }
          backendAddressPool: {
            id: '${applicationGateways_webapp_api_demo_name_resource.id}/backendAddressPools/${applicationGateways_webapp_api_demo_name}'
          }
          backendHttpSettings: {
            id: '${applicationGateways_webapp_api_demo_name_resource.id}/backendHttpSettingsCollection/${applicationGateways_webapp_api_demo_name}'
          }
        }
      }
    ]
    routingRules: []
    probes: []
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    firewallPolicy: {
      id: ApplicationGatewayWebApplicationFirewallPolicies_webapp_api_demo_externalid
    }
  }
}
