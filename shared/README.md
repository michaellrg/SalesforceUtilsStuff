# Shared

Maintainer: Michaell Reis — michaellrg@gmail.com.

The shared module contains the cross-framework permission set kept for backward compatibility. Framework-specific permissions are now available inside each module as separate User and Admin permission sets.

- `log` provides `Logger`, `Log__c`, record types, and the optional `LogEvent__e` event.
- `payload` depends on `log` through `PayloadLog`.
- `trigger` is independent from business classes and concrete trigger implementations.

Deploy `log` before `payload` when payload logging is enabled.
