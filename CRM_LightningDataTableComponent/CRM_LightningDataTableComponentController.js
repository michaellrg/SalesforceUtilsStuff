({
    doInit : function(component, event, helper) {
        
        if(component.get("v.externalObject")!==	undefined && component.get("v.externalField")!== undefined){
            helper.getLabel(component, event,helper);
        }
        component.set("v.loadingText", $A.get("$Label.c.CRM_In_Progress"));
        var action = component.get("c.getObjectRecords");
        //Set the Object parameters and Field Set name
        action.setParams({
            strObjectName : component.get("v.objectName"),
            strFieldSetName : component.get("v.fieldSet"),
            filter : component.get("v.queryFilter")
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === 'SUCCESS'){
                if(response.getReturnValue().lstDataTableData.length == 0) {
                    if(component.get("v.externalLabel")===undefined){
                    component.set("v.loadingText", $A.get("$Label.c.CRM_No_Records_Found"));
                    }else{
                        component.set("v.loadingText", $A.get("$Label.c.CRM_Invalid_Field") + ": "+component.get("v.externalLabel"));
                    }
                }
                else {
					var inprogress = component.find("inprogress");
                	$A.util.addClass(inprogress, 'slds-hide');
                            var data = response.getReturnValue().lstDataTableData;
                    var rows = Object.keys(data);//get number of rows
                    var keys = Object.keys(data[0]); //get column names
                    for(var row = 0; row<rows.length;row++){
                        for(var column =0; column<keys.length;column++){

                            var nameColumn = keys[column]; //store the name of column
                            if(data[row][nameColumn]!= undefined){
                                data[row][nameColumn]=String(data[row][nameColumn]);
                            }
                        }
                    }

                    component.set("v.tableColumns", response.getReturnValue().lstDataTableColumns);
                	component.set("v.tableData", data);
                }   
            }else if (state === 'ERROR'){
                console.log("[ERROR]: " + response.getError()[0].message);
                component.set("v.loadingText", $A.get("$Label.c.CRM_No_Records_Found"));
                var errorToast = $A.get("e.force:showToast");
                errorToast.setParams({
                    "message": response.getError()[0].message,
                    "type": "error"
                });
                errorToast.fire();
            }else{
                console.log("[ERROR] Failed with state: " + state);
            }
        });
        $A.enqueueAction(action);
    }
})