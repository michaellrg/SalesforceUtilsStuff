({
  handleRecordUpdated : function(component, event, helper) {
    var eventParams = event.getParams();
    if(eventParams.changeType === "LOADED" || eventParams.changeType === "CHANGED") {
        var action = component.get("c.getFilter");
            //Set the object Id and Name for query
            var filterField = component.get("v.filterName");
            var obj = component.get("v.object");
            var parentField = component.get("v.externalIdName");
            action.setParams({
                Parameter : filterField,
                ParameterValue : obj[parentField]
            });
            action.setCallback(this, function(response){
                var state = response.getState();
                if(state === 'SUCCESS'){
                    //create data table component
                    var popupDiv = component.find("openDataTable");
                    $A.createComponent(
                        "c:CRM_LightningDataTableComponent",
                        {
                            "objectName": component.get("v.sObjectExternal"),
                            "fieldSet": component.get("v.fieldSetName"),
                            "queryFilter": response.getReturnValue(),
                            "externalObject":component.get("v.sObjectName"),
                            "externalField": parentField
                        },
                        function (popup, state) {
                            if (state === "SUCCESS") {
                                var body = popupDiv.get("v.body");
                                body.push(popup);
                                popupDiv.set("v.body", popup);
                                $A.get('e.force:refreshView').fire();

                            }
                            else {
                                console.log("[ERROR] Failed with state: " + state);
                            }
                        }
                        );

                }else if (state === 'ERROR'){
                    console.log("[ERROR]: " + response.getError()[0].message);
                    var errorToast = $A.get("e.force:showToast");
                    errorToast.setParams({
                        "message": response.getError()[0].message,
                        "type": "error"
                    });
                    errorToast.fire();
                }else{
                    console.log('Something went wrong, Please check with your admin');
                }
            });
            $A.enqueueAction(action);
        }
    },
    doInit: function(component, event, helper){
        var action = component.get("c.getLabel");
        action.setParams({
            externalName : component.get("v.sObjectExternal")
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === 'SUCCESS'){
                component.set("v.headerLabel",response.getReturnValue());

            }else if (state === 'ERROR'){
                console.log("[ERROR]: " + response.getError()[0].message);
                var errorToast = $A.get("e.force:showToast");
                errorToast.setParams({
                    "message": response.getError()[0].message,
                    "type": "error"
                });
                errorToast.fire();
            }else{
                console.log('Something went wrong, Please check with your admin');
            }
        });
        $A.enqueueAction(action);
    },
    isRefreshed: function(component, event, helper) {
         $A.get('e.force:refreshView').fire();
    }

})