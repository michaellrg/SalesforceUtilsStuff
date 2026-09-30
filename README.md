# Salesforce Utils Frameworks

Reusable Salesforce framework bases extracted and adapted for independent use.

Maintainer: Michaell Reis — michaellrg@gmail.com.

## Modules

- `log/`: application and payload logging through `Logger`, `Log__c`, log record types, and the optional `LogEvent__e` platform event.
- `payload/`: outbound JSON generation, inbound SObject parsing, response matching, HTTP transactions, configuration SObjects, layouts, tests, and permission sets.
- `trigger/`: trigger context helpers, configurable handlers, global/object-level activation controls, Flow integration, layouts, tests, and permission sets.
- `shared/`: cross-framework permission set kept for backward compatibility.

## Scope

The extracted base contains reusable Apex classes, focused framework tests, schema/configuration metadata, layouts, and permissions. Business handlers, concrete triggers, exchange-specific operations, configuration records, screens, and application data remain outside the framework base.

## Dependencies

`payload` depends on `log` because `PayloadLog` persists callout information to `Log__c`. Deploy `log` before `payload` when using payload logging.

## Ownership

The source repository was not modified. This copy is maintained under the Salesforce Utils framework package and uses Michaell Reis / michaellrg@gmail.com in its framework-facing metadata and documentation.
