param location string = resourceGroup().location

param experimentName string
param aksName string

param experimentConfiguration object

param actionName string

// Define Chaos Studio experiment steps for a basic Virtual Machine Shutdown experiment
param experimentSteps array = [
  {
    name: 'Step 1'
    branches: [
      {
        name: 'Branch 1'
        actions: [
          {
            name: 'urn:csci:microsoft:chaosStudio:TimedDelay/1.0'
            type: 'delay'
            duration: 'PT1M'
          }
          {
            type: 'continuous'
            selectorId: guid('Selector1')
            duration: 'PT6M'
            parameters: [
              {
                key: 'jsonSpec'
                value: '{"action":"pod-failure","mode":"all","selector":{"namespaces":["${experimentConfiguration.namespace}"]},"stressors":{"cpu":{"workers":1,"load":90}}}'
              }
            ]
            name: 'urn:csci:microsoft:azureKubernetesServiceChaosMesh:${actionName}/2.1'
          }
        ]
      }
    ]
  }
]

resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' existing = {
  name: aksName
}

resource chaosTarget 'Microsoft.Chaos/targets@2023-11-01' = {
  name: 'Microsoft-AzureKubernetesServiceChaosMesh'
  location: location
  scope: aks
  properties: {}

  // Define the capability -- in this case, VM Shutdown
  resource chaosCapability 'capabilities' = {
    name: '${actionName}-2.1'
  }
}

//Define the role definition for the Chaos experiment
resource chaosRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: aks
  // In this case, 'Azure Kubernetes Service Cluster Admin Role' -- see https://learn.microsoft.com/azure/role-based-access-control/built-in-roles 
  name: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8'
}

// Define the role assignment for the Chaos experiment
resource chaosRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, chaosExperiment.id, chaosRoleDefinition.id)
  scope: aks
  properties: {
    roleDefinitionId: chaosRoleDefinition.id
    principalId: chaosExperiment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Do not use the latest stable version of the Chaos Experiment resource provider, as it is not even used by the portal yet and 
// will cause an error even if created successfully. Use the preview version instead.
resource chaosExperiment 'Microsoft.Chaos/experiments@2023-10-27-preview' = {
  name: experimentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    selectors: [
      {
        type: 'List'
        id: guid('Selector1')
        targets: [
          {
            id: chaosTarget.id
            type: 'ChaosTarget'
          }
        ]
      }
    ]
    startOnCreation: false // Change this to true if you want to start the experiment on creation
    steps: experimentSteps
  }
}

output servicePrincipalId string = chaosExperiment.identity.principalId
output experimentName string = experimentName
