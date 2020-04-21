public class rtPicklistController {
	@AuraEnabled
    public static List<picklistWrapper> getOptions (String obj){
        try{
        List<picklistWrapper> listOptions  = new List<picklistWrapper>();
        List<Schema.RecordTypeInfo> RTS = Schema.getGlobalDescribe().get(obj).getDescribe().getRecordTypeInfos();
         for (Schema.RecordTypeInfo rt: RTS){
             if(!rt.isMaster() && rt.isActive()){
             	picklistWrapper wp =new picklistWrapper(rt.getName(),rt.getRecordTypeId()) ;
             	listOptions.add (wp);
                 }
        }
            System.debug('List Options '+listOptions);
        return listOptions;
        }catch (Exception e){
            throw new AuraException (e);
        }
    }
    
	public class picklistWrapper{
       @AuraEnabled public String label {get; set;}
        @AuraEnabled public String value{get; set;}
        public picklistWrapper(String label, String value){
            this.label =label;
            this.value =value;
        }
    }    
}