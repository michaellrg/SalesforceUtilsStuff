@IsTest
private class PayloadInboundParserTest {
  @IsTest
  static void parsesFlatCollection() {
    Payload_Operation__c operation = createOperation('Inbound Contacts');
    createMapping(operation, 'id', 'Id', 'Contact', null, true);
    createMapping(operation, 'firstName', 'FirstName', 'Contact', null, false);
    createMapping(operation, 'lastName', 'LastName', 'Contact', null, false);
    createMapping(operation, 'email', 'Email', 'Contact', null, false);
    createMapping(operation, 'accountId', 'AccountId', 'Contact', null, false);

    String json =
      '{"contacts":[' +
      '{"id":"003000000000001AAA","firstName":"John","lastName":"Smith","email":"john@example.com","accountId":"001000000000001AAA"},' +
      '{"id":"003000000000002AAA","firstName":"Sarah","lastName":"Connor","email":"sarah@example.com","accountId":"001000000000001AAA"}' +
      ']}' ;

    PayloadInboundParser.InboundResult result = PayloadInboundParser.parse(
      'Inbound Contacts',
      json
    );

    System.assertEquals(2, result.recordsByObject.get('Contact').size());
    System.assertEquals(
      'john@example.com',
      result.recordsByObject.get('Contact')[0].get('Email')
    );
  }

  @IsTest
  static void parsesNestedCollectionsAndRecognizesMultipleLevels() {
    Payload_Operation__c operation = createOperation('Inbound Accounts');
    createMapping(operation, 'id', 'Id', 'Account', null, true);
    createMapping(operation, 'name', 'Name', 'Account', null, false);
    createMapping(operation, 'industry', 'Industry', 'Account', null, false);
    createMapping(operation, 'id', 'Id', 'Contact', null, true);
    createMapping(operation, 'firstName', 'FirstName', 'Contact', null, false);
    createMapping(operation, 'lastName', 'LastName', 'Contact', null, false);
    createMapping(operation, 'email', 'Email', 'Contact', null, false);
    createMapping(operation, 'accountId', 'AccountId', 'Contact', 'AccountId', false);

    String json =
      '{"accounts":[' +
      '{"id":"001000000000001AAA","name":"Acme Canada","industry":"Technology","contacts":[' +
      '{"id":"003000000000001AAA","firstName":"John","lastName":"Smith","email":"john@example.com"},' +
      '{"id":"003000000000002AAA","firstName":"Sarah","lastName":"Connor","email":"sarah@example.com"}' +
      ']},' +
      '{"id":"001000000000002AAA","name":"Globex Corporation","industry":"Financial Services","contacts":[' +
      '{"id":"003000000000003AAA","firstName":"Michael","lastName":"Scott","email":"michael@example.com"}' +
      ']}' +
      ']}' ;

    PayloadInboundParser.InboundResult result = PayloadInboundParser.parse(
      'Inbound Accounts',
      json
    );

    System.assertEquals(2, result.recordsByObject.get('Account').size());
    System.assertEquals(3, result.recordsByObject.get('Contact').size());
    System.assertEquals(0, result.nodes[0].depth);
  }

  @IsTest
  static void processesResponseByConfiguredMatchKey() {
    Payload_Operation__c operation = createOperation('Response Accounts');
    operation.Direction__c = 'Outbound';
    operation.Response_Mode__c = 'Update';
    update operation;
    createMapping(operation, 'name', 'Name', 'Account', null, true);
    createMapping(operation, 'phone', 'Phone', 'Account', null, false);

    Account existing = new Account(Name = 'Acme Response');
    insert existing;

    Test.startTest();
    PayloadResponseProcessor.ResponseResult result = PayloadResponseProcessor.process(
      operation.Name,
      '{"accounts":[{"name":"Acme Response","phone":"416-555-0100"}]}'
    );
    Test.stopTest();

    Account updated = [SELECT Phone FROM Account WHERE Id = :existing.Id];
    System.assertEquals(1, result.matchedCount);
    System.assertEquals('416-555-0100', updated.Phone);
  }

  @IsTest
  static void parsesMultipleObjectsThroughSubSubLevel() {
    Payload_Operation__c operation = createOperation('Three Level Graph');
    createMapping(operation, 'accountName', 'Name', 'Account', null, false);
    createMapping(operation, 'contactFirstName', 'FirstName', 'Contact', 'AccountId', false);
    createMapping(operation, 'caseSubject', 'Subject', 'Case', 'ContactId', false);

    String json =
      '{"accounts":[{"accountName":"Northwind","contacts":[{"contactFirstName":"Ana",' +
      '"cases":[{"caseSubject":"Integration failure"}]}]}]}';
    PayloadInboundParser.InboundResult result = PayloadInboundParser.parse(
      operation.Name,
      json
    );

    System.assertEquals(1, result.recordsByObject.get('Account').size());
    System.assertEquals(1, result.recordsByObject.get('Contact').size());
    System.assertEquals(1, result.recordsByObject.get('Case').size());
    System.assertEquals(0, result.nodes[0].depth);
    System.assertEquals(1, result.nodes[1].depth);
    System.assertEquals(2, result.nodes[2].depth);
  }

  @IsTest
  static void parsesLargeMultiObjectPayloadWithStableQueryCount() {
    Payload_Operation__c operation = createOperation('Large Mixed Payload');
    createMapping(operation, 'accountName', 'Name', 'Account', null, false);
    createMapping(operation, 'contactFirstName', 'FirstName', 'Contact', 'AccountId', false);

    List<String> accounts = new List<String>();
    for (Integer index = 0; index < 150; index++) {
      accounts.add(
        '{"accountName":"Account ' + index + '","contacts":[' +
        '{"contactFirstName":"Contact ' + index + '"}]}'
      );
    }
    String json = '{"accounts":[' + String.join(accounts, ',') + ']}';

    Integer queriesBefore = Limits.getQueries();
    PayloadInboundParser.InboundResult result = PayloadInboundParser.parse(
      operation.Name,
      json
    );
    Integer queriesUsed = Limits.getQueries() - queriesBefore;

    System.assertEquals(150, result.recordsByObject.get('Account').size());
    System.assertEquals(150, result.recordsByObject.get('Contact').size());
    System.assertEquals(2, queriesUsed);
  }

  private static Payload_Operation__c createOperation(String name) {
    Payload_Operation__c operation = new Payload_Operation__c(
      Name = name,
      Active__c = true,
      Direction__c = 'Inbound',
      Http_Method__c = 'POST',
      Http_Timeout__c = 1000
    );
    insert operation;
    return operation;
  }

  private static void createMapping(
    Payload_Operation__c operation,
    String jsonField,
    String salesforceField,
    String targetObject,
    String relationshipName,
    Boolean isUpsertKey
  ) {
    insert new Payload_Field__c(
      Name = targetObject + '_' + jsonField + '_' + salesforceField,
      Active__c = true,
      Direction__c = 'Inbound',
      JSON_Field__c = jsonField,
      Salesforce_Field__c = salesforceField,
      Target_Object_Name__c = targetObject,
      Relationship_Name__c = relationshipName,
      Is_Upsert_Key__c = isUpsertKey,
      Is_Match_Key__c = isUpsertKey,
      Payload_Operation__c = operation.Id
    );
  }
}
