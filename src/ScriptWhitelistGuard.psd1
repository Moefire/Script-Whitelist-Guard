@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ScriptWhitelistGuard.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a7e8c9f1-4b2d-4e3a-9f8c-1d5e7b9a4c3f'

    # Author of this module
    Author = 'Xiamen Moefire Technology Co.,Ltd.'

    # Company or vendor of this module
    CompanyName = 'Xiamen Moefire Technology Co.,Ltd.'

    # Copyright statement for this module
    Copyright = '(c) 2026 Xiamen Moefire Technology Co.,Ltd. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Interactive PowerShell script execution guard with SHA256 whitelist verification. Intercepts external .ps1 script execution at the PSReadLine level, validates against a whitelist, and transparently rewrites approved commands to execute with -ExecutionPolicy Bypass. Not a security boundary - primarily for workflow safety.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{
            ModuleName = 'PSReadLine'
            ModuleVersion = '2.0.0'
        }
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Add-ScriptWhitelist',
        'Remove-ScriptWhitelist',
        'Test-ScriptWhitelist',
        'Get-ScriptWhitelist',
        'Repair-ScriptWhitelist',
        'Enable-WhitelistGuard',
        'Disable-WhitelistGuard'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Security', 'PowerShell', 'Whitelist', 'ExecutionPolicy', 'PSReadLine', 'Guard', 'Script', 'Validation', 'SHA256')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/Moefire/Script-Whitelist-Guard/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Moefire/Script-Whitelist-Guard'

            # ReleaseNotes of this module
            ReleaseNotes = @'
# Version 1.0.0

Initial release of ScriptWhitelistGuard

## Features
- SHA256-based whitelist validation for external PowerShell scripts
- Interactive command interception via PSReadLine Enter key handler
- Transparent command rewriting for whitelisted scripts (-ExecutionPolicy Bypass)
- Persistent auto-enable via PowerShell profile integration
- Environment variable support for custom whitelist storage path
- Seven core cmdlets for whitelist management
- Cross-platform support (PowerShell 5.1+ and PowerShell 7+)

## Cmdlets
- Add-ScriptWhitelist: Add or update script in whitelist
- Remove-ScriptWhitelist: Remove script from whitelist
- Test-ScriptWhitelist: Verify script whitelist status and hash
- Get-ScriptWhitelist: List all whitelisted scripts
- Repair-ScriptWhitelist: Update hash for modified scripts
- Enable-WhitelistGuard: Activate guard with optional profile persistence
- Disable-WhitelistGuard: Deactivate guard with optional profile cleanup
'@
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''
}
