# FIDO2_PassKey-Operations

PowerShell operational tooling for FIDO2 passkey lifecycle management.

## Structure

```
scripts/reporting/       # Reporting entry-point scripts
scripts/lifecycling/     # Remediation/lifecycle entry-point scripts
modules/FIDO2PassKeyOperations/  # Shared module (helpers, API wrappers, logging)
docs/                    # Operational documentation
docs/scripts/            # Per-script documentation
config/                  # Configuration files
templates/               # Notification and output templates
tests/                   # Test placeholder
```

## Prerequisites

- PowerShell 7+
- `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore` modules
- Vault registered and unlocked before running scripts

## Getting Started

1. Install prerequisite modules:
   ```powershell
   Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser
   ```
2. Unlock your vault at the start of each session:
   ```powershell
   Unlock-SecretStore
   ```
3. Run scripts from the same unlocked PowerShell session.
