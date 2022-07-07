@description('Azure region to deploy in')
param location string = resourceGroup().location

@description('Azure Function App Name')
param functionAppName string = uniqueString(resourceGroup().id)

@description('Azure Storage Account Name')
param storageAccountName string = uniqueString(resourceGroup().id)

@description('App Service Plan Name')
param appSvcPlanName string = 'FunctionPlan'

@description('Application Insights Name')
param appInsightsName string = 'AppInsights'

@description('Storage account SKU name.')
param storageSku string = 'Standard_LRS'

var functionRuntime = 'powerShell'
//Pull vars from key vault instead and/or add as parameters
var clientId = '5897cd85-bf88-4673-8bc9-f2f06d526be8'
var adoServiceConnectionObjId = '9e618eed-1133-415d-8f93-360bbed90d90'
var functionManagedIdentityObjId = 'd2f4e36d-a152-4c9c-9276-6a3e051c0d06'
var keyVaultName = 'kv${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource plan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: appSvcPlanName
  location: location
  kind: 'functionapp,linux'
  sku: {
    name: 'Y1'
  }
  properties: {}
}

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
    enableSoftDelete: false
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: adoServiceConnectionObjId
        'permissions': {
          keys: []
          secrets: [
            'all'
          ]
          certificates: []
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: functionManagedIdentityObjId
        permissions: {
          keys: []
          secrets: [
            'get'
            'list'
          ]
          'certificates': []
        }
      }
    ]
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    enabled: true
    reserved: true
    isXenon: false
    hyperV: false
    siteConfig: {
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 200
      minimumElasticInstanceCount: 0
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: 'denyfunctionb051f2'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=clientsecret)'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
      ]
    }
    httpsOnly: true
  }
}

resource functionApp_authsettingsV2 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: functionApp
  name: 'authsettingsV2'
  location: location
  properties: {
    platform: {
      enabled: true
      runtimeVersion: '~1'
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0'
          clientId: clientId
          clientSecretSettingName: 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'
        }
        login: {
          disableWWWAuthenticate: false
        }
        validation: {
          jwtClaimChecks: {}
          allowedAudiences: [
          'https://management.core.windows.net/'
          ]
          defaultAuthorizationPolicy: {
            allowedPrincipals: {}
          }
        }
      }
    }
    login: {
      routes: {}
      tokenStore: {
        enabled: true
        tokenRefreshExtensionHours: 72
        fileSystem: {}
        azureBlobStorage: {}
      }
      preserveUrlFragmentsForLogins: false
      cookieExpiration: {
        convention: 'FixedTime'
        timeToExpiration: '08:00:00'
      }
      nonce: {
        validateNonce: true
        nonceExpirationInterval: '00:05:00'
      }
    }
    httpSettings: {
      requireHttps: true
      routes: {
        apiPrefix: '/.auth'
      }
      forwardProxy: {
        convention: 'NoProxy'
      }
    }
  }
}


//Add role assignment reader at Tenant root group level


//
// 
//resource resRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
//   name: guid(subscription().subscriptionId, policyContributorRoledef, uniqueString(resourceGroup().name))
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', policyContributorRoledef)
//     principalId: functionApp.identity.principalId
//     principalType: 'ServicePrincipal'
//   }
// }


