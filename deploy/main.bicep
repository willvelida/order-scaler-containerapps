@description('The location to deploy our application to. Default is location of resource group')
param location string = resourceGroup().location

@description('Name of our application.')
param applicationName string = uniqueString(resourceGroup().id)

var containerRegistryName = '${applicationName}acr'
var logAnalyticsWorkspaceName = '${applicationName}law'
var appInsightsName = '${applicationName}ai'
var containerAppEnvironmentName = '${applicationName}env'
var servicebusName = '${applicationName}sb'
var servicebusEndpoint = '${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey'
var cosmosAccountName = '${applicationName}db'
var databaseName = 'OrdersDB'
var ordersContainer = 'orders'
var orderQueueName = 'orders'
var orderwebAppName = 'order-web'
var oderApiAppName = 'order-api'
var oderprocessorAppName = 'order-processor'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: containerRegistryName
  location: location 
  sku: {
    name: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: servicebusName
  location: location
  sku: {
    name: 'Basic'
  }
}

resource ordersQueue 'Microsoft.ServiceBus/namespaces/queues@2022-01-01-preview' = {
  name: orderQueueName
  parent: serviceBus
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-11-15-preview' = {
  name: cosmosAccountName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAnalyticalStorage: true
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-11-15-preview' = {
  name: databaseName
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource writeContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-11-15-preview' = {
  name: ordersContainer
  parent: database
  properties: {
    options: {
      autoscaleSettings: {
        maxThroughput: 4000
      }
    }
    resource: {
      id: ordersContainer
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
      }
    }
  }
}

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: containerAppEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource orderweb 'Microsoft.App/containerApps@2022-03-01' = {
  name: orderwebAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: true
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: orderwebAppName
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Development'
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsights.properties.InstrumentationKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'OrdersApi'
              value: 'https://${orderapi.properties.configuration.ingress.fqdn}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource orderapi 'Microsoft.App/containerApps@2022-03-01' = {
  name: oderApiAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'cosmosdbconnectionstring'
          value: cosmosDbAccount.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'servicebusconnectionstring'
          value: 'Endpoint=sb://${serviceBus.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys(servicebusEndpoint, serviceBus.apiVersion).primaryKey}'
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
      ingress: {
        external: false
        targetPort: 80
        transport: 'http'
        allowInsecure: true
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: oderApiAppName
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Development'
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsights.properties.InstrumentationKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'servicebusconnectionstring'
              secretRef: 'servicebusconnectionstring'
            }
            {
              name: 'queuename'
              value: ordersQueue.name
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource oderprocessor 'Microsoft.App/containerApps@2022-03-01' = {
  name: oderprocessorAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'cosmosdbconnectionstring'
          value: cosmosDbAccount.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'servicebusconnectionstring'
          value: 'Endpoint=sb://${serviceBus.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys(servicebusEndpoint, serviceBus.apiVersion).primaryKey}'
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
      ingress: {
        external: false
        targetPort: 80
        transport: 'http'
        allowInsecure: true
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: oderprocessorAppName
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Development'
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsights.properties.InstrumentationKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'servicebusconnectionstring'
              secretRef: 'servicebusconnectionstring'
            }
            {
              name: 'cosmosdbconnectionstring'
              secretRef: 'cosmosdbconnectionstring'
            }
            {
              name: 'queuename'
              value: ordersQueue.name
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 30
        rules: [
          {
            name: 'queue-based-autoscaling'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                queueName: ordersQueue.name
                messageCount: '20'
              }
              auth: [
                {
                  secretRef: 'servicebusconnectionstring'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}
