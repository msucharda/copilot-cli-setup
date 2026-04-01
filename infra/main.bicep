// ──────────────────────────────────────────────────────────────
// Copilot CLI Test Environment — Main Bicep Template
// Deploys: VNet, NSG, Windows 11 VM with OpenSSH Server
// Scope:   Resource Group (self-contained)
// ──────────────────────────────────────────────────────────────

// ── Parameters ────────────────────────────────────────────────

@description('Environment name used in resource naming.')
@allowed(['dev', 'test'])
param environment string

@description('Azure region for all resources.')
param location string

@description('Workload name used in resource naming.')
param workloadName string

@description('VNet address space CIDR.')
param vnetAddressPrefix string

@description('VM subnet address prefix.')
param vmSubnetAddressPrefix string

@description('Admin username for the VM.')
param adminUsername string

@secure()
@description('Admin password for the VM. Must meet Azure complexity requirements.')
param adminPassword string

@description('Source IP address or CIDR for inbound SSH access.')
param allowedSourceIp string

@description('VM size. Must support Gen2 + Trusted Launch for Windows 11.')
param vmSize string = 'Standard_B2s_v2'

@description('Auto-shutdown time in 24h format (e.g. 1800 for 6:00 PM).')
param autoShutdownTime string = '1800'

@description('Auto-shutdown timezone.')
param autoShutdownTimeZone string = 'UTC'

@description('Optional tags to apply to all resources.')
param tags object = {}

// ── Variables ─────────────────────────────────────────────────

var defaultTags = union({
  environment: environment
  'managed-by': 'bicep'
  project: 'copilot-test'
}, tags)

var vmName = 'vm-copilot-${environment}'
var vnetName = 'vnet-${workloadName}-${environment}'
var subnetName = 'snet-vms-${environment}'
var nsgName = 'nsg-vms-${environment}'

// OpenSSH setup script (inline via Custom Script Extension)
var enableOpenSshScript = loadTextContent('scripts/enable-openssh.ps1')

// ── Network Security Group ────────────────────────────────────

module nsg 'br/public:avm/res/network/network-security-group:0.5.3' = {
  name: 'nsg-${uniqueString(deployment().name, nsgName)}'
  params: {
    name: nsgName
    location: location
    tags: defaultTags
    securityRules: [
      {
        name: 'AllowInboundSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSourceIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyOtherInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ── Virtual Network ──────────────────────────────────────────

module vnet 'br/public:avm/res/network/virtual-network:0.7.1' = {
  name: 'vnet-${uniqueString(deployment().name, vnetName)}'
  params: {
    name: vnetName
    location: location
    tags: defaultTags
    addressPrefixes: [
      vnetAddressPrefix
    ]
    subnets: [
      {
        name: subnetName
        addressPrefix: vmSubnetAddressPrefix
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
    ]
  }
}

// ── Windows 11 VM ─────────────────────────────────────────────

module vm 'br/public:avm/res/compute/virtual-machine:0.16.0' = {
  name: 'vm-${uniqueString(deployment().name, vmName)}'
  params: {
    name: vmName
    location: location
    tags: defaultTags
    availabilityZone: -1
    encryptionAtHost: false
    osType: 'Windows'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    securityType: 'TrustedLaunch'
    secureBootEnabled: true
    vTpmEnabled: true
    imageReference: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-11'
      sku: 'win11-24h2-ent'
      version: 'latest'
    }
    osDisk: {
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    nicConfigurations: [
      {
        nicSuffix: '-nic-01'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: vnet.outputs.subnetResourceIds[0]
            pipConfiguration: {
              publicIpNameSuffix: '-pip-01'
            }
          }
        ]
      }
    ]
    autoShutdownConfig: {
      status: 'Enabled'
      dailyRecurrenceTime: autoShutdownTime
      timeZone: autoShutdownTimeZone
    }
    extensionCustomScriptConfig: {
      enabled: true
      fileData: []
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "${replace(enableOpenSshScript, '"', '\\"')}"'
    }
  }
}

// ── Outputs ──────────────────────────────────────────────────

@description('VM name.')
output vmName string = vm.outputs.name

@description('VM resource ID.')
output vmResourceId string = vm.outputs.resourceId
