# Log Framework Implementation Guide

## Deployment order

1. Deploy the `Log__c` object, fields, record types, layouts, and `LogEvent__e`.
2. Deploy `Logger.cls` and `LoggerFrameworkTest.cls`.
3. Assign either `Log User` or `Log Admin`.

## Runtime contract

`Logger` creates `Log__c` records and can persist them through `push()`. The framework is intentionally agnostic about retention, monitoring, and application-specific log categories.

## Permission model

`Log User` grants Apex access and create/read/edit access without delete. `Log Admin` grants the same framework Apex access plus full maintenance access to `Log__c`.
