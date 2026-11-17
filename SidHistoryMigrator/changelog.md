# Changelog

## 1.0.8

+ Upd: Remove-SHTask - no longer deletes credentials still in use by remaining tasks
+ Upd: New-SHSession - Added support for UPN account names
+ Upd: Invoke-SHTask - Principals skipped dueto AdminCount are now listed with reason in the action log
+ Upd: Complete help overhaul
+ Fix: Fails to detect already migrated identities
+ Fix: Accidentally includes Contacts in entities to migrate
+ Fix: New-SHSession - Accounts and domain names cannot contain `-` or `_`
+ Fix: New-SHSession - Can fail with international characters in account names

## 1.0.0 (2026-10-27)

+ New: Initial Release
