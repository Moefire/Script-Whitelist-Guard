# Changelog

All notable changes to ScriptWhitelistGuard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-29

### Added

- **Core Whitelist Management**
  - `Add-ScriptWhitelist`: Add or update scripts with SHA256 hash validation
  - `Remove-ScriptWhitelist`: Remove scripts from whitelist
  - `Test-ScriptWhitelist`: Verify script whitelist status and hash integrity
  - `Get-ScriptWhitelist`: List all whitelisted scripts with metadata
  - `Repair-ScriptWhitelist`: Convenience command to update hashes after script modifications

- **Interactive Guard System**
  - `Enable-WhitelistGuard`: Activate PSReadLine Enter key interception
  - `Disable-WhitelistGuard`: Deactivate guard and restore default behavior
  - `-Persist` flag: Auto-enable guard in all new PowerShell sessions via profile integration
  - `-Unpersist` flag: Remove auto-enable block from profile

- **Whitelist Storage**
  - JSON-based persistent storage at `$HOME\.ps-script-whitelist.json`
  - Environment variable override: `SCRIPT_WHITELIST_GUARD_STORE` for custom storage paths
  - SHA256 hash verification for script integrity

- **PSReadLine Integration**
  - Custom Enter key handler with AST-based command parsing
  - Selective interception: only external `.ps1` scripts
  - Transparent command rewriting: whitelisted scripts execute with `-ExecutionPolicy Bypass`
  - Helpful error messages with copy-paste commands for blocked scripts

- **Cross-Platform Support**
  - PowerShell 5.1 (Windows PowerShell) compatibility
  - PowerShell 7+ (pwsh) support
  - Automatic detection of available PowerShell executable

- **Profile Management**
  - Idempotent profile block insertion with clear begin/end markers
  - Safe removal that preserves user's existing profile content
  - Automatic profile file creation if it doesn't exist

- **Testing & Quality**
  - Comprehensive Pester test suite (20+ test cases)
  - Tests for whitelist operations, hash validation, profile persistence
  - GitHub Actions CI/CD workflows
  - PSScriptAnalyzer integration for code quality

- **Documentation**
  - Comprehensive README with examples and security warnings
  - FAQ section covering common scenarios
  - Clear explanation of limitations and non-security-boundary nature

### Security Notes

⚠️ **This is NOT a security boundary.** ScriptWhitelistGuard can be easily bypassed by:
- Running `powershell -ExecutionPolicy Bypass` directly
- Executing scripts non-interactively (scheduled tasks, CI/CD)
- Disabling the guard with `Disable-WhitelistGuard`

For true enforcement, use:
- **AppLocker** or **Windows Defender Application Control (WDAC)** on Windows
- **Code signing** with trusted certificates
- **GPO-based** execution policies

This module is designed for **workflow safety** to prevent accidental execution of untrusted scripts, not as malware protection.

## [Unreleased]

### Planned Features
- Optional logging of all script execution attempts
- Integration with Windows Event Log
- Support for wildcard/regex patterns in whitelist paths
- Team whitelist synchronization helpers
- PowerShell 7+ module cache optimization

---

## Release Tags

- `v1.0.0` - Initial public release

[1.0.0]: https://github.com/YourOrg/ScriptWhitelistGuard/releases/tag/v1.0.0
