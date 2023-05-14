param ApplicationGatewayWebApplicationFirewallPolicies_giant_friday_004_name string = 'giant-friday-004'

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
