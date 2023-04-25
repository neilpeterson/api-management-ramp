@secure()
param adminPassword string
param adminUserName string = 'azureadmin'
param virtualNetworkID string
param location string = resourceGroup().location
param name string

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: '${name}-vm'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
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
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: '${virtualNetworkID}/subnets/default'
          }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: name
  location: location
  properties: {
  }
}

resource nsgrule 'Microsoft.Network/networkSecurityGroups/securityRules@2022-09-01' = {
  name: 'SSH'
  parent: nsg
  properties: {
    protocol: 'TCP'
    sourcePortRange: '*'
    destinationPortRange: '22'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 300
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
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
}

