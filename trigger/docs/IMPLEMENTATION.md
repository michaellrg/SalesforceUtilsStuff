# Trigger Framework Implementation Guide

## Deployment order

1. Deploy the Apex classes and `TriggerObjectConfig__mdt`.
2. Deploy `TriggerHandlerConfig__mdt` and `TriggerFrameworkSettings__mdt`.
3. Deploy layouts and tests.
4. Assign `Trigger User` to runtime users or integration identities.
5. Assign `Trigger Admin` to users who maintain trigger and Flow configuration.

## Activation checklist

1. Use the included `TriggerFrameworkSettings__mdt` record named `Global` and set `Active__c` as required.
2. Create one or more `TriggerObjectConfig__mdt` records, each with the target Salesforce object API name.
3. Create one or more `TriggerHandlerConfig__mdt` records for handler classes and select the related object configuration in `SObject__c`.
4. Set `Execution_Type__c` on each `TriggerHandlerConfig__mdt` record to `Apex` or `Flow`. The framework does not orchestrate Apex and Flow together; if a Flow invokes Apex, that orchestration remains owned by the Flow.
5. For Flow execution, configure the Flow API name, activation flag, and run context on that same handler record.
6. Optionally set `Active__c` on the related `TriggerObjectConfig__mdt` record to disable all handlers for that object.
7. Optionally create an active `TriggerFrameworkUserException__mdt` record for a user that may bypass the persistent global switch.

## Flow contract

Flows must be autolaunched and define compatible input variables named `newRecords` and `oldRecords`. The framework starts one interview per configured Flow handler per trigger transaction and passes the complete record collections.

## Permission model

`Trigger User` grants access to framework Apex and read access to configuration metadata. `Trigger Admin` grants the same Apex access and configuration-maintenance metadata access.
