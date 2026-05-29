# Graph Authentication Migration Plan

## Current State (Option B — Delegated Interactive Auth)

The `Get-FIDO2UnregisteredUsers.ps1` script currently uses **delegated authentication**
via `Connect-MgGraph`. The operator signs in interactively with their Entra ID account.

### Requirements
- Operator must have one of these Entra roles:
  - Authentication Administrator
  - Security Administrator
  - Reports Reader
  - Security Reader
  - Global Administrator
- Graph scopes consented at sign-in:
  - `UserAuthenticationMethod.Read.All`
  - `AuditLog.Read.All`
- Modules installed: `Microsoft.Graph.Authentication`, `Microsoft.Graph.Reports`

### How to run
```powershell
.\scripts\reporting\Get-FIDO2UnregisteredUsers.ps1
# or with device code (remote/headless sessions):
.\scripts\reporting\Get-FIDO2UnregisteredUsers.ps1 -UseDeviceCode
```

### Limitations
- Requires a browser or device code sign-in on each new session
- Cannot be fully automated or scheduled without operator interaction
- Token lifetime is tied to the interactive session

---

## Future State (Option A — App Registration / Client Credentials)

Migrate to a service principal with application permissions for fully unattended execution.

### Steps to implement
1. **Create an app registration** in Entra ID:
   - Name: `FIDO2-PassKey-Operations`
   - No redirect URI needed (daemon/service flow)

2. **Add application permissions** (not delegated) and grant admin consent:
   - `AuditLog.Read.All`
   - `UserAuthenticationMethod.Read.All`

3. **Create a client secret** on the app registration.

4. **Store secrets in HYPRVault**:
   ```powershell
   Unlock-SecretStore
   Set-Secret -Name 'FIDO2_ClientId'     -Vault HYPRVault -Secret '<app-client-id>'
   Set-Secret -Name 'FIDO2_ClientSecret' -Vault HYPRVault -Secret '<client-secret>'
   Set-Secret -Name 'FIDO2_TenantId'     -Vault HYPRVault -Secret '<tenant-id>'
   ```

5. **Update the script** to use `Invoke-RestMethod` client credentials flow:
   - Remove `Connect-MgGraph` / `Get-MgReport*` SDK calls
   - Add `Get-VaultSecret` helper and `Get-GraphToken` (client_credentials grant)
   - Call `https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails`
     directly with a Bearer token
   - Handle `@odata.nextLink` pagination manually

### Benefits over Option B
- Fully automated / schedulable (no interactive prompt)
- No dependency on a specific operator's role or active session
- Token scoped precisely to what the app registration permits
- Consistent with the HYPR-Operations pattern

### Decision criteria for cutover
- [ ] App registration created and admin consent granted
- [ ] Vault secrets stored and verified
- [ ] Script updated and tested end-to-end with client credentials
- [ ] Option B (`Connect-MgGraph`) code path removed
