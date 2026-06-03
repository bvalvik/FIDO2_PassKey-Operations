# Changelog

All notable changes to FIDO2 PassKey Operations are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-05-29

### Added

- Initial project scaffold: directory structure, README, `.gitignore`, and base shared module (`modules/FIDO2PassKeyOperations/FIDO2PassKeyOperations.psm1`)
- `config/FIDO2PassKeyOperations.config.psd1` — shared non-credential configuration (SMTP settings, output/log paths, Entra app registration Client ID and Tenant ID)
- Shared module functions extracted from inline script logic for reuse across reporting scripts
- `scripts/reporting/Get-NoHardwareKeyUsers.ps1` — reports Entra ID users with no hardware security key (FIDO2 key or other physical token) enrolled; outputs `No-HardwareKey-Users.csv`
- `scripts/reporting/Get-PlatformPasskeyUsers.ps1` — reports users enrolled with only platform passkeys (e.g. Windows Hello for Business) and no hardware key; outputs `PlatformPasskey-Users.csv`
- `scripts/reporting/Get-NoFIDO2Users.ps1` — reports users with zero FIDO2 authentication capability (no hardware key and no platform passkey); outputs `No-FIDO2-Users.csv`
- `future/Graph-Auth-Migration-Plan.md` — plan for migrating from delegated to app-only Graph authentication

### Fixed

- OData pagination: switched to bracket notation `$response.'@odata.nextLink'` to prevent strict mode errors in PowerShell 7
- User scope filter: replaced UPN suffix matching with `onPremisesDomainName eq 'corp.standard.com'` for accurate corporate-scope targeting

### Removed

- Deprecated `Get-FIDO2UnregisteredUsers.ps1`: functionality replaced by the two focused reporting scripts (`Get-NoHardwareKeyUsers.ps1` and `Get-PlatformPasskeyUsers.ps1`)
