public with sharing class DynamicCustomLookupController {

    @AuraEnabled
    public static List<sObject> fetchExtendedLookUpValues(String searchKeyWord, String objectName,String fieldSetName) {

        String realObjectName = String.escapeSingleQuotes(objectName);
        System.debug('fieldSetName '+fieldSetName);
        List<String> lstFieldsToQuery = new List<String>();
        if(fieldSetName!=null){
            String realFieldsToQuery = String.escapeSingleQuotes(fieldSetName);
            List<Schema.FieldSetMember> fieldSetMembers= Utility.readFieldSet(fieldSetName, objectName);
            for(Schema.FieldSetMember eachFieldSetMember : fieldSetMembers){
                lstFieldsToQuery.add(String.valueOf(eachFieldSetMember.getFieldPath()));
            }
        }
        String searchKey = searchKeyWord + '%';



        List<sObject> returnList = new List <sObject>();

        // Create a Dynamic SOQL Query For Fetch Record List with LIMIT 5
        String sQuery =  'select Id,Name';
        if(lstFieldsToQuery.size()!=0){
            sQuery+=', '+  String.join(lstFieldsToQuery, ',');
        }
        sQuery+=+' from ' + realObjectName + ' where Name LIKE :searchKey order by createdDate DESC limit 10';
        try {
            List <sObject> lstOfRecords = Database.query(sQuery);
            for (sObject obj: lstOfRecords) {
                returnList.add(obj);
            }
            System.debug(returnList);
        } catch (Exception e) {
            throw new AuraHandledException('That didn\'n work:'+sQuery+'\n'+e.getMessage());
        }
        return returnList;
    }

    @AuraEnabled
    public static String getLabel(String objectName){

        try {
            Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
            String objectLabel = DescribeSObjectResultObj.getLabel();

            return objectLabel;
        }catch(Exception e) {  throw new AuraHandledException(e.getMessage());}
    }

    @AuraEnabled
    public static String getFieldLabel(String objectName,String fieldName){

        try {
            String fieldLabel =Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe().getLabel();
            return fieldLabel;
        }catch(Exception e) {  throw new AuraHandledException(e.getMessage());}
    }

    @AuraEnabled
    public static SObject fetchObjectLookup(String objectName, String recordId){
        System.debug('Enter fechObjectLookup');
        String realObjectName = String.escapeSingleQuotes(objectName);
        String sQuery =  'select Id,Name from ' + realObjectName + ' where Id ='+'\''+recordId+'\'';
        sObject record;
        try {

            record = Database.query(sQuery);
            System.debug(record);
        } catch (Exception e) {
            throw new AuraHandledException('That didn\'n work:'+sQuery+'\n'+e.getMessage());
        }
        return record;
    }
}
