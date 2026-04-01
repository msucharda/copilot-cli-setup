using './main.bicep'

// ──────────────────────────────────────────────────────────────
// Copilot CLI Test — Dev Environment Parameters
// ──────────────────────────────────────────────────────────────

param environment = 'dev'
param location = 'swedencentral'
param workloadName = 'copilot-test'

// ── Networking ───────────────────────────────────────────────

param vnetAddressPrefix = '10.2.0.0/24'
param vmSubnetAddressPrefix = '10.2.0.0/26'

// ── VM Admin ─────────────────────────────────────────────────

param adminUsername = 'copilotadmin'
param adminPassword = readEnvironmentVariable('ADMIN_PASSWORD')

// ── Network Access ───────────────────────────────────────────

param allowedSourceIp = readEnvironmentVariable('ALLOWED_SOURCE_IP')

// ── VM Size (burstable, cost-effective for testing) ──────────

param vmSize = 'Standard_B2s_v2'

// ── Auto-shutdown ────────────────────────────────────────────

param autoShutdownTime = '1800'
param autoShutdownTimeZone = 'UTC'

// ── Tags ─────────────────────────────────────────────────────

param tags = {
  project: 'copilot-cli-test'
  owner: 'msucharda'
  purpose: 'Test bootstrap-copilot.ps1 via SSH'
}
