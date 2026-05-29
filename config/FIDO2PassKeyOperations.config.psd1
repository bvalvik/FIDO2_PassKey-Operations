# FIDO2PassKeyOperations Configuration File
# -----------------------------------------------------------------------
# Non-sensitive shared configuration values for all FIDO2_PassKey-Operations
# scripts. DO NOT store credentials, tokens, passwords, or secrets here.
# -----------------------------------------------------------------------
@{
    # Output directory for CSV reports
    FIDO2_OutputPath = 'C:\Reports\FIDO2_PassKey-Operations'

    # UPN domain suffix identifying corp (corp.standard.com on-prem) users
    FIDO2_CorpDomain = '@standard.com'

    # Regex applied to UPN prefix to exclude service/non-human accounts.
    # Accounts whose prefix matches any of these terms are excluded.
    # Hyphens and number-suffixed UPNs are intentionally not filtered —
    # these belong to real users with hyphenated names or duplicate accounts.
    FIDO2_ServiceKeywords = '(?i)(service|noreply|test|team|sql|sync|ftp|admin|import|submission)'

    # Microsoft Graph methodsRegistered values for FIDO2 / passkey credentials.
    # All three qualify a user as "FIDO2 registered" (IsFIDO2Registered = true).
    FIDO2_MethodHardware      = 'fido2SecurityKey'                         # External hardware key (YubiKey etc.)
    FIDO2_MethodPlatformOS    = 'passKeyDeviceBoundAuthenticator'          # OS platform passkey (Windows Hello consumer, Face ID/Touch ID via browser)
    FIDO2_MethodAuthenticator = 'passKeyDeviceBoundMicrosoftAuthenticator' # Microsoft Authenticator app passkey (iOS 17+/Android 14+)

    # Output filename prefixes — a timestamp is appended at runtime
    FIDO2_NoHardwareKeyReportPrefix   = 'No-HardwareKey-Users'
    FIDO2_PlatformPasskeyReportPrefix = 'PlatformPasskey-Users'
}
