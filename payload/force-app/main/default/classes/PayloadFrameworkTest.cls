@IsTest
private class PayloadFrameworkTest {
  @IsTest
  static void rejectsBlankOperationName() {
    Boolean didThrow = false;

    try {
      PayloadOperation.getByName('');
    } catch (PayloadOperation.PayloadOperationException ex) {
      didThrow = true;
    }

    System.assertEquals(true, didThrow);
  }

  @IsTest
  static void loadsOperationFromSObject() {
    Payload_Operation__c definition = new Payload_Operation__c(
      Name = 'Smoke Operation',
      Active__c = true,
      Http_Method__c = 'GET',
      Http_Timeout__c = 1000,
      URL_Base__c = 'https://example.test',
      URL_Path__c = '/health'
    );
    insert definition;

    PayloadOperation operation = PayloadOperation.getByName('  Smoke Operation  ');

    System.assertEquals(definition.Id, operation.Id);
    System.assertEquals('GET', operation.HttpMethod);
    System.assertEquals('https://example.test/health', operation.getEndpoint(null));
  }

  @IsTest
  static void readsJsonNodeValues() {
    PayloadGenerator.JSONObjectNode node = new PayloadGenerator.JSONObjectNode();

    System.assertEquals(null, node.get('missingField'));
    System.assertEquals(true, node.isStrValueBlank('missingField'));
  }
}
