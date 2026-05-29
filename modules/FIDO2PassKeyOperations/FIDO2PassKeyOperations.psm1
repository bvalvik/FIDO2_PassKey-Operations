# FIDO2 PassKey Operations Module
# Shared helpers, API wrappers, and logging for FIDO2_PassKey-Operations scripts.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Configuration ─────────────────────────────────────────────────────────────

function Get-FIDO2Config {
<#
.SYNOPSIS
    Loads the FIDO2PassKeyOperations configuration PSD1 file.
.PARAMETER ConfigPath
    Optional override path. Defaults to config/FIDO2PassKeyOperations.config.psd1
    relative to the module root.
#>
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $PSScriptRoot '..\..\config\FIDO2PassKeyOperations.config.psd1'
    }

    $resolved = Resolve-Path $ConfigPath -ErrorAction Stop
    return Import-PowerShellDataFile -Path $resolved -ErrorAction Stop
}

# ── Graph Authentication ──────────────────────────────────────────────────────

function Connect-FIDO2Graph {
<#
.SYNOPSIS
    Connects to Microsoft Graph with the scopes required for FIDO2 reporting.
    Reuses an existing session if all required scopes are already present.
.PARAMETER UseDeviceCode
    Use device code flow instead of browser-based interactive sign-in.
#>
    param(
        [switch]$UseDeviceCode
    )

    $requiredScopes = @('UserAuthenticationMethod.Read.All', 'AuditLog.Read.All')

    $context = Get-MgContext
    if ($context) {
        $missing = $requiredScopes | Where-Object { $context.Scopes -notcontains $_ }
        if (-not $missing) {
            Write-Host "Already connected to Microsoft Graph as: $($context.Account)"
            return
        }
        Write-Host "Connected but missing scopes ($($missing -join ', ')). Reconnecting..."
        Disconnect-MgGraph | Out-Null
    }

    Write-Host "Connecting to Microsoft Graph (sign-in required)..."
    if ($UseDeviceCode) {
        Connect-MgGraph -Scopes $requiredScopes -UseDeviceCode -NoWelcome -ErrorAction Stop
    } else {
        Connect-MgGraph -Scopes $requiredScopes -NoWelcome -ErrorAction Stop
    }
    Write-Host "Connected as: $((Get-MgContext).Account)"
}

# ── Data Retrieval ────────────────────────────────────────────────────────────

function Get-FIDO2UserRegistrations {
<#
.SYNOPSIS
    Retrieves all user authentication method registration details from Microsoft Graph.
    Handles SDK-level pagination automatically via -All.
#>
    Write-Host "Retrieving authentication method registration details (this may take a moment)..."
    $users = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop
    Write-Host "Total records retrieved: $($users.Count)"
    return $users
}

function Get-FIDO2SamLookup {
<#
.SYNOPSIS
    Builds a hashtable of Entra user ID -> [PSCustomObject]{ SamAccountName, OnPremisesDomainName }
    by paging through the /users endpoint. Returns only entries that have a SAM account.
    OnPremisesDomainName is used by Get-FIDO2CorpUsers to filter to corp.standard.com accounts,
    mirroring the pattern in Get-EntraElevatedUsers.ps1.
#>
    Write-Host "Fetching SAM account names and on-premises domain from user directory..."
    $lookup = @{}
    $uri    = 'https://graph.microsoft.com/v1.0/users?$select=id,onPremisesSamAccountName,onPremisesDomainName&$top=999'

    do {
        $resp = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction Stop
        foreach ($u in $resp.value) {
            if ($u.onPremisesSamAccountName) {
                $lookup[$u.id] = [PSCustomObject]@{
                    SamAccountName       = $u.onPremisesSamAccountName
                    OnPremisesDomainName = $u.onPremisesDomainName
                }
            }
        }
        $uri = $resp['@odata.nextLink']
    } while ($uri)

    Write-Host "SAM lookup built: $($lookup.Count) on-prem accounts found."
    return $lookup
}

# ── Filtering ────────────────────────────────────────────────────────────────

function Get-FIDO2CorpUsers {
<#
.SYNOPSIS
    Applies the base corp-user filter to a collection of userRegistrationDetails.
    Requires onPremisesDomainName -eq FIDO2_OnPremDomain (corp.standard.com) via the
    SAM lookup, mirroring the filter in Get-EntraElevatedUsers.ps1. Also requires a dot
    in the UPN prefix (human name format), excludes service-account keyword UPNs, and
    excludes disabled accounts where AccountEnabled is explicitly false.
.PARAMETER Users
    Full collection from Get-FIDO2UserRegistrations.
.PARAMETER SamLookup
    Hashtable from Get-FIDO2SamLookup (id -> { SamAccountName, OnPremisesDomainName }).
.PARAMETER Config
    Config hashtable from Get-FIDO2Config.
#>
    param(
        [Parameter(Mandatory)]
        [object[]]$Users,

        [Parameter(Mandatory)]
        [hashtable]$SamLookup,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $domain   = $Config.FIDO2_OnPremDomain
    $keywords = $Config.FIDO2_ServiceKeywords

    $filtered = $Users | Where-Object {
        $entry  = $SamLookup[$_.Id]
        $upn    = $_.UserPrincipalName
        $prefix = ($upn -split '@')[0]
        $acct   = $_.PSObject.Properties['AccountEnabled']
        $null -ne $entry -and
        $entry.OnPremisesDomainName -eq $domain -and
        $prefix -match '\.' -and
        $prefix -notmatch $keywords -and
        ($null -eq $acct -or $acct.Value -ne $false)
    }

    Write-Host "Corp human accounts in scope: $($filtered.Count)"
    return $filtered
}

# ── Row Builder ───────────────────────────────────────────────────────────────

function New-FIDO2UserRow {
<#
.SYNOPSIS
    Builds a standardised PSCustomObject CSV row for a single user.
    IsFIDO2Registered is true when any FIDO2/passkey method is present.
    PasskeySource reflects which device-bound method(s) are registered.
.PARAMETER User
    A userRegistrationDetails object from Get-FIDO2UserRegistrations.
.PARAMETER SamLookup
    Hashtable from Get-FIDO2SamLookup (id -> samAccountName).
.PARAMETER Config
    Config hashtable from Get-FIDO2Config.
#>
    param(
        [Parameter(Mandatory)]
        [object]$User,

        [Parameter(Mandatory)]
        [hashtable]$SamLookup,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $methods          = @($User.MethodsRegistered)
    $hasHardware      = $methods -contains $Config.FIDO2_MethodHardware
    $hasPlatformOS    = $methods -contains $Config.FIDO2_MethodPlatformOS
    $hasAuthenticator = $methods -contains $Config.FIDO2_MethodAuthenticator
    $isFido2          = $hasHardware -or $hasPlatformOS -or $hasAuthenticator

    $passkeySource = if ($hasPlatformOS -and $hasAuthenticator) { 'Both' }
                     elseif ($hasAuthenticator)                  { 'Authenticator' }
                     elseif ($hasPlatformOS)                     { 'PlatformOS' }
                     else                                        { 'None' }

    [PSCustomObject]@{
        UserPrincipalName       = $User.UserPrincipalName
        DisplayName             = $User.UserDisplayName
        SamAccountName          = $SamLookup[$User.Id]?.SamAccountName
        Id                      = $User.Id
        AccountEnabled          = $User.PSObject.Properties['AccountEnabled']?.Value
        IsAdmin                 = $User.PSObject.Properties['IsAdmin']?.Value
        IsMFACapable            = $User.PSObject.Properties['IsMfaCapable']?.Value
        IsMFARegistered         = $User.PSObject.Properties['IsMfaRegistered']?.Value
        IsSSPRRegistered        = $User.PSObject.Properties['IsSsprRegistered']?.Value
        IsPasswordlessCapable   = $User.PSObject.Properties['IsPasswordlessCapable']?.Value
        IsFIDO2Registered       = $isFido2
        HasHardwareKey          = $hasHardware
        HasPlatformPasskey      = $hasPlatformOS
        HasAuthenticatorPasskey = $hasAuthenticator
        PasskeySource           = $passkeySource
        MethodsRegistered       = ($methods -join '; ')
    }
}

# ── Output Helpers ────────────────────────────────────────────────────────────

function New-FIDO2OutputDirectory {
<#
.SYNOPSIS
    Ensures the output directory exists, creating it if necessary.
#>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        Write-Host "Creating output directory: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

Export-ModuleMember -Function *
