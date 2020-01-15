({
	getLabel : function(component, event,helper) {

        var action = component.get("c.getNameLabelField");

        action.setParams({
            objectName   : component.get("v.externalObject"),
            fieldName    : component.get("v.externalField")
        });

        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === 'SUCCESS'){
                    //create data table component
                    component.set("v.externalLabel",response.getReturnValue());

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
})