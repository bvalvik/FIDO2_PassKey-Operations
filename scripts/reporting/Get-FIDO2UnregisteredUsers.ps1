# DEPRECATED — This script has been split into two focused scripts.
#
# Use these replacements instead:
#   Get-NoHardwareKeyUsers.ps1     — corp users with no hardware FIDO2 key
#   Get-PlatformPasskeyUsers.ps1   — corp users with device-bound passkey, no hardware key
#
# Both scripts share common logic via:
#   modules/FIDO2PassKeyOperations/FIDO2PassKeyOperations.psm1
#   config/FIDO2PassKeyOperations.config.psd1
#
# This file is retained only for git history purposes and should not be executed.
throw "This script is deprecated. Use Get-NoHardwareKeyUsers.ps1 or Get-PlatformPasskeyUsers.ps1."
