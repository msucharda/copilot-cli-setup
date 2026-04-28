# Copilot CLI Bootstrap for Windows

Bootstrap script that installs the full toolchain for running **GitHub Copilot CLI** with MCP servers on Windows. Supports two MCP variants:

| Variant | Server | Transport | What it does |
|---------|--------|-----------|-------------|
| **AzureMCP** | Azure MCP Server (`@azure/mcp`) | Local (npx) | 40+ Azure service tools — deploy, query, manage resources |
| **LearnMCP** | Microsoft Learn MCP | Remote HTTP | Search official Microsoft docs, fetch code samples |
| **Both** *(default)* | Both servers | Local + HTTP | Full coverage: Azure operations + documentation |

WorkIQ MCP (Microsoft 365 intelligence) is always included regardless of variant.

## What It Installs

| Tool | Package ID | Purpose |
|------|-----------|---------|
| PowerShell 7 | `Microsoft.PowerShell` | Required runtime for Copilot CLI on Windows |
| GitHub CLI | `GitHub.cli` | GitHub authentication and workflow management |
| Azure CLI | `Microsoft.AzureCLI` | Azure authentication (used by Azure MCP Server) |
| Node.js LTS | `OpenJS.NodeJS.LTS` | Runtime for MCP servers (npx) |
| Copilot CLI | `GitHub.Copilot` | The agentic AI assistant |
| Azure MCP Server | `@azure/mcp` (npx) | 40+ Azure service integrations for Copilot |
| WorkIQ MCP | `@microsoft/workiq` (npx) | Microsoft 365 intelligence (email, calendar, Teams) |

## Prerequisites

- **Windows 10 (1809+) or Windows 11**
- **WinGet** — ships with Windows 11 and modern Windows 10 via App Installer ([download](https://aka.ms/getwinget))
- **Active GitHub Copilot subscription**
- **Azure subscription** (for Azure MCP Server)

## Quick Start (one-liner)

Open **PowerShell** (or Windows Terminal) as Administrator and paste:

```powershell
irm https://raw.githubusercontent.com/msucharda/copilot-cli-setup/refs/heads/master/bootstrap-copilot.ps1 | iex
```

## Usage

If you've cloned the repo locally:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\bootstrap-copilot.ps1
```

### Options

| Flag | Description |
|------|-------------|
| `-McpVariant` | `AzureMCP`, `LearnMCP`, or `Both` (default). Controls which MCP servers are configured. |
| `-Force` | Reinstall packages and overwrite existing MCP config entries |
| `-SkipMcpConfig` | Install tools only, don't write MCP configuration |

### Examples

```powershell
# Default — both Azure MCP + Learn MCP + WorkIQ
.\bootstrap-copilot.ps1

# Azure MCP only (resource management tools)
.\bootstrap-copilot.ps1 -McpVariant AzureMCP

# Learn MCP only (documentation search)
.\bootstrap-copilot.ps1 -McpVariant LearnMCP
```

## Post-Install Steps

1. **Restart your terminal** (PATH changes require a new session)
2. **Authenticate with GitHub:** `gh auth login --web`
3. **Authenticate with Azure:** `az login`
4. **Launch Copilot CLI:** `copilot`
5. **Verify MCP servers:** type `/mcp show` inside Copilot CLI
6. **Accept WorkIQ EULA** (required before first use): `npx -y @microsoft/workiq accept-eula`

## MCP Configuration

The script writes MCP server config to `~/.copilot/mcp-config.json`. The contents depend on the `-McpVariant` chosen:

### Both (default)

```json
{
  "mcpServers": {
    "azure": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start"],
      "tools": ["*"]
    },
    "microsoft-learn": {
      "type": "http",
      "url": "https://learn.microsoft.com/api/mcp",
      "tools": ["*"]
    },
    "workiq": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@microsoft/workiq@latest", "mcp"],
      "tools": ["*"]
    }
  }
}
```

- **azure** — local process via npx, requires `az login` for auth
- **Microsoft Learn MCP** — remote HTTP endpoint, no auth needed, free
- **WorkIQ** — local process via npx, requires M365 tenant admin consent

---

## Testing with an Azure VM

A self-contained Azure environment is included for testing the bootstrap script on a real Windows 11 VM via SSH.

### Architecture

```
┌──────────────────────────────────────────────────────┐
│  Resource Group: rg-copilot-test-dev                 │
│                                                      │
│  NSG (SSH from your IP)                              │
│  VNet 10.2.0.0/24 → Subnet 10.2.0.0/26              │
│                                                      │
│  ┌────────────────────────────────────┐              │
│  │ vm-copilot-dev                     │              │
│  │ Windows 11 Enterprise 24H2        │              │
│  │ Standard_B2s · OpenSSH Server     │              │
│  │ Public IP · Auto-shutdown 18:00   │              │
│  └────────────────────────────────────┘              │
└──────────────────────────────────────────────────────┘
```

### Quick Start

```bash
# Set required environment variables
export ADMIN_PASSWORD='YourC0mplexP@ssword!'
export ALLOWED_SOURCE_IP=$(curl -s ifconfig.me)/32

# Accept Windows 11 marketplace terms (one-time)
make accept-terms

# Deploy the VM
make deploy

# Copy bootstrap script and run it
make deploy-script

# Verify all tools installed correctly
make test-remote

# SSH in for interactive testing
make ssh

# Tear down when done
make destroy
```

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make lint` | Lint Bicep files |
| `make build` | Compile Bicep (syntax check) |
| `make accept-terms` | Accept Windows 11 marketplace image terms |
| `make deploy` | Deploy the VM to Azure |
| `make destroy` | Delete the resource group |
| `make ip` | Show the VM's public IP |
| `make ssh` | SSH into the VM |
| `make deploy-script` | Copy and run `bootstrap-copilot.ps1` on the VM |
| `make test-remote` | Full end-to-end test: deploy script + verify all tools |

### Why Windows 11 (not Windows Server)?

- Windows 11 ships with **WinGet** (App Installer) out of the box
- Windows Server 2022 does **NOT** have WinGet — only Server 2025 added it
- Windows 11 has only **Windows PowerShell 5.1** pre-installed (not PS7), which matches the real target scenario
- The `win11-24h2-ent` image is available as a standard Azure Marketplace image

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `winget` not found | Install App Installer: https://aka.ms/getwinget |
| Tools not in PATH after install | Restart terminal |
| Azure MCP "not authenticated" | Run `az login` before launching Copilot CLI |
| WorkIQ consent error | Tenant admin must grant consent ([instructions](https://github.com/microsoft/work-iq/blob/main/ADMIN-INSTRUCTIONS.md)) |
| Execution policy blocks script | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |
| SSH connection refused | Wait 2-3 min after deploy for CSE to finish; check `make ip` |
| Marketplace terms error | Run `make accept-terms` first |

## Notes

- The bootstrap script is **idempotent** — safe to re-run
- The old `gh copilot` extension was deprecated in October 2025; this installs the new standalone `copilot` binary
- The GitHub MCP server is built into Copilot CLI and does not need configuration
- The VM auto-shuts down at 18:00 UTC to save costs; run `make destroy` when done testing
