# Payload Framework Implementation Guide

## Deployment order

1. Deploy the `log` framework when `PayloadLog` is enabled.
2. Deploy `Payload_Operation__c`, `Payload_Field__c`, fields, layouts, classes, and tests.
3. Assign `Payload User` to runtime users or integration identities.
4. Assign `Payload Admin` to users who maintain payload definitions.

## Configuration checklist

1. Create a `Payload_Operation__c` record.
2. Select `Direction__c` and, for request/response operations, `Response_Mode__c`.
3. Create `Payload_Field__c` mappings with JSON field, Salesforce field, target object, and direction.
4. For nested inbound data, set `Relationship_Name__c` on child mappings.
5. For inbound upsert, mark one external ID mapping with `Is_Upsert_Key__c`.
6. For response updates, mark one mapping per object with `Is_Match_Key__c` and optionally set `Match_Salesforce_Field__c`.

## Bulk limits

Mapping metadata is loaded once per parse. Response matching queries and DML are chunked at 2,000 records. Use pagination or asynchronous processing for payloads that approach Apex heap, CPU, query, or DML limits.

## Permission model

`Payload User` grants runtime Apex access, read/create/edit access to payload configuration records, and the minimum Log access required by `PayloadLog`; delete is excluded. `Payload Admin` grants full maintenance access to payload configuration and Log records.
