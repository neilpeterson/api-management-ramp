@secure()
param adminPassword string
param adminUserName string = 'azureadmin'
param location string = resourceGroup().location
param name string = 'jump-box'
param VirtualNetworkName string
param VirtualNetworkResourceGroupName string

resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: VirtualNetworkName
  scope: resourceGroup(VirtualNetworkResourceGroupName)
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
            id: '${VirtualNetwork.id}/subnets/virtual-machine'
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
}

