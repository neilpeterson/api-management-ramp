param name string
param location string = resourceGroup().location
param subnet string

resource examplePublicIp 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: name
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource apiManagementInstance 'Microsoft.ApiManagement/service@2020-12-01' = {
  name: name
  location: location
  sku:{
    capacity: 1
    name: 'Developer'
  }
  properties:{
    virtualNetworkType: 'External'
    publisherEmail: 'nepeters@microsoft.com'
    publisherName: 'nepeters.com'
    virtualNetworkConfiguration: {
      subnetResourceId: subnet
    }
  }
}
