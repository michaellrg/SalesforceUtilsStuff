@IsTest
private class TriggerFrameworkTest {
  @IsTest
  static void initializesOutsideTriggerContextForTests() {
    Triggers context = new Triggers();

    System.assertEquals(0, context.size);
    System.assertEquals(false, context.isBefore);
    System.assertEquals(false, context.isAfter);
    System.assertEquals(false, context.hasNewObjs);
    System.assertEquals(false, context.hasOldObjs);
  }

  @IsTest
  static void factoryCanToggleConfiguredTriggers() {
    TriggerFactory.turnOff();
    System.assertEquals(false, TriggerFactory.isEnabled(Account.SObjectType));
    TriggerFactory.turnOn();

    System.assertNotEquals(null, TriggerConfig.Configurations);
    System.assertEquals(true, TriggerFactory.isEnabled(Account.SObjectType));
  }

  @IsTest
  static void objectWithoutSpecificOverrideRemainsEnabled() {
    TriggerFactory.turnOn();
    TriggerObjectConfig.clearCache();

    System.assertEquals(null, TriggerObjectConfig.getBySObjectType(Account.SObjectType));
    System.assertEquals(true, TriggerFactory.isEnabled(Account.SObjectType));
  }
}
