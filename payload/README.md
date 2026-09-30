# Payload Framework

Maintainer: Michaell Reis — michaellrg@gmail.com.

## Purpose

Provides configurable REST/SOAP payload generation, inbound JSON parsing, response matching, HTTP transport helpers, and payload logging. Configuration is stored in `Payload_Operation__c` and `Payload_Field__c` SObjects.

## Direction and message part

`Direction__c` accepts `Inbound`, `Outbound`, or `Both`. `Message_Part__c` separates mappings used by the outbound `Request`, the returned `Response`, or `Both`.

Inbound mappings use `Target_Object_Name__c`, `Relationship_Name__c`, `Cross_Object_Id_Field__c`, and `Is_Upsert_Key__c` to materialize SObjects, connect nested levels, and select external IDs for upsert. For a child lookup resolved from a parent external ID, map the child lookup field (for example `AccountId`), set `Relationship_Name__c` to the parent relationship (`Account`), and set `Cross_Object_Id_Field__c` to the parent external ID field (`Integration_Key__c`).

## Inbound formats

`PayloadInboundParser.parse()` supports a single object, root arrays, nested arrays, multiple SObjects, and flat child records. `PayloadInboundParser.upsertRecords()` groups records by SObject and depth, persisting parents before children.

The parser supports structures such as Account → Contact → Case and flat Contact records that carry `AccountId`.

For flat relationships, the child can carry the parent's external key instead of a Salesforce Id. The parser queries parent IDs in bulk and processes object dependencies before child DML.

## Response matching

Set `Response_Mode__c` on the operation to `Ignore`, `Update`, or `Upsert`. Mark one response mapping per SObject with `Is_Match_Key__c = true`. When the received value must be matched against a different Salesforce field, set `Match_Salesforce_Field__c`.

```text
JSON_Field__c              = reference
Salesforce_Field__c        = Remote_Reference__c
Is_Match_Key__c            = true
Match_Salesforce_Field__c  = External_Id__c
Message_Part__c            = Response
Response_Mode__c           = Update
```

`PayloadResponseProcessor.process(operationName, responseJson)` performs one bulk query per object/key group and bulk DML. `TransmitUtils` invokes it automatically for successful HTTP responses when response processing is enabled. Results are exposed through `PayloadTransaction.responseResult`, including matched, updated, inserted, and unmatched counts.

## Performance model

The parser loads mappings once per parse and does not execute SOQL per JSON record. Response matching chunks key queries and DML into blocks of 2,000 records. Very large integrations should still use API pagination, Queueable, or Batch processing because Apex heap, CPU, query, and DML limits remain transaction boundaries.

The external `JSONParse` project was reviewed but is not on the hot path because it also uses `JSON.deserializeUntyped` and therefore does not provide streaming memory behavior.

## Included components

`PayloadGenerator`, `PayloadOperation`, `PayloadLog`, `TransmitUtils`, `PayloadInboundParser`, `PayloadResponseProcessor`, focused tests, configuration SObjects, fields, layouts, and `Payload User` / `Payload Admin` permission sets.
