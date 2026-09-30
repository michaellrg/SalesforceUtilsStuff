# Trigger Framework Implementation Guide

## Deployment order

1. Deploy the Apex classes and `TriggerConfig__mdt`.
2. Deploy `TriggerObjectConfig__mdt` and `TriggerFrameworkSettings__mdt`.
3. Deploy layouts and tests.
4. Assign `Trigger User` to runtime users or integration identities.
5. Assign `Trigger Admin` to users who maintain trigger and Flow configuration.

## Activation checklist

1. Use the included `TriggerFrameworkSettings__mdt` record named `Global` and set `Active__c` as required.
2. Create one or more `TriggerConfig__mdt` records for handler classes.
3. Optionally create `TriggerObjectConfig__mdt` records for object-level switches.
4. Set `Execution_Type__c` on each `TriggerConfig__mdt` record to `Apex`, `Flow`, or `Both`.
5. For Flow execution, configure the Flow API name, activation flag, and run context on that same handler record.
6. Optionally create an active `TriggerFrameworkUserException__mdt` record for a user that may bypass the persistent global switch.

## Flow contract

Flows must be autolaunched and define compatible input variables named `newRecords` and `oldRecords`. The framework starts one interview per configured Flow handler per trigger transaction and passes the complete record collections.

## Permission model

`Trigger User` grants access to framework Apex and read access to configuration metadata. `Trigger Admin` grants the same Apex access and configuration-maintenance metadata access.
