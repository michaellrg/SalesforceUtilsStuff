/**
 * @File Name    :   TriggerFactory
 * @Description  :   Trigger Factory Class
 * @Date Created :   2017-05-09
 * @Author       :   Michaell Reis
 * @Email        :   michaellrg@gmail.com
 * @Project      :   Salesforce Utils
 * @group        :   Interface
 * @Modification Log:
 **************************************************************************************
 * Ver       Date        Author         Modification
 * 1.0       2017-05-09  Michaell Reis       Created the file/class
 * 1.1       2018-04-18  Michaell Reis  Added Trigger framework 2.0
 * 2.1       2018-04-19  Michaell Reis  Adapted createHandlerAndExecute to be compabile with V1 Logic
 * 3.0       2026-09-30  Michaell Reis    Adapted for Salesforce Utils
 **/
public without sharing class TriggerFactory {
  public static final String FRAMEWORK_NAME = 'Salesforce Utils Trigger';
  @TestVisible
  private static Map<Schema.SObjectType, TriggerConfig[]> TriggerConfigs;
  @TestVisible
  private static Map<String, TriggerInterface> TriggerHanlderMap;
  @TestVisible
  private static Set<Schema.SObjectType> TriggerIgnores;
  @TestVisible
  private static Boolean FrameworkEnabledOverride;

  static {
    TriggerConfigs = TriggerConfig.Configurations;
    TriggerIgnores = new Set<Schema.SObjectType>();
    TriggerHanlderMap = new Map<String, TriggerInterface>();
    FrameworkEnabledOverride = null;
  }

  /**
   * @Name          turnOff/On
   * @Description   Manage the state of all triggers, or just specific ones
   * @Author        Michaell Reis
   * @CreatedDate   2019-12-02
   * @Param         Schema.SObjectType soType
   */
  public static void turnOff() {
    FrameworkEnabledOverride = false;
  }
  public static void turnOn() {
    FrameworkEnabledOverride = null;
  }

  public static void turnOffFor(Schema.SObjectType pType) {
    TriggerIgnores.add(pType);
  }
  public static void turnOnFor(Schema.SObjectType pType) {
    TriggerIgnores.remove(pType);
  }

  public static Boolean isEnabled(Schema.SObjectType pType) {
    if (FrameworkEnabledOverride != null) {
      return FrameworkEnabledOverride;
    }
    if (!isGloballyEnabled()) {
      return false;
    }
    if (TriggerIgnores.contains(pType)) {
      return false;
    }
    TriggerObjectConfig objectConfig = TriggerObjectConfig.getBySObjectType(pType);
    return objectConfig == null || objectConfig.IsActive;
  }

  @TestVisible
  private static Boolean isGloballyEnabled() {
    Map<String, TriggerFrameworkSettings__mdt> settings =
      TriggerFrameworkSettings__mdt.getAll();
    if (settings.isEmpty()) {
      return true;
    }
    Boolean active;
    if (settings.containsKey('Global')) {
      active = settings.get('Global').Active__c;
    } else {
      for (TriggerFrameworkSettings__mdt setting : settings.values()) {
        active = setting.Active__c;
        break;
      }
    }
    if (active == true) {
      return true;
    }
    for (TriggerFrameworkUserException__mdt userException : TriggerFrameworkUserException__mdt.getAll().values()) {
      if (
        userException.Active__c == true &&
        String.isNotBlank(userException.User_Username__c) &&
        userException.User_Username__c.equalsIgnoreCase(UserInfo.getUserName())
      ) {
        return true;
      }
    }
    return false;
  }

  /**
   * @Name          getHandlers
   * @Description   Version 2.0 Get trigger handlers for sObject
   * @Author        Michaell Reis
   * @CreatedDate   2018-04-18
   * @Param         Schema.SObjectType soType
   * @Return        TriggerInterface[]
   */
  @TestVisible
  private static List<TriggerInterface> getHandlers(Schema.SObjectType soType) {
    List<TriggerInterface> rVal = new List<TriggerInterface>();
    String cls;

    if (TriggerConfigs.containsKey(soType)) {
      for (TriggerConfig cfg : TriggerConfigs.get(soType))
        if (cfg.IsActive && (cfg.ExecutionType == 'Apex' || cfg.ExecutionType == 'Both')) {
          cls = cfg.Handler;

          if (!TriggerHanlderMap.containsKey(cls))
            TriggerHanlderMap.put(
              cls,
              (TriggerInterface) Type.forName(cls).newInstance()
            );

          rVal.add(TriggerHanlderMap.get(cls));
        }
    }
    return rVal;
  }

  /**
   * @Name          createHandlerAndExecute
   * @Description   Version 2.0 Create Trigger handler and execute
   * @Author        Michaell Reis
   * @CreatedDate   2017-05-09
   * @Param         Schema.SObjectType soType
   * @Return        void
   */
  public static void createHandlerAndExecute(Schema.SObjectType soType) {
    if (isEnabled(soType)) {
      for (TriggerInterface handler : getHandlers(soType))
        handler.execute();
      runConfiguredFlows(soType);
    }
  }

  private static void runConfiguredFlows(Schema.SObjectType soType) {
    if (!TriggerConfigs.containsKey(soType)) {
      return;
    }
    for (TriggerConfig config : TriggerConfigs.get(soType)) {
      if (
        config.IsActive &&
        (config.ExecutionType == 'Flow' || config.ExecutionType == 'Both') &&
        config.FlowActive &&
        String.isNotBlank(config.FlowName) &&
        shouldRunFlow(config.FlowRunContext)
      ) {
        Flow.Interview interview = Flow.Interview.createInterview(
          config.FlowName,
          new Map<String, Object>{
            'newRecords' => new List<SObject>(Trigger.new == null ? new List<SObject>() : Trigger.new),
            'oldRecords' => new List<SObject>(Trigger.old == null ? new List<SObject>() : Trigger.old)
          }
        );
        interview.start();
      }
    }
  }

  private static Boolean shouldRunFlow(String runContext) {
    if (runContext == 'Both') {
      return true;
    }
    return (Trigger.isBefore && runContext == 'Before') ||
      (Trigger.isAfter && runContext == 'After');
  }

  public class TriggerException extends Exception {
  }
}
