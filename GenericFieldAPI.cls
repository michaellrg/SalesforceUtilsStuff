/*Generic fields API*/
public class GenericFieldAPI {

    public static void historyTracker(Map<Id, Account>  accObjMap){


        Map<String,String> triggerPlusCopyFieldMap = new Map<String,String>();
        List<String> triggerfields = new List<String>();
        List<String> copyfields = new List<String>();

        for(History_Tracker__c historytrackerController : [Select Id, name,Fields_to_Copy__c, ObjectType__c,Trigger_Fields__c,Active__c from History_Tracker__c where ObjectType__c =: 'Account' and Active__c =: True]){
            triggerfields = historytrackerController.Trigger_Fields__c.split(',');
            copyfields  = historytrackerController.Fields_to_Copy__c.split(',');
            system.debug('triggerfields'+triggerfields );
            //triggerPlusCopyFieldMap.put(globalhistoryController.Trigger_Fields__c,globalhistoryController.Fields_to_Copy__c);

        }
        
        List<History__c> listHistory = new List<History__c>();


        for(Account accObj: accObjMap.values()){

            for(integer i=0; i<triggerfields.size(); i++){
                string fieldAPI = triggerfields[i];
                


                String oldNameValue     = (String)trigger.oldMap.get(accObj.Id).get('Name');
                String currentNameValue = (String)accObj.Name;

                if(!oldNameValue.equals(currentNameValue) ){

                    id recordTypeId = Schema.SObjectType.History__c.getRecordTypeInfosByName().get('Account Name').getRecordTypeId();
                    History__c history = copyFieldsHistory(accObj, copyfields);
                    history.Account_Firm_Name__c=oldNameValue;
                    history.RecordTypeId= recordTypeId;
                    listHistory.add(history);

                }
                if(trigger.oldMap.get(accObj.Id).get(fieldAPI)!=null){

                    if( trigger.oldMap.get(accObj.Id).get(fieldAPI) != accObj.get(fieldAPI) ){
                        History__c history = copyFieldsHistory(accObj, copyfields);
                        listHistory.add(history);
                        break;
                    }
                }
            }           

        }
        if(listHistory.size()>0){
            insert listHistory;
        }
    }  



    public static History__c copyFieldsHistory(Account accObj, List<String> listFields){

        id recordTypeId = Schema.SObjectType.History__c.getRecordTypeInfosByName().get('Account Milestone').getRecordTypeId();
        History__c history = new History__c();
        history.Account__c = accObj.Id;
        history.RecordTypeId= recordTypeId;
        for(integer i=0; i<listFields.size(); i++){
            string fieldAPI = listFields[i];
                //system.debug('fieldAPI'+fieldAPI);
                //String oldFieldValue = trigger.oldMap.get(accObj.Id)+'.'+fieldAPI;
                history.Account_Firm_Name__c = accObj.Name;

                history.put(fieldAPI,trigger.oldMap.get(accObj.Id).get(fieldAPI) );


            }
            return history;
        }

    }