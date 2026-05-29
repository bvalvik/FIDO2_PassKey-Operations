<#
.SYNOPSIS
    Reports corp users with no FIDO2 capability registered whatsoever — no hardware
    security key, no platform passkey, and no Microsoft Authenticator passkey.

.DESCRIPTION
    Connects to Microsoft Graph (delegated, interactive or device-code), retrieves
    every user's authentication method registration details, and exports a CSV of
    corp human accounts where IsFIDO2Registered is false across all three methods:

      fido2SecurityKey                         (hardware key — YubiKey etc.)
      passKeyDeviceBoundAuthenticator          (OS platform passkey)
      passKeyDeviceBoundMicrosoftAuthenticator (Authenticator app passkey)

    These users are the highest-priority targets for FIDO2 enrollment — they have
    no passkey credential of any kind and do not appear in either of the other two
    reports.

    Output: No-FIDO2-Users-<timestamp>.csv in the configured output path.

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
    $corpUsers = Get-FIDO2CorpUsers -Users $allUsers -SamLookup $samLookup -Config $config

    # Report filter: none of the three FIDO2/passkey methods are registered
    $noFido2Users = $corpUsers | Where-Object {
        $methods = @($_.MethodsRegistered)
        $methods -notcontains $config.FIDO2_MethodHardware -and
        $methods -notcontains $config.FIDO2_MethodPlatformOS -and
        $methods -notcontains $config.FIDO2_MethodAuthenticator
    }
    Write-Host "Users with no FIDO2 capability registered: $($noFido2Users.Count)"

    # Build output rows and export
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $csvPath   = Join-Path $OutputPath "$($config.FIDO2_NoFIDO2ReportPrefix)-$timestamp.csv"

    $noFido2Users |
        ForEach-Object { New-FIDO2UserRow -User $_ -SamLookup $samLookup -Config $config } |
        Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

    Write-Host "Report saved: $csvPath"

} catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    Write-Error "Script failed at line $line. Details: $($_.Exception.Message)"
    exit 1
}
