#Requires -Version 5.1

<#
.SYNOPSIS
    ScriptWhitelistGuard - Interactive PowerShell script execution guard with SHA256 whitelist verification
.DESCRIPTION
    This module intercepts external PowerShell script (.ps1) execution at the PSReadLine level,
    validates scripts against a SHA256-based whitelist, and transparently rewrites approved commands
    to execute with -ExecutionPolicy Bypass. Not a security boundary - can be bypassed intentionally.
.NOTES
    Author: Xiamen Moefire Technology Co.,Ltd.
    License: MIT
#>

#region Private Variables and Configuration

# Store the original PSReadLine Enter handler for restoration
$script:OriginalEnterHandler = $null
$script:GuardEnabled = $false

# Get whitelist storage path with environment variable override support
function Get-WhitelistStorePath {
    $envPath = [Environment]::GetEnvironmentVariable('SCRIPT_WHITELIST_GUARD_STORE')
    if ($envPath) {
        return $envPath
    }
    return Join-Path $HOME '.ps-script-whitelist.json'
}

#endregion

#region Whitelist Storage Management

<#
.SYNOPSIS
    Converts PSCustomObject to hashtable for whitelist operations
#>
function ConvertTo-WhitelistHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )
    
    if ($Data -is [hashtable]) {
        return $Data
    }
    
    $hashtable = @{}
    if ($Data) {
        $Data.PSObject.Properties | ForEach-Object {
            $hashtable[$_.Name] = $_.Value
        }
    }
    return $hashtable
}

<#
.SYNOPSIS
    Loads the whitelist from JSON storage
#>
function Get-WhitelistData {
    [CmdletBinding()]
    param()
    
    $storePath = Get-WhitelistStorePath
    
    if (Test-Path $storePath) {
        try {
            $content = Get-Content -Path $storePath -Raw -ErrorAction Stop
            return ($content | ConvertFrom-Json)
        }
        catch {
            Write-Warning "Failed to load whitelist from '$storePath': $_"
            return @{}
        }
    }
    
    return @{}
}

<#
.SYNOPSIS
    Saves the whitelist to JSON storage
#>
function Set-WhitelistData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )
    
    $storePath = Get-WhitelistStorePath
    
    try {
        $storeDir = Split-Path $storePath -Parent
        if (-not (Test-Path $storeDir)) {
            New-Item -Path $storeDir -ItemType Directory -Force | Out-Null
        }
        
        $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $storePath -Encoding UTF8 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Failed to save whitelist to '$storePath': $_"
        return $false
    }
}

<#
.SYNOPSIS
    Computes SHA256 hash of a file
#>
function Get-FileSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    try {
        $hash = Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop
        return $hash.Hash
    }
    catch {
        throw "Failed to compute SHA256 hash for '$Path': $_"
    }
}

#endregion

#region Exported Commands

<#
.SYNOPSIS
    Adds or updates a script in the whitelist with its current SHA256 hash
.PARAMETER Path
    Path to the PowerShell script to whitelist
.EXAMPLE
    Add-ScriptWhitelist -Path "C:\Scripts\npm.ps1"
#>
function Add-ScriptWhitelist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )
    
    # Resolve to absolute path
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    
    if (-not (Test-Path $resolvedPath)) {
        throw "Script not found: $resolvedPath"
    }
    
    $hash = Get-FileSha256 -Path $resolvedPath
    $whitelist = ConvertTo-WhitelistHashtable -Data (Get-WhitelistData)
    
    $whitelist[$resolvedPath] = @{
        Path = $resolvedPath
        Sha256 = $hash
        AddedAt = (Get-Date).ToString('o')
    }
    
    if (Set-WhitelistData -Data $whitelist) {
        Write-Host "✓ Added to whitelist: $resolvedPath" -ForegroundColor Green
        Write-Host "  SHA256: $hash" -ForegroundColor Gray
    }
}

<#
.SYNOPSIS
    Removes a script from the whitelist
.PARAMETER Path
    Path to the PowerShell script to remove from whitelist
.EXAMPLE
    Remove-ScriptWhitelist -Path "C:\Scripts\npm.ps1"
#>
function Remove-ScriptWhitelist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )
    
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $whitelist = ConvertTo-WhitelistHashtable -Data (Get-WhitelistData)
    
    if ($whitelist.ContainsKey($resolvedPath)) {
        $whitelist.Remove($resolvedPath)
        if (Set-WhitelistData -Data $whitelist) {
            Write-Host "✓ Removed from whitelist: $resolvedPath" -ForegroundColor Yellow
        }
    }
    else {
        Write-Warning "Script not found in whitelist: $resolvedPath"
    }
}

<#
.SYNOPSIS
    Tests if a script is in the whitelist and its hash matches
.PARAMETER Path
    Path to the PowerShell script to test
.OUTPUTS
    System.Boolean - True if whitelisted and hash matches, False otherwise
.EXAMPLE
    Test-ScriptWhitelist -Path "C:\Scripts\npm.ps1"
#>
function Test-ScriptWhitelist {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )
    
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    
    if (-not (Test-Path $resolvedPath)) {
        return $false
    }
    
    $whitelist = ConvertTo-WhitelistHashtable -Data (Get-WhitelistData)
    
    if (-not $whitelist.ContainsKey($resolvedPath)) {
        return $false
    }
    
    $currentHash = Get-FileSha256 -Path $resolvedPath
    $storedHash = $whitelist[$resolvedPath].Sha256
    
    return ($currentHash -eq $storedHash)
}

<#
.SYNOPSIS
    Lists all scripts currently in the whitelist
.OUTPUTS
    Array of whitelist entries with Path, Sha256, and AddedAt properties
.EXAMPLE
    Get-ScriptWhitelist
#>
function Get-ScriptWhitelist {
    [CmdletBinding()]
    param()
    
    $whitelist = ConvertTo-WhitelistHashtable -Data (Get-WhitelistData)
    
    if ($whitelist.Count -eq 0) {
        Write-Host "Whitelist is empty. Use Add-ScriptWhitelist to add scripts." -ForegroundColor Yellow
        return @()
    }
    
    $entries = $whitelist.Values | ForEach-Object {
        [PSCustomObject]@{
            Path = $_.Path
            Sha256 = $_.Sha256
            AddedAt = $_.AddedAt
            Exists = (Test-Path $_.Path)
        }
    }
    
    return $entries
}

<#
.SYNOPSIS
    Updates the hash for an existing whitelisted script (convenience wrapper for Add-ScriptWhitelist)
.PARAMETER Path
    Path to the PowerShell script to repair/update
.EXAMPLE
    Repair-ScriptWhitelist -Path "C:\Scripts\npm.ps1"
#>
function Repair-ScriptWhitelist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )
    
    Add-ScriptWhitelist -Path $Path
}

#endregion

#region PSReadLine Integration

<#
.SYNOPSIS
    Finds the appropriate PowerShell executable (pwsh or powershell)
#>
function Get-PowerShellExecutable {
    # Prefer pwsh (PowerShell 7+)
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        return $pwsh.Source
    }
    
    # Fallback to powershell (Windows PowerShell)
    $powershell = Get-Command powershell -ErrorAction SilentlyContinue
    if ($powershell) {
        return $powershell.Source
    }
    
    throw "Cannot find PowerShell executable (pwsh or powershell)"
}

<#
.SYNOPSIS
    Handles whitelisted script execution by rewriting the command
#>
function Invoke-WhitelistedScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory)]
        [object]$CommandAst
    )
    
    $psExe = Get-PowerShellExecutable
    
    # Build argument string from AST
    $arguments = $CommandAst.CommandElements | Select-Object -Skip 1
    $argString = if ($arguments) {
        ($arguments | ForEach-Object { $_.Extent.Text }) -join ' '
    } else {
        ''
    }
    
    $newLine = "& `"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $argString".Trim()
    
    # Replace the buffer and execute
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($newLine)
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

<#
.SYNOPSIS
    Displays error message for blocked script execution
#>
function Show-ScriptBlockedMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )
    
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    
    Write-Host ""
    Write-Host "✗ Script execution blocked by ScriptWhitelistGuard" -ForegroundColor Red
    Write-Host "  Script: $ScriptPath" -ForegroundColor Gray
    
    $whitelist = ConvertTo-WhitelistHashtable -Data (Get-WhitelistData)
    
    if ($whitelist.ContainsKey($ScriptPath)) {
        Write-Host "  Reason: SHA256 hash mismatch (script has been modified)" -ForegroundColor Yellow
    } else {
        Write-Host "  Reason: Script not in whitelist" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "To allow this script, run:" -ForegroundColor Cyan
    Write-Host "  Add-ScriptWhitelist -Path `"$ScriptPath`"" -ForegroundColor White
    Write-Host ""
}

<#
.SYNOPSIS
    Custom PSReadLine Enter handler that intercepts and validates external script execution
#>
function Invoke-WhitelistGuardEnterHandler {
    [CmdletBinding()]
    param()
    
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
    # Early return for empty lines
    if ([string]::IsNullOrWhiteSpace($line)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        return
    }
    
    try {
        # Parse and get first command
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$null, [ref]$null)
        $commandAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $false) | Select-Object -First 1
        
        # Early return if no command or no command name
        if (-not $commandAst -or -not ($commandName = $commandAst.GetCommandName())) {
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }
        
        # Resolve and check if it's an external script
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if (-not $command -or $command.CommandType -ne 'ExternalScript') {
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }
        
        # Handle external script based on whitelist status
        $scriptPath = $command.Source
        if (Test-ScriptWhitelist -Path $scriptPath) {
            Invoke-WhitelistedScript -ScriptPath $scriptPath -CommandAst $commandAst
        } else {
            Show-ScriptBlockedMessage -ScriptPath $scriptPath
        }
    }
    catch {
        Write-Warning "WhitelistGuard error: $_"
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

<#
.SYNOPSIS
    Checks and ensures PSReadLine module is available
#>
function Test-PSReadLineAvailability {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if (-not (Get-Module -Name PSReadLine -ListAvailable)) {
        Write-Error "PSReadLine module is not available. This module requires PSReadLine for interactive command interception."
        return $false
    }
    
    if (-not (Get-Module -Name PSReadLine)) {
        Import-Module PSReadLine -ErrorAction SilentlyContinue
    }
    
    if (-not (Get-Module -Name PSReadLine)) {
        Write-Error "Failed to import PSReadLine. Please ensure PSReadLine is installed and enabled."
        return $false
    }
    
    return $true
}

<#
.SYNOPSIS
    Adds auto-enable block to PowerShell profile
#>
function Add-GuardToProfile {
    [CmdletBinding()]
    param()
    
    $profilePath = $PROFILE.CurrentUserAllHosts
    $beginMarker = "# BEGIN ScriptWhitelistGuard Auto-Enable"
    $endMarker = "# END ScriptWhitelistGuard Auto-Enable"
    
    $profileContent = ""
    if (Test-Path $profilePath) {
        $profileContent = Get-Content -Path $profilePath -Raw
    }
    
    # Check if already present
    if ($profileContent -match [regex]::Escape($beginMarker)) {
        Write-Host "✓ Profile already contains ScriptWhitelistGuard auto-enable block" -ForegroundColor Yellow
        return
    }
    
    # Prepare the profile block
    $guardBlock = @"

$beginMarker
Import-Module ScriptWhitelistGuard -ErrorAction SilentlyContinue
if (Get-Module -Name ScriptWhitelistGuard) {
    Enable-WhitelistGuard
}
$endMarker
"@
    
    try {
        # Create profile directory if needed
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }
        
        # Append to profile
        Add-Content -Path $profilePath -Value $guardBlock -Encoding UTF8
        
        Write-Host "✓ Added auto-enable block to profile: $profilePath" -ForegroundColor Green
        Write-Host "  ScriptWhitelistGuard will now activate automatically in new PowerShell sessions" -ForegroundColor Gray
    }
    catch {
        Write-Error "Failed to update profile: $_"
    }
}

<#
.SYNOPSIS
    Enables the whitelist guard by installing the PSReadLine Enter handler
.PARAMETER Persist
    If specified, adds the guard activation to the user's PowerShell profile for auto-enable on startup
.EXAMPLE
    Enable-WhitelistGuard
.EXAMPLE
    Enable-WhitelistGuard -Persist
#>
function Enable-WhitelistGuard {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Persist
    )
    
    # Check PSReadLine availability
    if (-not (Test-PSReadLineAvailability)) {
        return
    }
    
    # Store original handler if not already stored
    if (-not $script:OriginalEnterHandler -and -not $script:GuardEnabled) {
        $currentBinding = Get-PSReadLineKeyHandler | Where-Object { $_.Key -eq 'Enter' }
        if ($currentBinding) {
            $script:OriginalEnterHandler = $currentBinding.Function
        }
    }
    
    # Set custom Enter handler
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        Invoke-WhitelistGuardEnterHandler
    }
    
    $script:GuardEnabled = $true
    Write-Host "✓ ScriptWhitelistGuard enabled for this session" -ForegroundColor Green
    
    # Handle persistence
    if ($Persist) {
        Add-GuardToProfile
    }
}

<#
.SYNOPSIS
    Disables the whitelist guard by restoring the original PSReadLine Enter handler
.PARAMETER Unpersist
    If specified, removes the guard activation from the user's PowerShell profile
.EXAMPLE
    Disable-WhitelistGuard
.EXAMPLE
    Disable-WhitelistGuard -Unpersist
#>
function Disable-WhitelistGuard {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Unpersist
    )
    
    if (-not $script:GuardEnabled) {
        Write-Host "ScriptWhitelistGuard is not currently enabled" -ForegroundColor Yellow
        return
    }
    
    # Restore original handler or use default AcceptLine
    if ($script:OriginalEnterHandler) {
        Set-PSReadLineKeyHandler -Key Enter -Function $script:OriginalEnterHandler
    }
    else {
        Set-PSReadLineKeyHandler -Key Enter -Function AcceptLine
    }
    
    $script:GuardEnabled = $false
    Write-Host "✓ ScriptWhitelistGuard disabled for this session" -ForegroundColor Yellow
    
    # Handle unpersistence
    if ($Unpersist) {
        $profilePath = $PROFILE.CurrentUserAllHosts
        
        if (-not (Test-Path $profilePath)) {
            Write-Host "Profile does not exist, nothing to remove" -ForegroundColor Gray
            return
        }
        
        $beginMarker = "# BEGIN ScriptWhitelistGuard Auto-Enable"
        $endMarker = "# END ScriptWhitelistGuard Auto-Enable"
        
        $profileContent = Get-Content -Path $profilePath -Raw
        
        # Remove the block using regex
        $pattern = "(?s)`r?`n?$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))`r?`n?"
        
        if ($profileContent -match $pattern) {
            $newContent = $profileContent -replace $pattern, ''
            
            try {
                Set-Content -Path $profilePath -Value $newContent -Encoding UTF8 -NoNewline
                Write-Host "✓ Removed auto-enable block from profile: $profilePath" -ForegroundColor Yellow
            }
            catch {
                Write-Error "Failed to update profile: $_"
            }
        }
        else {
            Write-Host "Auto-enable block not found in profile" -ForegroundColor Gray
        }
    }
}

#endregion

#region Module Initialization

# Export functions
Export-ModuleMember -Function @(
    'Add-ScriptWhitelist',
    'Remove-ScriptWhitelist',
    'Test-ScriptWhitelist',
    'Get-ScriptWhitelist',
    'Repair-ScriptWhitelist',
    'Enable-WhitelistGuard',
    'Disable-WhitelistGuard'
)

#endregion
