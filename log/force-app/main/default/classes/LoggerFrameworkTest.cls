@IsTest
private class LoggerFrameworkTest {
  @IsTest
  static void createsApplicationLogWithoutDml() {
    Log__c logEntry = new Logger().logObject('framework smoke test');

    System.assertEquals('framework smoke test', logEntry.Comment__c);
    System.assertEquals('INFO', String.valueOf(logEntry.Severity__c));
    System.assertNotEquals(null, logEntry.RecordTypeId);
  }
}
