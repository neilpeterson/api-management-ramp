param profiles_pef_apim_lab_cert_name string = 'pef-apim-lab-cert'
param frontdoorWebApplicationFirewallPolicies_FrontDoorWAFPolicy_externalid string = '/subscriptions/7d87d11e-2aaa-4d69-85bf-a1c11503f96d/resourceGroups/paf-apim-lab-1001/providers/Microsoft.Network/frontdoorWebApplicationFirewallPolicies/FrontDoorWAFPolicy'

resource profiles_pef_apim_lab_cert_name_resource 'Microsoft.Cdn/profiles@2022-11-01-preview' = {
  name: profiles_pef_apim_lab_cert_name
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  kind: 'frontdoor'
  properties: {
    originResponseTimeoutSeconds: 30
    extendedProperties: {}
  }
}

resource profiles_pef_apim_lab_cert_name_profiles_pef_apim_lab_cert_name 'Microsoft.Cdn/profiles/afdendpoints@2022-11-01-preview' = {
  parent: profiles_pef_apim_lab_cert_name_resource
  name: '${profiles_pef_apim_lab_cert_name}'
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource profiles_pef_apim_lab_cert_name_default_origin_group 'Microsoft.Cdn/profiles/origingroups@2022-11-01-preview' = {
  parent: profiles_pef_apim_lab_cert_name_resource
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

resource profiles_pef_apim_lab_cert_name_default_origin_group_default_origin 'Microsoft.Cdn/profiles/origingroups/origins@2022-11-01-preview' = {
  parent: profiles_pef_apim_lab_cert_name_default_origin_group
  name: 'default-origin'
  properties: {
    hostName: '20.241.167.239'
    httpPort: 80
    httpsPort: 443
    originHostHeader: '20.241.167.239'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false
  }
  dependsOn: [

    profiles_pef_apim_lab_cert_name_resource
  ]
}

resource profiles_pef_apim_lab_cert_name_test_waf 'Microsoft.Cdn/profiles/securitypolicies@2022-11-01-preview' = {
  parent: profiles_pef_apim_lab_cert_name_resource
  name: 'test-waf'
  properties: {
    parameters: {
      wafPolicy: {
        id: frontdoorWebApplicationFirewallPolicies_FrontDoorWAFPolicy_externalid
      }
      associations: [
        {
          domains: [
            {
              id: profiles_pef_apim_lab_cert_name_profiles_pef_apim_lab_cert_name.id
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

resource profiles_pef_apim_lab_cert_name_profiles_pef_apim_lab_cert_name_default_route 'Microsoft.Cdn/profiles/afdendpoints/routes@2022-11-01-preview' = {
  parent: profiles_pef_apim_lab_cert_name_profiles_pef_apim_lab_cert_name
  name: 'default-route'
  properties: {
    customDomains: []
    originGroup: {
      id: profiles_pef_apim_lab_cert_name_default_origin_group.id
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
  dependsOn: [

    profiles_pef_apim_lab_cert_name_resource

  ]
}
