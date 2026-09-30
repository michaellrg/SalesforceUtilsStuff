/**
 * @description Matches an HTTP response to Salesforce records and applies the
 *              configured response mappings in bulk.
 * @author Michaell Reis
 * @contact michaellrg@gmail.com
 * @project Salesforce Utils
 */
global without sharing class PayloadResponseProcessor {
  global class ResponseException extends Exception {}

  global class ResponseResult {
    global Integer matchedCount { get; private set; }
    global Integer insertedCount { get; private set; }
    global Integer updatedCount { get; private set; }
    global Integer unmatchedCount { get; private set; }
    global List<String> unmatchedKeys { get; private set; }
    global List<Database.SaveResult> saveResults { get; private set; }

    private ResponseResult() {
      this.matchedCount = 0;
      this.insertedCount = 0;
      this.updatedCount = 0;
      this.unmatchedCount = 0;
      this.unmatchedKeys = new List<String>();
      this.saveResults = new List<Database.SaveResult>();
    }
  }

  private class MatchConfig {
    private String sourceField;
    private String matchField;
    private Set<String> mappedFields;
  }

  global static ResponseResult process(String operationName, String responseJson) {
    PayloadOperation operation = PayloadOperation.getByName(operationName);
    if (operation == null || !operation.Active) {
      throw new ResponseException('Payload operation is missing or inactive: ' + operationName);
    }
    if (operation.ResponseMode == 'Ignore') {
      return new ResponseResult();
    }

    List<Payload_Field__c> mappings = loadResponseMappings(operation.Id);
    if (mappings.isEmpty()) {
      throw new ResponseException('No active response mappings found for operation: ' + operationName);
    }

    Map<String, MatchConfig> configByObject = buildConfigs(mappings);
    PayloadInboundParser.InboundResult parsed = PayloadInboundParser.parseResponse(
      operationName,
      responseJson
    );
    ResponseResult result = new ResponseResult();

    for (String objectName : parsed.recordsByObject.keySet()) {
      MatchConfig config = configByObject.get(objectName);
      if (config == null) {
        continue;
      }
      processObject(
        objectName,
        parsed.recordsByObject.get(objectName),
        config,
        operation.ResponseMode,
        result
      );
    }
    return result;
  }

  private static List<Payload_Field__c> loadResponseMappings(Id operationId) {
    List<Payload_Field__c> allMappings = [
      SELECT
        JSON_Field__c,
        Salesforce_Field__c,
        Target_Object_Name__c,
        Match_Salesforce_Field__c,
        Is_Match_Key__c,
        Message_Part__c,
        Active__c
      FROM Payload_Field__c
      WHERE Active__c = TRUE AND Payload_Operation__c = :operationId
    ];
    List<Payload_Field__c> responseMappings = new List<Payload_Field__c>();
    for (Payload_Field__c mapping : allMappings) {
      if (
        String.isBlank(mapping.Message_Part__c) ||
        mapping.Message_Part__c == 'Both' ||
        mapping.Message_Part__c == 'Response'
      ) {
        responseMappings.add(mapping);
      }
    }
    return responseMappings;
  }

  private static Map<String, MatchConfig> buildConfigs(List<Payload_Field__c> mappings) {
    Map<String, MatchConfig> configs = new Map<String, MatchConfig>();
    for (Payload_Field__c mapping : mappings) {
      String objectName = canonicalObjectName(mapping.Target_Object_Name__c);
      if (String.isBlank(objectName) || String.isBlank(mapping.Salesforce_Field__c)) {
        continue;
      }
      if (!configs.containsKey(objectName)) {
        configs.put(objectName, new MatchConfig());
        configs.get(objectName).mappedFields = new Set<String>();
      }
      MatchConfig config = configs.get(objectName);
      String salesforceField = lastPathPart(mapping.Salesforce_Field__c);
      config.mappedFields.add(salesforceField);
      if (mapping.Is_Match_Key__c && String.isBlank(config.sourceField)) {
        config.sourceField = salesforceField;
        config.matchField = String.isBlank(mapping.Match_Salesforce_Field__c)
          ? salesforceField
          : lastPathPart(mapping.Match_Salesforce_Field__c);
      }
    }
    return configs;
  }

  private static void processObject(
    String objectName,
    List<SObject> incoming,
    MatchConfig config,
    String responseMode,
    ResponseResult result
  ) {
    if (String.isBlank(config.sourceField) || String.isBlank(config.matchField)) {
      throw new ResponseException(
        'A response mapping marked Is_Match_Key__c is required for ' + objectName
      );
    }

    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
    if (objectType == null || !hasField(objectType, config.matchField)) {
      throw new ResponseException(
        'Invalid match field ' + config.matchField + ' for ' + objectName
      );
    }

    Set<String> keys = new Set<String>();
    for (SObject record : incoming) {
      Object value = record.get(config.sourceField);
      if (value != null && String.isNotBlank(String.valueOf(value))) {
        keys.add(String.valueOf(value));
      }
    }
    if (keys.isEmpty()) {
      result.unmatchedCount += incoming.size();
      return;
    }

    Map<String, SObject> existingByKey = queryExisting(objectName, config.matchField, keys);
    List<SObject> updates = new List<SObject>();
    List<SObject> inserts = new List<SObject>();
    for (SObject incomingRecord : incoming) {
      String key = valueAsString(incomingRecord.get(config.sourceField));
      SObject existing = existingByKey.get(key);
      if (existing != null) {
        copyMappedFields(incomingRecord, existing, config);
        updates.add(existing);
        result.matchedCount++;
      } else if (responseMode == 'Upsert' && config.matchField != 'Id') {
        if (config.sourceField != config.matchField) {
          incomingRecord.put(config.matchField, incomingRecord.get(config.sourceField));
        }
        if (config.sourceField == 'Id') {
          incomingRecord.put('Id', null);
        }
        inserts.add(incomingRecord);
      } else {
        result.unmatchedCount++;
        result.unmatchedKeys.add(key);
      }
    }

    if (!updates.isEmpty()) {
      for (Integer offset = 0; offset < updates.size(); offset += 2000) {
        Integer endIndex = Math.min(offset + 2000, updates.size());
        List<SObject> chunk = new List<SObject>();
        for (Integer index = offset; index < endIndex; index++) {
          chunk.add(updates[index]);
        }
        Database.SaveResult[] updateResults = Database.update(chunk, false);
        result.saveResults.addAll(updateResults);
        result.updatedCount += chunk.size();
      }
    }
    if (!inserts.isEmpty()) {
      for (Integer offset = 0; offset < inserts.size(); offset += 2000) {
        Integer endIndex = Math.min(offset + 2000, inserts.size());
        List<SObject> chunk = new List<SObject>();
        for (Integer index = offset; index < endIndex; index++) {
          chunk.add(inserts[index]);
        }
        Database.SaveResult[] insertResults = Database.insert(chunk, false);
        result.saveResults.addAll(insertResults);
        result.insertedCount += chunk.size();
      }
    }
  }

  private static Map<String, SObject> queryExisting(
    String objectName,
    String matchField,
    Set<String> keys
  ) {
    Map<String, SObject> existingByKey = new Map<String, SObject>();
    List<String> keyList = new List<String>(keys);
    for (Integer offset = 0; offset < keyList.size(); offset += 2000) {
      Integer endIndex = Math.min(offset + 2000, keyList.size());
      Set<String> keyChunk = new Set<String>();
      for (Integer index = offset; index < endIndex; index++) {
        keyChunk.add(keyList[index]);
      }
      String query =
        'SELECT Id, ' +
        matchField +
        ' FROM ' +
        objectName +
        ' WHERE ' +
        matchField +
        ' IN :keyChunk';
      for (SObject record : Database.query(query)) {
        existingByKey.put(valueAsString(record.get(matchField)), record);
      }
    }
    return existingByKey;
  }

  private static void copyMappedFields(
    SObject incoming,
    SObject existing,
    MatchConfig config
  ) {
    Map<String, Object> populated = incoming.getPopulatedFieldsAsMap();
    Map<String, Schema.SObjectField> fields = existing.getSObjectType().getDescribe().fields.getMap();
    for (String fieldName : config.mappedFields) {
      if (fieldName == 'Id' || !populated.containsKey(fieldName) || !fields.containsKey(fieldName)) {
        continue;
      }
      if (fields.get(fieldName).getDescribe().isUpdateable()) {
        existing.put(fieldName, populated.get(fieldName));
      }
    }
  }

  private static Boolean hasField(Schema.SObjectType objectType, String fieldName) {
    return objectType.getDescribe().fields.getMap().containsKey(fieldName);
  }

  private static String canonicalObjectName(String requestedName) {
    if (String.isBlank(requestedName)) {
      return null;
    }
    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    if (globalDescribe.containsKey(requestedName)) {
      return globalDescribe.get(requestedName).getDescribe().getName();
    }
    for (String apiName : globalDescribe.keySet()) {
      if (apiName.equalsIgnoreCase(requestedName)) {
        return apiName;
      }
    }
    return null;
  }

  private static String lastPathPart(String value) {
    List<String> parts = value == null ? new List<String>() : value.split('\\.');
    return parts.isEmpty() ? value : parts[parts.size() - 1];
  }

  private static String valueAsString(Object value) {
    return value == null ? null : String.valueOf(value);
  }
}
