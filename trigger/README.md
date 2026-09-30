# Trigger Framework

Maintainer: Michaell Reis — michaellrg@gmail.com.

## Purpose

Provides trigger context helpers, configurable handler dispatch, activation controls, and optional Flow integration.

## Configuration layers

- `TriggerConfig__mdt`: enables or disables an individual handler, references a `TriggerObjectConfig__mdt` record through `SObject__c`, and selects `Execution_Type__c` as either `Apex` or `Flow` for that handler record. The framework does not compose Apex and Flow; any Flow-to-Apex orchestration belongs to the Flow.
- `TriggerObjectConfig__mdt`: enables or disables the entire framework for one SObject.
- `TriggerFrameworkSettings__mdt`: global persistent switch. The framework includes an active `Global` record by default; set `Active__c` to control the framework globally.
- `TriggerFactory.turnOff()` / `turnOn()`: transaction-level global override.
- `TriggerFactory.turnOffFor(SObjectType)` / `turnOnFor(SObjectType)`: transaction-level object override.

## Flow integration

Configure an autolaunched Flow in the individual `TriggerConfig__mdt` record with `Execution_Type__c = Flow`, `Flow_Name__c`, `Flow_Active__c = true`, and `Flow_Run_Context__c` set to `Before`, `After`, or `Both`.

The Flow starts once per trigger transaction, not once per record. It receives these input variables:

- `newRecords`
- `oldRecords`
- The Flow must define compatible `newRecords` and `oldRecords` input variables using those API names. The object and event are already known by the handler configuration and by the records/context that invoked the Flow.

To bypass the persistent global switch for a specific user, create an active `TriggerFrameworkUserException__mdt` record with `User_Username__c` set to the Salesforce username. This exception does not bypass `turnOff()` or an object-level deactivation.

## Bulk and recursion behavior

Handler dispatch and Flow invocation are transaction-level operations. The framework passes the complete trigger collection to the Flow and does not perform one Flow interview per record.

## Included components

`TriggerInterface`, `Triggers`, `AbstractTriggerHandler`, `TriggerConfig`, `TriggerObjectConfig`, `TriggerFactory`, configuration metadata, layouts, focused tests, and `Trigger User` / `Trigger Admin` permission sets.
