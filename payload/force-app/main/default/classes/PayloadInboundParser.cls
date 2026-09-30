/**
 * @description Converts inbound JSON collections into configured SObjects.
 *              Supports root collections, nested collections and flat child records.
 * @author Michaell Reis
 * @contact michaellrg@gmail.com
 * @project Salesforce Utils
 */
global without sharing class PayloadInboundParser {
  global class InboundException extends Exception {}

  global class InboundNode {
    global SObject record { get; private set; }
    global String objectName { get; private set; }
    global Integer depth { get; private set; }
    global InboundNode parent { get; private set; }

    private InboundNode(
      SObject recordValue,
      String objectNameValue,
      Integer depthValue,
      InboundNode parentValue
    ) {
      this.record = recordValue;
      this.objectName = objectNameValue;
      this.depth = depthValue;
      this.parent = parentValue;
    }
  }

  global class InboundResult {
    global List<InboundNode> nodes { get; private set; }
    global Map<String, List<SObject>> recordsByObject { get; private set; }
    global List<Database.UpsertResult> upsertResults { get; private set; }

    private InboundResult() {
      this.nodes = new List<InboundNode>();
      this.recordsByObject = new Map<String, List<SObject>>();
      this.upsertResults = new List<Database.UpsertResult>();
    }

    private void addNode(InboundNode node) {
      this.nodes.add(node);
      if (!this.recordsByObject.containsKey(node.objectName)) {
        this.recordsByObject.put(node.objectName, new List<SObject>());
      }
      this.recordsByObject.get(node.objectName).add(node.record);
    }
  }

  private class MappingContext {
    private PayloadOperation operation;
    private List<Payload_Field__c> mappings;
    private Map<String, List<Payload_Field__c>> mappingsByJsonField;
    private Map<String, List<Payload_Field__c>> mappingsByObject;
    private Map<String, List<Payload_Field__c>> relationshipMappingsByObject;
    private Map<String, String> upsertFieldByObject;

    private MappingContext(PayloadOperation operationValue, String messagePart) {
      this.operation = operationValue;
      this.mappings = [
        SELECT
          Name,
          Active__c,
          JSON_Field__c,
          Salesforce_Field__c,
          Target_Object_Name__c,
          Relationship_Name__c,
          Is_Upsert_Key__c,
          Message_Part__c,
          Direction__c,
          Target_System_Type__c,
          Payload_Operation__c
        FROM Payload_Field__c
        WHERE
          Active__c = TRUE
          AND Payload_Operation__c = :operation.Id
        ORDER BY JSON_Field__c ASC
      ];
      this.mappingsByJsonField = new Map<String, List<Payload_Field__c>>();
      this.mappingsByObject = new Map<String, List<Payload_Field__c>>();
      this.relationshipMappingsByObject = new Map<String, List<Payload_Field__c>>();
      this.upsertFieldByObject = new Map<String, String>();

      for (Payload_Field__c mapping : this.mappings) {
        if (
          String.isBlank(messagePart) &&
          mapping.Direction__c == 'Outbound'
        ) {
          continue;
        }
        if (
          String.isNotBlank(messagePart) &&
          String.isNotBlank(mapping.Message_Part__c) &&
          mapping.Message_Part__c != 'Both' &&
          mapping.Message_Part__c != messagePart
        ) {
          continue;
        }
        String jsonField = normalize(mapping.JSON_Field__c);
        String targetObject = normalize(mapping.Target_Object_Name__c);
        if (String.isNotBlank(jsonField)) {
          addMapping(this.mappingsByJsonField, jsonField, mapping);
        }
        if (String.isNotBlank(targetObject)) {
          addMapping(this.mappingsByObject, targetObject, mapping);
          if (String.isNotBlank(mapping.Relationship_Name__c)) {
            addMapping(this.relationshipMappingsByObject, targetObject, mapping);
          }
          if (mapping.Is_Upsert_Key__c && String.isNotBlank(mapping.Salesforce_Field__c)) {
            this.upsertFieldByObject.put(
              targetObject,
              lastPathPart(mapping.Salesforce_Field__c)
            );
          }
        }
      }
    }
  }

  global static InboundResult parse(String operationName, String json) {
    return parseInternal(operationName, json, null, false);
  }

  global static InboundResult parseResponse(String operationName, String json) {
    return parseInternal(operationName, json, 'Response', true);
  }

  private static InboundResult parseInternal(
    String operationName,
    String json,
    String messagePart,
    Boolean allowOutbound
  ) {
    if (String.isBlank(json)) {
      throw new InboundException('Inbound JSON cannot be blank.');
    }

    PayloadOperation operation = PayloadOperation.getByName(operationName);
    if (
      operation == null ||
      !operation.Active ||
      (!allowOutbound && operation.Direction == 'Outbound')
    ) {
      throw new InboundException(
        'Payload operation is missing or inactive: ' + operationName
      );
    }

    MappingContext context = new MappingContext(operation, messagePart);
    if (context.mappings.isEmpty()) {
      throw new InboundException(
        'No active inbound mappings found for operation: ' + operationName
      );
    }

    Object decoded = System.JSON.deserializeUntyped(json);
    InboundResult result = new InboundResult();
    walk(decoded, null, 0, context, result);

    if (result.nodes.isEmpty()) {
      throw new InboundException(
        'The JSON did not contain an object matching the configured target objects.'
      );
    }
    return result;
  }

  global static InboundResult upsertRecords(String operationName, String json) {
    InboundResult result = parse(operationName, json);
    MappingContext context = new MappingContext(
      PayloadOperation.getByName(operationName),
      null
    );
    Integer maxDepth = 0;
    for (InboundNode node : result.nodes) {
      maxDepth = Math.max(maxDepth, node.depth);
    }

    for (Integer depth = 0; depth <= maxDepth; depth++) {
      Map<String, List<InboundNode>> nodesByObject =
        new Map<String, List<InboundNode>>();

      for (InboundNode node : result.nodes) {
        if (node.depth != depth) {
          continue;
        }
        applyParentRelationship(node, context);
        if (!nodesByObject.containsKey(node.objectName)) {
          nodesByObject.put(node.objectName, new List<InboundNode>());
        }
        nodesByObject.get(node.objectName).add(node);
      }

      for (String objectName : nodesByObject.keySet()) {
        List<InboundNode> nodes = nodesByObject.get(objectName);
        List<SObject> records = new List<SObject>();
        for (InboundNode node : nodes) {
          records.add(node.record);
        }

        Schema.SObjectField externalIdField = findExternalIdField(
          records,
          context.upsertFieldByObject.get(normalize(objectName))
        );
        Database.UpsertResult[] saveResults = externalIdField == null
          ? Database.upsert(records, false)
          : Database.upsert(records, externalIdField, false);
        result.upsertResults.addAll(saveResults);
      }
    }
    return result;
  }

  private static void walk(
    Object value,
    InboundNode parent,
    Integer depth,
    MappingContext context,
    InboundResult result
  ) {
    if (value instanceof List<Object>) {
      for (Object item : (List<Object>) value) {
        walk(item, parent, depth, context, result);
      }
      return;
    }

    if (!(value instanceof Map<String, Object>)) {
      return;
    }

    Map<String, Object> values = (Map<String, Object>) value;
    String targetObject = resolveTargetObject(values, context);
    InboundNode current = parent;
    if (String.isNotBlank(targetObject)) {
      current = buildNode(values, targetObject, parent, depth, context);
      result.addNode(current);
    }

    for (String key : values.keySet()) {
      Object child = values.get(key);
      if (child instanceof Map<String, Object> || child instanceof List<Object>) {
        walk(child, current, String.isNotBlank(targetObject) ? depth + 1 : depth, context, result);
      }
    }
  }

  private static InboundNode buildNode(
    Map<String, Object> values,
    String targetObject,
    InboundNode parent,
    Integer depth,
    MappingContext context
  ) {
    Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    Schema.SObjectType sObjectType = globalDescribe.get(targetObject);
    String canonicalObjectName;
    if (sObjectType == null) {
      for (String apiName : globalDescribe.keySet()) {
        if (apiName.equalsIgnoreCase(targetObject)) {
          sObjectType = globalDescribe.get(apiName);
          break;
        }
      }
    }
    if (sObjectType == null) {
      throw new InboundException('Unknown target SObject: ' + targetObject);
    }
    canonicalObjectName = sObjectType.getDescribe().getName();

    SObject record = sObjectType.newSObject();
    Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
    Map<String, Object> normalizedValues = normalizeValues(values);
    for (Payload_Field__c mapping : context.mappingsByObject.get(normalize(targetObject))) {
      String jsonKey = normalize(mapping.JSON_Field__c);
      String fieldName = lastPathPart(mapping.Salesforce_Field__c);
      if (!normalizedValues.containsKey(jsonKey) || String.isBlank(fieldName) || !fields.containsKey(fieldName)) {
        continue;
      }
      Object rawValue = normalizedValues.get(jsonKey);
      if (rawValue == null) {
        continue;
      }
      record.put(
        fieldName,
        convertValue(rawValue, fields.get(fieldName).getDescribe().getType())
      );
    }

    return new InboundNode(record, canonicalObjectName, depth, parent);
  }

  private static void applyParentRelationship(
    InboundNode node,
    MappingContext context
  ) {
    if (node.parent == null || node.parent.record.Id == null) {
      return;
    }

    Map<String, Schema.SObjectField> fields = node.record.getSObjectType()
      .getDescribe()
      .fields
      .getMap();
    List<Payload_Field__c> relationshipMappings = context.relationshipMappingsByObject.get(
      normalize(node.objectName)
    );
    if (relationshipMappings == null) {
      return;
    }
    for (Payload_Field__c mapping : relationshipMappings) {
      String fieldName = lastPathPart(mapping.Salesforce_Field__c);
      if (
        String.isNotBlank(mapping.Relationship_Name__c) &&
        String.isNotBlank(fieldName) &&
        fields.containsKey(fieldName) &&
        node.record.get(fieldName) == null
      ) {
        node.record.put(fieldName, node.parent.record.Id);
      }
    }
  }

  private static Schema.SObjectField findExternalIdField(
    List<SObject> records,
    String fieldName
  ) {
    if (records.isEmpty() || String.isBlank(fieldName) || fieldName == 'Id') {
      return null;
    }
    Schema.DescribeSObjectResult describe = records[0].getSObjectType().getDescribe();
    if (!describe.fields.getMap().containsKey(fieldName)) {
      throw new InboundException('Upsert key does not exist: ' + fieldName);
    }
    Schema.SObjectField fieldToken = describe.fields.getMap().get(fieldName);
    if (!fieldToken.getDescribe().isExternalId()) {
      throw new InboundException('Upsert key must be an External ID: ' + fieldName);
    }
    return fieldToken;
  }

  private static String resolveTargetObject(
    Map<String, Object> values,
    MappingContext context
  ) {
    Map<String, Integer> matches = new Map<String, Integer>();
    for (String key : values.keySet()) {
      String jsonKey = normalize(key);
      List<Payload_Field__c> mappings = context.mappingsByJsonField.get(jsonKey);
      if (mappings == null) {
        continue;
      }
      for (Payload_Field__c mapping : mappings) {
        String target = normalize(mapping.Target_Object_Name__c);
        if (String.isNotBlank(target)) {
          matches.put(target, matches.containsKey(target) ? matches.get(target) + 1 : 1);
        }
      }
    }

    String selected;
    Integer selectedCount = 0;
    for (String target : matches.keySet()) {
      if (matches.get(target) > selectedCount) {
        selected = target;
        selectedCount = matches.get(target);
      }
    }
    return selected;
  }

  private static Object convertValue(Object value, Schema.DisplayType fieldType) {
    if (value == null) {
      return null;
    }
    String stringValue = String.valueOf(value);
    if (fieldType == Schema.DisplayType.Boolean) return Boolean.valueOf(stringValue);
    if (fieldType == Schema.DisplayType.Integer) return Integer.valueOf(stringValue);
    if (fieldType == Schema.DisplayType.Double) return Double.valueOf(stringValue);
    if (fieldType == Schema.DisplayType.Currency || fieldType == Schema.DisplayType.Percent) return Decimal.valueOf(stringValue);
    if (fieldType == Schema.DisplayType.Date) return Date.valueOf(stringValue);
    if (fieldType == Schema.DisplayType.Datetime) return Datetime.valueOfGmt(stringValue.replace('T', ' ').replace('Z', ''));
    return stringValue;
  }

  private static void addMapping(
    Map<String, List<Payload_Field__c>> target,
    String key,
    Payload_Field__c mapping
  ) {
    if (!target.containsKey(key)) {
      target.put(key, new List<Payload_Field__c>());
    }
    target.get(key).add(mapping);
  }

  private static Map<String, Object> normalizeValues(Map<String, Object> values) {
    Map<String, Object> normalized = new Map<String, Object>();
    for (String key : values.keySet()) {
      normalized.put(normalize(key), values.get(key));
    }
    return normalized;
  }

  private static String normalize(String value) {
    return String.isBlank(value) ? '' : value.trim().toLowerCase();
  }

  private static String lastPathPart(String value) {
    if (String.isBlank(value)) {
      return value;
    }
    List<String> parts = value.split('\\.');
    return parts[parts.size() - 1];
  }
}
