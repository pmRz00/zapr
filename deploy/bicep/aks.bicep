// params
@description('The DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string = 'zapr01'

@description('The name of the Managed Cluster resource.')
param clusterName string = 'zapraks01'

@description('Specifies the Azure location where the key vault should be created.')
param location string = resourceGroup().location

@minValue(1)
@maxValue(50)
@description('The number of nodes for the cluster. 1 Node is enough for Dev/Test and minimum 3 nodes, is recommended for Production')
param agentCount int = 1

@description('The size of the Virtual Machine.')
param agentVMSize string = 'Standard_D2_v3'

@minLength(5)
@maxLength(50)
@description('Specifies the name of the azure container registry.')
param acrName string = 'acr001${uniqueString(resourceGroup().id)}' // must be globally unique

@description('Enable admin user that have push / pull permission to the registry.')
param acrAdminUserEnabled bool = false

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Basic'

// azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2019-12-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
  }
}


// vars
var kubernetesVersion = '1.19.7'
var subnetRef = '${vn.id}/subnets/${subnetName}'
var addressPrefix = '20.0.0.0/16'
var subnetName = 'Subnet01'
var subnetPrefix = '20.0.0.0/24'
var virtualNetworkName = 'MyVNET01'
var nodeResourceGroup = 'rg-${dnsPrefix}-${clusterName}'
var tags = {
  environment: 'production'
  projectCode: 'zapr-dev'
}
var agentPoolName = 'agentpool01'

// Azure virtual network
resource vn 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// Azure kubernetes service
resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: agentPoolName
        count: agentCount
        mode: 'System'
        vmSize: agentVMSize
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        enableAutoScaling: false
        vnetSubnetID: subnetRef
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    nodeResourceGroup: nodeResourceGroup
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

output id string = aks.id
output apiServerAddress string = aks.properties.fqdn
output acrLoginServer string = acr.properties.loginServer
