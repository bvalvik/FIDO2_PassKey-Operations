<#
.SYNOPSIS
    Reports corp users who have registered a device-bound platform passkey
    (Microsoft Authenticator app OR OS platform passkey) but have NOT yet
    registered a FIDO2 hardware security key.

.DESCRIPTION
    Connects to Microsoft Graph (delegated, interactive or device-code), retrieves
    every user's authentication method registration details, and exports a CSV of
    corp human accounts that have at least one device-bound passkey method but no
    hardware fido2SecurityKey.

    These users are relevant because their passkey credential is tied to a specific
    device, not a portable hardware token. This report can be used to target
    hardware-key adoption campaigns for users who are already passkey-aware.

    Output: PlatformPasskey-Users-<timestamp>.csv in the configured output path.

.PARAMETER OutputPath
    Override the output directory. Defaults to FIDO2_OutputPath in the config file.

.PARAMETER UseDeviceCode
    Use device-code authentication flow instead of browser-based interactive sign-in.
    Required when running in headless or remote sessions.

.NOTES
    Prerequisites:
      - Microsoft.Graph.Authentication module
      - Microsoft.Graph.Reports module
      - Caller account needs: AuditLog.Read.All, UserAuthenticationMethod.Read.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$UseDeviceCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Module Import ─────────────────────────────────────────────────────────────

$modulePath = Join-Path $PSScriptRoot '..\..\modules\FIDO2PassKeyOperations\FIDO2PassKeyOperations.psm1'
Import-Module (Resolve-Path $modulePath -ErrorAction Stop) -Force -ErrorAction Stop

# ── Main ──────────────────────────────────────────────────────────────────────

try {
    # Load configuration
    $config = Get-FIDO2Config

    # Resolve output directory
    if (-not $OutputPath) { $OutputPath = $config.FIDO2_OutputPath }
    New-FIDO2OutputDirectory -Path $OutputPath

    # Graph authentication
    Connect-FIDO2Graph -UseDeviceCode:$UseDeviceCode

    # Data retrieval
    $allUsers  = Get-FIDO2UserRegistrations
    $samLookup = Get-FIDO2SamLookup

    # Base filter: corp human accounts only
    $corpUsers = Get-FIDO2CorpUsers -Users $allUsers -Config $config

    # Report filter: has at least one device-bound passkey, but no hardware key
    $passkeyUsers = $corpUsers | Where-Object {
        $methods = @($_.MethodsRegistered)
        (
            $methods -contains $config.FIDO2_MethodPlatformOS -or
            $methods -contains $config.FIDO2_MethodAuthenticator
        ) -and
        $methods -notcontains $config.FIDO2_MethodHardware
    }
    Write-Host "Users with platform passkey and no hardware key: $($passkeyUsers.Count)"

    # Build output rows and export
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $csvPath   = Join-Path $OutputPath "$($config.FIDO2_PlatformPasskeyReportPrefix)-$timestamp.csv"

    $passkeyUsers |
        ForEach-Object { New-FIDO2UserRow -User $_ -SamLookup $samLookup -Config $config } |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    Write-Host "Report saved: $csvPath"

} catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    Write-Error "Script failed at line $line. Details: $($_.Exception.Message)"
    exit 1
}
