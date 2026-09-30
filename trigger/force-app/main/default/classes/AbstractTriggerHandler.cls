/**
  * @File Name    :   AbstractTriggerHandler
  * @Description  :   Salesforce Utils base class for trigger handlers
  * @Date Created :   2017-05-09
  * @Author       :   Michaell Reis
  * @Email        :   michaellrg@gmail.com
  * @Project      :   Salesforce Utils
  * @group        :   Interface
  * @Modification Log:
  **************************************************************************************
  * Ver       Date        Author              Modification
  * 1.0       2017-05-09  Michaell Reis            Craeted the file/class
  * 1.1       2018-04-18  Michaell Reis      Added Trigger framework 2.0
  * 3.0       2026-09-30  Michaell Reis         Adapted for Salesforce Utils

  Usage patterns:

  NOTES:
      1. DO NOT use the System.Trigger in your handler
      2. ALWAYS use [this.triggers] in your handler - it has the same API as System.Trigger
      3. BECAUSE an instance of [this.triggers] can be used in a future, queue or batch

  (0) - Custom Metadata setup entry in TriggerConfig__mdt:
      Label: Example AccountContactRelations
      Name : Example_AccountContactRelations
      Order__c  : 0
      Active__c : Y
      SObject__c: AccountContactRelation
      Handler_Name__c: ExampleAccountContactRelationHandler

  (1) - Trigger code: [For the (0).SObject__c value]
      /**
        * @File Name    :   ExampleAccountContactRelationTrigger
        * @Description  :   AccountContactRelation Trigger, calls CRM_TriggerFactory
        * @Date Created :   20..-..-..
        * @Author       :   Michaell Reis, Salesforce Utils, michaellrg@gmail.com
        * @group        :   Trigger
        * @Modification Log:
        **************************************************************************************
        * Ver       Date        Author              Modification
        * 1.0       2026-09-30  Michaell Reis      Example implementation
        ** /
      trigger ExampleAccountContactRelationTrigger on AccountContactRelation (
          // before insert, before update, before delete,
          // after insert, after update, after delete, after undelete
      ) {
          TriggerFactory.createHandlerAndExecute(AccountContactRelation.SObjectType);
      }

  (2) - Handler code SAMPLE: [For the (0).Handler_Name__c value]
      /**
        * @File Name    :   ExampleAccountContactRelationHandler
        * @Description  :   AccountContactRelation Trigger Handler, invoked on DML actions for the object
        * @Date Created :   20..-..-..
        * @Author       :   Michaell Reis, Salesforce Utils, michaellrg@gmail.com
        * @group        :   Trigger
        * @Modification Log:
        **************************************************************************************
        * Ver       Date        Author              Modification
        * 1.0       2026-09-30  Michaell Reis      Example implementation
        ** /
      public virtual with sharing class ExampleAccountContactRelationHandler extends AbstractTriggerHandler
      {
          private static final List<String> FLDS_OFCHANGE = new String[]{'AccountId', 'Roles'};

          /**
            * @description Before object insert processing
            * @Date Created :   20..-..-..
            * @Author       :   Michaell Reis
            * /
          public override void beforeInsert()
          {
              System.debug('Context='+this.triggers.asJSON());
              ...
          }

          /**
            * @description After object update processing
            * @Date Created :   20..-..-..
            * @Author       :   Michaell Reis
            * /
          public override void afterUpdate()
          {
              Triggers trg = this.triggers;
              AccountContactRelation oldAcr;

              Set<AccountContactRelation>
                  relsAdd  = new Set<AccountContactRelation>(),
                  relsSubs = new Set<AccountContactRelation>();

              // -- Iterate against the incoming ACRs to identify if the AccountId has changed, which means [whatever] from the parenting change.
              for(AccountContactRelation acr : (List<AccountContactRelation>)trg.newLst)
              {   //Get the old values of the record.
                  oldAcr = (AccountContactRelation)trg.oldMap.get(acr.Id);

                  if(trg.hasChangedOR(acr, FLDS_OFCHANGE))
                  {
                      if(trg.isChanged(acr, FLDS_OFCHANGE[1]) && acr.AccountId != null) // Roles
                      {
                          if(acr.Roles.contains('[whatever]')) relsAdd.add(acr);
                          else relsSubs.add(acr);
                      }
                      if(trg.isChanged(acr, FLDS_OFCHANGE[0])) // AccountId
                      {
                          if(acr.Roles.contains('[whatever]'))
                          {
                              if(acr.AccountId != null)    relsAdd.add(acr);
                              if(oldAcr.AccountId != null) relsSubs.add(oldAcr);
                          }
                      }
                  }
              }
              if(!relsAdd.isEmpty())  doSomethingOnAdd(relsAdd,  ...);
              if(!relsSubs.isEmpty()) doSomethingOnSub(relsSubs, ...);
          }

          
          /**
            * @description After object delete processing
            * @Date Created :   20..-..-..
            * @Author       :   Michaell Reis
            * /
          public override void afterDelete()
          {
              ...
          }
      }
  **/
public with sharing abstract class AbstractTriggerHandler implements TriggerInterface {
  public static Boolean FirstRun = true;

  public virtual void bulkBefore() {
  }
  public virtual void bulkAfter() {
  }
  public virtual void andFinally() {
  }

  public virtual void beforeInsert() {
  }
  public virtual void beforeUpdate() {
  }
  public virtual void beforeDelete() {
  }

  public virtual void afterInsert() {
  }
  public virtual void afterUpdate() {
  }
  public virtual void afterDelete() {
  }
  public virtual void afterUndelete() {
  }

  public Triggers triggers { get; set; }

  /**
   * @Name          execute
   * @Description   Execute this handler
   * @Author        Michaell Reis
   * @CreatedDate   2017-05-09
   * @Param         TriggerInterface instance handler
   * @Return        void
   */
  public void execute() {
    this.triggers = new Triggers();

    if (Trigger.isBefore) {
      this.bulkBefore();

      if (Trigger.isDelete) {
        this.beforeDelete();
      } else if (Trigger.isInsert) {
        this.beforeInsert();
      } else if (Trigger.isUpdate) {
        this.beforeUpdate();
      }
    } else {
      this.bulkAfter();

      if (Trigger.isDelete) {
        this.afterDelete();
      } else if (Trigger.isInsert) {
        this.afterInsert();
      } else if (Trigger.isUpdate) {
        this.afterUpdate();
      } else if (Trigger.isUndelete) {
        this.afterUndelete();
      }
    }
    this.andFinally();
  }

  /**
   * @Name          setFieldValues
   * @Description   For the specified object, set the collection of fields to their mapped values
   * @Author        Michaell Reis
   * @CreatedDate   2018-10-01
   * @Param         SObject             Target object
   * @Param         Map<String, Object> Fields/Values mapping to consider
   * @Return        SOjbect             Affected input object
   */
  @TestVisible
  protected SObject setFieldValues(SObject pObj, Map<String, Object> pFlds) {
    for (String fld : pFlds.keySet())
      pObj.put(fld, pFlds.get(fld));

    return pObj;
  }

  /**
   * @Name          wipeout
   * @Description   For the specified object, set the collection of fields to null
   * @Author        Michaell Reis
   * @CreatedDate   2018-07-20
   * @Param         SObject  Target object
   * @Param         String[] Fields to wipe-out
   * @Return        SOjbect  Affected input object
   */
  @TestVisible
  protected SObject wipeout(SObject pObj, String[] pFlds) {
    for (String key : pFlds)
      pObj.put(key, null);

    return pObj;
  }
}
