# Log Framework

Maintainer: Michaell Reis — michaellrg@gmail.com.

## Purpose

Provides a small, reusable logging layer for application errors, warnings, informational events, and payload/callout diagnostics.

## Included components

- `Logger.cls`: fluent logging API and `Log__c` record construction.
- `LoggerFrameworkTest.cls`: focused framework smoke test.
- `Log__c`: log object, fields, record types, and layouts.
- `LogEvent__e`: optional platform event contract for publishing log events.
- `Log User` and `Log Admin` permission sets.

## Usage

```apex
Log__c entry = new Logger()
  .logObject('An application event')
  .push();
```

Use the User permission set for application users that need to create/read logs. Use the Admin permission set for configuration and maintenance users.

The framework does not include application-specific log records or business logging policies.
