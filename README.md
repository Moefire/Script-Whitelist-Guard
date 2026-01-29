# ScriptWhitelistGuard

[![CI](https://github.com/Moefire/Script-Whitelist-Guard/actions/workflows/ci.yml/badge.svg)](https://github.com/Moefire/Script-Whitelist-Guard/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/ScriptWhitelistGuard)](https://www.powershellgallery.com/packages/ScriptWhitelistGuard)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Interactive PowerShell script execution guard with SHA256 whitelist verification**

ScriptWhitelistGuard is a PowerShell module that intercepts external `.ps1` script execution at the PSReadLine level, validates scripts against a SHA256-based whitelist, and transparently rewrites approved commands to execute with `-ExecutionPolicy Bypass`. It's designed as a workflow safety tool, not a security boundary.

## 🎯 What Does It Do?

When you type a command like `npm -v` or `.\my-script.ps1 args...` and press Enter:

1. **Intercepts** the command before execution (via PSReadLine Enter key handler)
2. **Detects** if it's an external PowerShell script (`.ps1`)
3. **Validates** the script against your whitelist using SHA256 hash
4. **Allows** execution by transparently rewriting to: `pwsh -NoProfile -ExecutionPolicy Bypass -File "script.ps1" args...`
5. **Blocks** execution if not whitelisted or hash mismatch, displaying a helpful error with the exact command to whitelist it

### How It Works

```
User Input: npm -v
     ↓
[PSReadLine Enter Handler]
     ↓
Resolve command → C:\Program Files\nodejs\npm.ps1
     ↓
Check whitelist & SHA256 hash
     ↓
✓ Match? → Rewrite: & "pwsh" -NoProfile -ExecutionPolicy Bypass -File "C:\...\npm.ps1" -v
✗ No match? → Block & show: Add-ScriptWhitelist -Path "C:\...\npm.ps1"
```

## 🚀 Quick Start

### Installation

```powershell
# From PowerShell Gallery (recommended)
Install-Module -Name ScriptWhitelistGuard -Scope CurrentUser

# Or clone and import manually
git clone https://github.com/YourOrg/ScriptWhitelistGuard
Import-Module ./ScriptWhitelistGuard/src/ScriptWhitelistGuard.psd1
```

### Enable for Current Session

```powershell
Import-Module ScriptWhitelistGuard
Enable-WhitelistGuard
```

### Enable Permanently (Auto-Start on All New Sessions)

```powershell
Enable-WhitelistGuard -Persist
```

This adds an auto-enable block to your PowerShell profile (`$PROFILE.CurrentUserAllHosts`). From now on, every new PowerShell window will automatically activate the guard.

### Disable Permanently

```powershell
Disable-WhitelistGuard -Unpersist
```

## 📋 Whitelist Management

### Add a Script to Whitelist

```powershell
# Example: Whitelist Node.js npm script
Add-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"

# Output:
# ✓ Added to whitelist: C:\Program Files\nodejs\npm.ps1
#   SHA256: a1b2c3d4e5f6...
```

### Test If Script Is Whitelisted

```powershell
Test-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"
# Returns: True or False
```

### List All Whitelisted Scripts

```powershell
Get-ScriptWhitelist

# Output:
# Path                                    Sha256                            AddedAt              Exists
# ----                                    ------                            -------              ------
# C:\Program Files\nodejs\npm.ps1         a1b2c3d4e5f6...                   2026-01-29T10:30:00Z True
```

### Remove from Whitelist

```powershell
Remove-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"
```

### Repair/Update Hash After Script Changes

```powershell
# When a script is updated (e.g., Node.js upgrade), its hash changes
# Update the whitelist entry:
Repair-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"

# Equivalent to:
Add-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"
```

## 🔧 Common Scenarios

### Scenario 1: First Time Running `npm`

```powershell
PS> npm -v

✗ Script execution blocked by ScriptWhitelistGuard
  Script: C:\Program Files\nodejs\npm.ps1
  Reason: Script not in whitelist

To allow this script, run:
  Add-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"

PS> Add-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"
✓ Added to whitelist: C:\Program Files\nodejs\npm.ps1
  SHA256: a1b2c3d4e5f6...

PS> npm -v
10.2.4
```

### Scenario 2: Node.js Update Breaks npm

After updating Node.js, the `npm.ps1` script changes, causing a hash mismatch:

```powershell
PS> npm -v

✗ Script execution blocked by ScriptWhitelistGuard
  Script: C:\Program Files\nodejs\npm.ps1
  Reason: SHA256 hash mismatch (script has been modified)

To allow this script, run:
  Add-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"

PS> Repair-ScriptWhitelist -Path "C:\Program Files\nodejs\npm.ps1"
✓ Added to whitelist: C:\Program Files\nodejs\npm.ps1
  SHA256: z9y8x7w6v5u4...

PS> npm -v
11.0.0
```

### Scenario 3: Custom Whitelist Storage Location

Use an environment variable to store the whitelist in a custom location (e.g., for team-shared whitelists):

```powershell
# Set before importing the module
$env:SCRIPT_WHITELIST_GUARD_STORE = "C:\TeamConfig\shared-whitelist.json"

Import-Module ScriptWhitelistGuard
Enable-WhitelistGuard
```

## ⚙️ Advanced Configuration

### Custom Whitelist Storage Path

By default, the whitelist is stored at `$HOME\.ps-script-whitelist.json`. To use a custom path:

```powershell
$env:SCRIPT_WHITELIST_GUARD_STORE = "D:\MyConfig\whitelist.json"
```

Set this environment variable **before** importing the module or add it to your profile.

### Profile Persistence Details

When you run `Enable-WhitelistGuard -Persist`, the module adds the following block to your profile:

```powershell
# BEGIN ScriptWhitelistGuard Auto-Enable
Import-Module ScriptWhitelistGuard -ErrorAction SilentlyContinue
if (Get-Module -Name ScriptWhitelistGuard) {
    Enable-WhitelistGuard
}
# END ScriptWhitelistGuard Auto-Enable
```

- **Idempotent**: Running `-Persist` multiple times won't create duplicate blocks
- **Safe Removal**: `Disable-WhitelistGuard -Unpersist` removes only this block, preserving your other profile content

## 🛡️ Security & Limitations

### ⚠️ NOT A SECURITY BOUNDARY

**Important:** This module is **not** a security feature and can be easily bypassed:

- Any user can run `powershell -ExecutionPolicy Bypass -File script.ps1` directly
- The guard only intercepts interactive PSReadLine input (not scripts, scheduled tasks, or CI/CD)
- Users with profile write access can disable it with `Disable-WhitelistGuard -Unpersist`
- It's designed for **workflow safety** (prevent accidental execution of untrusted scripts), not malware prevention

### For True Enforcement

If you need genuine script execution control:

- **Windows:** Use **AppLocker** or **Windows Defender Application Control (WDAC)**
- **Enterprise:** Implement GPO-based execution policies
- **Code Signing:** Require signed scripts with trusted certificates

ScriptWhitelistGuard is a convenience tool, not a replacement for these security measures.

## 🔍 What Gets Intercepted?

### Intercepted (External `.ps1` Scripts)

- ✅ `npm -v` (resolves to `npm.ps1`)
- ✅ `.\my-script.ps1`
- ✅ `C:\Scripts\build.ps1 -Verbose`

### NOT Intercepted

- ❌ Built-in cmdlets: `Get-Process`, `Set-Location`
- ❌ Functions defined in your session
- ❌ Aliases: `ls`, `dir`, `gci`
- ❌ Executables: `node`, `python.exe`, `git`
- ❌ Non-interactive execution: scripts run via Task Scheduler, CI/CD pipelines
- ❌ Commands pasted or run programmatically (not typed interactively)

## 📦 Exported Commands

| Command | Description |
|---------|-------------|
| `Add-ScriptWhitelist` | Add or update a script in the whitelist with its current SHA256 hash |
| `Remove-ScriptWhitelist` | Remove a script from the whitelist |
| `Test-ScriptWhitelist` | Check if a script is whitelisted and hash matches |
| `Get-ScriptWhitelist` | List all whitelisted scripts with metadata |
| `Repair-ScriptWhitelist` | Update the hash for an existing whitelisted script (alias for Add) |
| `Enable-WhitelistGuard` | Activate the guard for the current session (use `-Persist` for auto-enable) |
| `Disable-WhitelistGuard` | Deactivate the guard (use `-Unpersist` to remove from profile) |

## 🧪 Testing

Run Pester tests locally:

```powershell
# Install Pester if needed
Install-Module Pester -MinimumVersion 5.0.0 -Force

# Run tests
Invoke-Pester -Path ./tests
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes with tests
4. Ensure CI passes: `Invoke-Pester` and `Invoke-ScriptAnalyzer`
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [PSReadLine](https://github.com/PowerShell/PSReadLine) - Command-line editing for PowerShell
- [PowerShell Execution Policies](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies)

---

**Made with ❤️ for the PowerShell community**
