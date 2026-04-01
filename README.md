# Copilot CLI Bootstrap for Windows

Bootstrap script that installs the full toolchain for running **GitHub Copilot CLI** with **Azure MCP Server** and **WorkIQ MCP** on Windows.

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

## Usage

Open **PowerShell** (or Windows Terminal) as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\bootstrap-copilot.ps1
```

### Options

| Flag | Description |
|------|-------------|
| `-Force` | Reinstall packages and overwrite existing MCP config entries |
| `-SkipMcpConfig` | Install tools only, don't write MCP configuration |

### Examples

```powershell
# Standard install
.\bootstrap-copilot.ps1

# Force reinstall everything
.\bootstrap-copilot.ps1 -Force

# Install tools only (no MCP config)
.\bootstrap-copilot.ps1 -SkipMcpConfig
```

## Post-Install Steps

After running the script:

1. **Restart your terminal** (PATH changes require a new session)
2. **Authenticate with GitHub:** `gh auth login --web`
3. **Authenticate with Azure:** `az login`
4. **Launch Copilot CLI:** `copilot`
5. **Verify MCP servers:** type `/mcp show` inside Copilot CLI
6. **Accept WorkIQ EULA** (required before first use): `npx -y @microsoft/workiq accept-eula`

## MCP Configuration

The script writes MCP server config to `~/.copilot/mcp-config.json`:

```json
{
  "mcpServers": {
    "Azure MCP Server": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "@azure/mcp@latest", "server", "start"],
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

Both servers use `npx -y` which always fetches the latest version at runtime — no manual updates needed.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `winget` not found | Install App Installer: https://aka.ms/getwinget |
| Tools not in PATH after install | Restart terminal |
| Azure MCP "not authenticated" | Run `az login` before launching Copilot CLI |
| WorkIQ consent error | Tenant admin must grant consent ([instructions](https://github.com/microsoft/work-iq/blob/main/ADMIN-INSTRUCTIONS.md)) |
| Execution policy blocks script | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` |

## Notes

- The script is **idempotent** — safe to re-run. It skips already-installed packages and merges MCP config without overwriting existing entries.
- The old `gh copilot` extension was deprecated in October 2025. This script installs the new standalone `copilot` binary.
- The GitHub MCP server is built into Copilot CLI and does not need configuration.
