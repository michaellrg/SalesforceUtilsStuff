/**
 * @File Name:   TriggerConfig.cls
 * @Description:
 * @Date Created: 2017-05-09
 * @Author:       Michaell Reis
 * @Email:        michaellrg@gmail.com
 * @Project:      Salesforce Utils
 * @Group:        Apex
 * @Modification Log :
 *-------------------------------------------------------------------------------------
 * Ver       Date        Author         Modification
 * 1.0       2017-05-09  Michaell Reis       Created the file/class
 * 1.1       2018-04-18  Michaell Reis  Added Trigger framework 2.0
 * 2.0       2019-12-02  Michaell Reis    Streamlining changes
 * 3.0       2026-09-30  Michaell Reis  Adapted for Salesforce Utils
 */
public with sharing class TriggerConfig {
  public static Map<Schema.SObjectType, TriggerConfig[]> Configurations { // All the configurations
    get {
      if (Configurations == null) {
        Configurations = new Map<Schema.SObjectType, TriggerConfig[]>();
        Map<String, TriggerHandlerConfig__mdt> triggerMap = TriggerHandlerConfig__mdt.getAll();
        for (String key : triggerMap.keySet()) {
          TriggerHandlerConfig__mdt cfg = triggerMap.get(key);
          TriggerConfig tc = new TriggerConfig(cfg);

          if (!Configurations.containsKey(tc.SObjectType))
            Configurations.put(tc.SObjectType, new List<TriggerConfig>());

          Configurations.get(tc.SObjectType).add(tc);
        }
      }
      return Configurations;
    }
    private set;
  }

  /**
   * @Name          getBySObjectType
   * @Description   Get Trigger Configuration By SObject Type
   * @Author        Michaell Reis
   * @CreatedDate   2017-05-09
   * @Param         SObjectType Type
   * @Return        TriggerConfig
   */
  public static TriggerConfig[] getBySObjectType(SObjectType pType) {
    return Configurations.get(pType);
  }
  /**
   * @Name          getBySObjectName
   * @Description   Get Trigger Configuration By Name
   * @Author        Michaell Reis
   * @CreatedDate   2017-05-09
   * @Param         String Name
   * @Return        TriggerConfig
   */
  public static TriggerConfig[] getBySObjectName(String pName) {
    return getBySObjectType(Schema.getGlobalDescribe().get(pName));
  }

  /**
   * @Name          TriggerConfig
   * @Description   Private Constructor of class
   * @Author        Michaell Reis
   * @CreatedDate   2019-12-02
   * @Param         Metadata configuration
   * @Return        TriggerConfig
   */
  @TestVisible
  private TriggerConfig(TriggerHandlerConfig__mdt pCfg) {
    this.Handler = pCfg.Handler_Name__c;
    this.IsActive = pCfg.Active__c;
    TriggerObjectConfig__mdt objectConfig = String.isBlank(pCfg.SObject__c)
      ? null
      : TriggerObjectConfig__mdt.getInstance(pCfg.SObject__c);
    this.SObjectName = objectConfig == null ? null : objectConfig.SObject__c;
    this.ExecutionType = String.isBlank(pCfg.Execution_Type__c)
      ? 'Apex'
      : pCfg.Execution_Type__c;
    this.FlowName = pCfg.Flow_Name__c;
    this.FlowRunContext = String.isBlank(pCfg.Flow_Run_Context__c)
      ? 'After'
      : pCfg.Flow_Run_Context__c;
    this.SObjectType = String.isBlank(this.SObjectName)
      ? null
      : Schema.getGlobalDescribe().get(this.SObjectName);
  }

  public SObjectType SObjectType { get; private set; }
  public Boolean IsActive { get; private set; }
  public String Handler { get; private set; }
  public String SObjectName { get; private set; }
  public String ExecutionType { get; private set; }
  public String FlowName { get; private set; }
  public String FlowRunContext { get; private set; }
}
