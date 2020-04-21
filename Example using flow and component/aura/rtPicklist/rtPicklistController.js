({
	init : function(component, event, helper) {
		var action = component.get("c.getOptions");
        action.setParams({
            obj : component.get ("v.object")
        });
        action.setCallback(this, function(response){
            var state = response.getState();
            if(state === 'SUCCESS'){
                component.set("v.options",response.getReturnValue());
				console.log (JSON.stringify(response.getReturnValue()));
                console.log(response.getReturnValue()[0].value);
                component.set("v.selectedId",response.getReturnValue()[0].value);
                var options =component.get("v.options");
				console.log()                
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
    onChange: function (cmp, evt, helper) {
        cmp.set("v.selectedId",cmp.find('recordTypeList').get('v.value'));
    }
})