param name string
param location string

resource loadTesting 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: name
  location: location
  tags: {
    DemoPerformance: 'Azure Load Testing'
  }
  identity: {
    type: 'SystemAssigned'
  }
}
