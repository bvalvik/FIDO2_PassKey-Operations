<#
.SYNOPSIS
    Reports Entra ID users who have not registered a FIDO2 passkey.

.DESCRIPTION
    Connects to Microsoft Graph using delegated (interactive) authentication and
    exports a CSV of all enabled accounts that do not have a FIDO2 security key
    (fido2SecurityKey) registered. No group membership changes are made.

    Required Entra ID role (delegated):
        Authentication Administrator, Security Administrator, Reports Reader,
        Security Reader, or Global Administrator.

    Required Graph scopes (consented at sign-in):
        UserAuthenticationMethod.Read.All
        AuditLog.Read.All

    Auth note:
        This script uses interactive delegated auth (Option B). For a fully
        automated app-registration approach, see future/Graph-Auth-Migration-Plan.md.

.PARAMETER OutputPath
    Directory to write the CSV report. Defaults to C:\Reports\FIDO2_PassKey-Operations.

.PARAMETER CsvFileName
    Output CSV filename. Defaults to a timestamped name.

.PARAMETER UseDeviceCode
    Use device code flow instead of browser-based sign-in (useful in restricted
    environments or when running over a remote session).

.EXAMPLE
    .\Get-FIDO2UnregisteredUsers.ps1
    .\Get-FIDO2UnregisteredUsers.ps1 -OutputPath C:\Reports\FIDO2_PassKey-Operations
    .\Get-FIDO2UnregisteredUsers.ps1 -UseDeviceCode
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'C:\Reports\FIDO2_PassKey-Operations',

    [Parameter(Mandatory = $false)]
    [string]$CsvFileName = "FIDO2-Unregistered-Users-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv",

    [switch]$UseDeviceCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RequiredScopes = @('UserAuthenticationMethod.Read.All', 'AuditLog.Read.All')

# ── Main ─────────────────────────────────────────────────────────────────────

try {
    # Validate output directory
    if (-not (Test-Path -Path $OutputPath)) {
        Write-Host "Creating output directory: $OutputPath"
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $csvPath = Join-Path $OutputPath $CsvFileName

    # Connect to Microsoft Graph (skip if already connected with required scopes)
    $context = Get-MgContext
    $needsConnect = $true

    if ($context) {
        $missing = $RequiredScopes | Where-Object { $context.Scopes -notcontains $_ }
        if (-not $missing) {
            Write-Host "Already connected to Microsoft Graph as: $($context.Account)"
            $needsConnect = $false
        } else {
            Write-Host "Connected but missing scopes ($($missing -join ', ')). Reconnecting..."
            Disconnect-MgGraph | Out-Null
        }
    }

    if ($needsConnect) {
        Write-Host "Connecting to Microsoft Graph (sign-in required)..."
        if ($UseDeviceCode) {
            Connect-MgGraph -Scopes $RequiredScopes -UseDeviceCode -NoWelcome -ErrorAction Stop
        } else {
            Connect-MgGraph -Scopes $RequiredScopes -NoWelcome -ErrorAction Stop
        }
        Write-Host "Connected as: $((Get-MgContext).Account)"
    }

    # Retrieve all user registration details (SDK handles paging via -All)
    Write-Host "Retrieving authentication method registration details (this may take a moment)..."
    $allUsers = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop
    Write-Host "Total records retrieved: $($allUsers.Count)"

    # Filter: enabled accounts without fido2SecurityKey
    $unregistered = $allUsers | Where-Object {
        $_.AccountEnabled -eq $true -and
        $_.MethodsRegistered -notcontains 'fido2SecurityKey'
    }

    Write-Host "Users without FIDO2 passkey: $($unregistered.Count)"

    # Build CSV rows
    $rows = foreach ($u in $unregistered) {
        [PSCustomObject]@{
            UserPrincipalName     = $u.UserPrincipalName
            DisplayName           = $u.UserDisplayName
            Id                    = $u.Id
            AccountEnabled        = $u.AccountEnabled
            IsAdmin               = $u.IsAdmin
            IsMFACapable          = $u.IsMfaCapable
            IsMFARegistered       = $u.IsMfaRegistered
            IsSSPRRegistered      = $u.IsSsprRegistered
            IsPasswordlessCapable = $u.IsPasswordlessCapable
            IsFIDO2Registered     = $false
            MethodsRegistered     = ($u.MethodsRegistered -join '; ')
        }
    }

    # Export
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report saved: $csvPath  ($($rows.Count) users)"

} catch {
    $line = $_.InvocationInfo.ScriptLineNumber
    Write-Error "Script failed at line $line. Details: $($_.Exception.Message)"
    exit 1
}
