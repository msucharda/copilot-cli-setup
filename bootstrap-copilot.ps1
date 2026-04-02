#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap script for GitHub Copilot CLI on Windows.

.DESCRIPTION
    Installs the full toolchain for running GitHub Copilot CLI with
    MCP servers on Windows:

    1. PowerShell 7       (winget)
    2. GitHub CLI          (winget)
    3. Azure CLI           (winget)
    4. Node.js LTS         (winget)  — runtime for MCP servers
    5. GitHub Copilot CLI  (winget)
    6. MCP Servers         (configured in mcp-config.json)
    7. WorkIQ MCP          (npx, configured in mcp-config.json)

    Use -McpVariant to choose which MCP servers to configure:
      AzureMCP  — Azure MCP Server (npx @azure/mcp, 40+ Azure services)
      LearnMCP  — Microsoft Learn MCP (remote HTTP, docs search)
      Both      — Azure MCP + Learn MCP (default)

    Safe to re-run — skips already-installed packages and merges
    MCP config without overwriting existing entries.

.PARAMETER McpVariant
    Which MCP servers to configure: AzureMCP, LearnMCP, or Both (default).

.PARAMETER SkipMcpConfig
    Skip writing the MCP server configuration file.

.PARAMETER Force
    Force reinstall of packages and overwrite existing MCP config entries.

.EXAMPLE
    # Install with both Azure MCP + Learn MCP (default):
    .\bootstrap-copilot.ps1

.EXAMPLE
    # Install with Azure MCP only:
    .\bootstrap-copilot.ps1 -McpVariant AzureMCP

.EXAMPLE
    # Install with Microsoft Learn MCP only:
    .\bootstrap-copilot.ps1 -McpVariant LearnMCP

.EXAMPLE
    # Force reinstall everything:
    .\bootstrap-copilot.ps1 -Force

.NOTES
    Requires WinGet (Windows Package Manager), which ships with
    Windows 11 and modern Windows 10 via the App Installer.
    Download: https://aka.ms/getwinget
#>

[CmdletBinding()]
param(
    [ValidateSet('AzureMCP', 'LearnMCP', 'Both')]
    [string]$McpVariant = 'Both',

    [switch]$SkipMcpConfig,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helper functions ──────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n>> $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "   [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "   [SKIP] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "   [FAIL] $Message" -ForegroundColor Red
}

function Refresh-Path {
    <#
    .SYNOPSIS
        Reload PATH from the registry so newly installed tools are
        visible without restarting the terminal.
    #>
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path    = "$machinePath;$userPath"
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-WinGetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [switch]$Exact
    )

    Write-Step "Installing $Name ($Id)"

    $wingetArgs = @('install', '--id', $Id, '--source', 'winget',
                    '--accept-source-agreements', '--accept-package-agreements')
    if ($Exact) { $wingetArgs += '--exact' }
    if ($Force) { $wingetArgs += '--force' }

    if (-not $Force) {
        # Check if already installed
        $listOutput = & winget list --id $Id --accept-source-agreements 2>&1 | Out-String
        if ($listOutput -match [regex]::Escape($Id)) {
            Write-Skip "$Name is already installed"
            return
        }
    }

    $output = & winget @wingetArgs 2>&1 | Out-String
    if ($output -match 'Successfully installed|already installed|No applicable update') {
        Write-OK "$Name installed successfully"
    }
    elseif ($LASTEXITCODE -ne 0 -and $output -notmatch 'already installed') {
        Write-Fail "Failed to install $Name (exit code $LASTEXITCODE)"
        Write-Host $output -ForegroundColor DarkGray
        $script:installFailed = $true
    }
    else {
        Write-OK "$Name installed successfully"
    }
}

# ── Banner ────────────────────────────────────────────────────

Write-Host @"

 ╔══════════════════════════════════════════════════════════╗
 ║  Copilot CLI Bootstrap for Windows                      ║
 ║  PowerShell 7 · gh · az · Node · Copilot CLI · MCP     ║
 ║  MCP Variant: $($McpVariant.PadRight(46))║
 ╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

# ── Pre-flight ────────────────────────────────────────────────

Write-Step "Pre-flight checks"

if (-not (Test-CommandExists 'winget')) {
    Write-Fail "WinGet (Windows Package Manager) is not available."
    Write-Host @"

    WinGet ships with Windows 11 and modern Windows 10 via App Installer.
    Install it from: https://aka.ms/getwinget
    Or from the Microsoft Store: search for 'App Installer'.
"@ -ForegroundColor Yellow
    exit 1
}
Write-OK "WinGet is available"

# ── Install core tools ────────────────────────────────────────

$script:installFailed = $false

Install-WinGetPackage -Id 'Microsoft.PowerShell'  -Name 'PowerShell 7'
Install-WinGetPackage -Id 'GitHub.cli'             -Name 'GitHub CLI'
Install-WinGetPackage -Id 'Microsoft.AzureCLI'     -Name 'Azure CLI'         -Exact
Install-WinGetPackage -Id 'OpenJS.NodeJS.LTS'      -Name 'Node.js LTS'
Install-WinGetPackage -Id 'GitHub.Copilot'         -Name 'GitHub Copilot CLI'

# ── Abort on install failures ─────────────────────────────────

if ($script:installFailed) {
    Write-Host "`n" -NoNewline
    Write-Fail "One or more packages failed to install. Fix the errors above and re-run."
    exit 1
}

# ── Refresh PATH ──────────────────────────────────────────────

Write-Step "Refreshing PATH"
Refresh-Path
Write-OK "PATH refreshed from registry"

# ── Verify installations ─────────────────────────────────────

Write-Step "Verifying installations"

$tools = @(
    @{ Cmd = 'pwsh';    Name = 'PowerShell 7';    Arg = '--version' }
    @{ Cmd = 'gh';      Name = 'GitHub CLI';      Arg = '--version' }
    @{ Cmd = 'az';      Name = 'Azure CLI';       Arg = 'version'   }
    @{ Cmd = 'node';    Name = 'Node.js';         Arg = '--version' }
    @{ Cmd = 'npm';     Name = 'npm';             Arg = '--version' }
    @{ Cmd = 'npx';     Name = 'npx';             Arg = '--version' }
    @{ Cmd = 'copilot'; Name = 'Copilot CLI';     Arg = '--version' }
)

$allOk = $true
foreach ($t in $tools) {
    if (Test-CommandExists $t.Cmd) {
        try {
            $ver = & $t.Cmd $t.Arg 2>&1 | Select-Object -First 1
            Write-OK "$($t.Name): $ver"
        }
        catch {
            Write-OK "$($t.Name): installed"
        }
    }
    else {
        Write-Fail "$($t.Name) ($($t.Cmd)) not found in PATH"
        $allOk = $false
    }
}

if (-not $allOk) {
    Write-Host "`n   Some tools not found. You may need to restart your terminal." -ForegroundColor Yellow
}

# ── Configure MCP servers ────────────────────────────────────

if (-not $SkipMcpConfig) {
    Write-Step "Configuring MCP servers for Copilot CLI"

    $mcpConfigDir  = Join-Path $env:USERPROFILE '.copilot'
    $mcpConfigFile = Join-Path $mcpConfigDir 'mcp-config.json'

    if (-not (Test-Path $mcpConfigDir)) {
        New-Item -Path $mcpConfigDir -ItemType Directory -Force | Out-Null
        Write-OK "Created $mcpConfigDir"
    }

    # Desired MCP server entries based on variant
    $desiredServers = [ordered]@{}

    # Azure MCP Server — local process via npx (40+ Azure service tools)
    if ($McpVariant -in @('AzureMCP', 'Both')) {
        $desiredServers['Azure MCP Server'] = [ordered]@{
            type    = 'local'
            command = 'npx'
            args    = @('-y', '@azure/mcp@latest', 'server', 'start')
            tools   = @('*')
        }
    }

    # Microsoft Learn MCP — remote HTTP endpoint (docs search, code samples)
    if ($McpVariant -in @('LearnMCP', 'Both')) {
        $desiredServers['microsoft-learn'] = [ordered]@{
            type = 'http'
            url  = 'https://learn.microsoft.com/api/mcp'
            tools = @('*')
        }
    }

    # WorkIQ MCP — always included (Microsoft 365 intelligence)
    $desiredServers['workiq'] = [ordered]@{
        type    = 'local'
        command = 'npx'
        args    = @('-y', '@microsoft/workiq@latest', 'mcp')
        tools   = @('*')
    }

    # Load or initialize config
    $config = $null
    if (Test-Path $mcpConfigFile) {
        try {
            $raw = Get-Content $mcpConfigFile -Raw
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $config = $raw | ConvertFrom-Json -AsHashtable
            }
            else {
                # PowerShell 5.1 fallback: convert PSCustomObject to hashtable
                $obj = $raw | ConvertFrom-Json
                $config = @{}
                foreach ($prop in $obj.PSObject.Properties) {
                    $config[$prop.Name] = $prop.Value
                }
            }
        }
        catch {
            Write-Host "   Warning: existing mcp-config.json is invalid, backing up" -ForegroundColor Yellow
            Copy-Item $mcpConfigFile "$mcpConfigFile.bak" -Force
            $config = $null
        }
    }

    if ($null -eq $config) {
        $config = [ordered]@{}
    }

    if (-not $config.Contains('mcpServers')) {
        $config['mcpServers'] = [ordered]@{}
    }

    # Convert mcpServers to a mutable hashtable if it came from JSON as PSCustomObject
    if ($config['mcpServers'] -is [PSCustomObject]) {
        $existing = [ordered]@{}
        foreach ($prop in $config['mcpServers'].PSObject.Properties) {
            $existing[$prop.Name] = $prop.Value
        }
        $config['mcpServers'] = $existing
    }

    # Remove variant-managed servers not in current selection
    # (so switching from Both → AzureMCP removes the Learn entry)
    $variantManagedKeys = @('Azure MCP Server', 'microsoft-learn')
    foreach ($key in $variantManagedKeys) {
        if ($config['mcpServers'].Contains($key) -and -not $desiredServers.Contains($key)) {
            $config['mcpServers'].Remove($key)
            Write-OK "MCP server '$key' removed (not in $McpVariant variant)"
        }
    }

    # Merge desired servers
    foreach ($name in $desiredServers.Keys) {
        if ($config['mcpServers'].Contains($name) -and -not $Force) {
            Write-Skip "MCP server '$name' already configured"
        }
        else {
            $config['mcpServers'][$name] = $desiredServers[$name]
            Write-OK "MCP server '$name' configured"
        }
    }

    # Write config
    $json = $config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($mcpConfigFile, $json, [System.Text.Encoding]::UTF8)
    Write-OK "MCP config written to $mcpConfigFile"
}

# ── Post-install instructions ─────────────────────────────────

Write-Host @"

 ╔══════════════════════════════════════════════════════════╗
 ║  Installation Complete!                                 ║
 ╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

if (-not $allOk) {
    Write-Host @"
 ⚠  Some tools were not found in PATH. Close and reopen
    your terminal, then re-run this script to verify.
"@ -ForegroundColor Yellow
}

Write-Host @"

 Next steps:

   1. RESTART YOUR TERMINAL (required for PATH changes to take effect)

   2. Authenticate with GitHub:
      > gh auth login --web

   3. Authenticate with Azure:
      > az login

   4. Launch Copilot CLI:
      > copilot

   5. Verify MCP servers are loaded (inside Copilot CLI):
      > /mcp show

   6. Accept WorkIQ EULA (required before first use):
      Inside Copilot CLI, WorkIQ will prompt for EULA acceptance,
      or run from a terminal: npx -y @microsoft/workiq accept-eula

   7. (Optional) Install Learn MCP as a Copilot plugin (adds agent skills):
      > /plugin install microsoftdocs/mcp

   MCP variant: $McpVariant
   MCP config:  ~\.copilot\mcp-config.json

"@ -ForegroundColor White
