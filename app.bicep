param name string = 'appams001'
param location string = resourceGroup().location

resource appServicePlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: name
  location: location
  sku: {
    name: 'F1'
    capacity: 1
  }
  kind: 'linux'
}

resource webApplication 'Microsoft.Web/sites@2021-01-15' = {
  name: name
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    // siteConfig: {
    //   linuxFxVersion: 'PYTHON|3.7'
    // }
  }
}

// resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
//   name: '${appService.name}/web'
//   properties: {
//     repoUrl: repositoryUrl
//     branch: branch
//     isManualIntegration: true
//   }
// }
