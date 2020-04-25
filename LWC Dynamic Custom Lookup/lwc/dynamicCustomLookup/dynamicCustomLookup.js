import {
    LightningElement,
    api,
    wire,
    track
} from 'lwc';
import fetchExtendedLookUpValues from '@salesforce/apex/DynamicCustomLookupController.fetchExtendedLookUpValues';
import getFieldLabel from '@salesforce/apex/DynamicCustomLookupController.getFieldLabel';
import fetchObjectLookup from '@salesforce/apex/DynamicCustomLookupController.fetchObjectLookup';
import {
  refreshApex
} from '@salesforce/apex';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import {
  getRecord
} from 'lightning/uiRecordApi';
import {
  updateRecord
} from 'lightning/uiRecordApi';


export default class dynamicCustomLookup extends LightningElement {
                 @api objectApi;
                 @api objectApiName;
                 @api enableButton = false;
                 @api iconName;
                 @api fieldSet = null;
                 @api fieldName = null;
                 @api fieldAPI = null;
                 @api label;
                 @api record;
                 @track recordIdParent;
                 @track resultClass;
                 @track selectedRecord = null;
                 @track results = null;
                 @track message = null;
                 @track showSpinner = false;
                 @track lastSearchValue;
                 @api recordId;
                 @wire(getRecord, {
                   recordId: "$recordId",
                   layoutTypes: ["Full"]
                 })
                 wiredRecord({
                   error,
                   data
                 }) {
                   if (error) {
                     let message = 'Unknown error';
                     if (Array.isArray(error.body)) {
                       message = error.body.map(e => e.message).join(', ');
                     } else if (typeof error.body.message === 'string') {
                       message = error.body.message;
                     }
                     this.dispatchEvent(
                       new ShowToastEvent({
                         title: 'Error loading the record',
                         message,
                         variant: 'error',
                       }),
                     );
                   } else if (data) {
                     this.record = data;
                     this.recordIdParent = this.record.fields[this.fieldAPI].value;
                     if(this.record.fields[this.fieldAPI].value!= undefined ){
                      let parentObject = {
                        recordId: this.record.fields[this.fieldAPI].value,
                        objectName: this.objectApiName
                      };
                      fetchObjectLookup(parentObject)
                        .then((result) => {
                          this.selectedRecord = result;
                          return refreshApex(this.record);

                        })
                        .catch((error) => {
                          this.dispatchEvent(
                            new ShowToastEvent({
                              title: "Error",
                              message: error.body.message,
                              variant: "error"
                            })
                          );
                        });
                     }

                   }
                 }


                 constructor() {
                   super();
                   this.switchResult(false);

                 }

                 renderedCallback() {


                 }

                 connectedCallback() {

                   let infoLabel = {
                     objectName: this.objectApiName,
                     fieldName: this.fieldAPI
                   };
                   getFieldLabel(infoLabel)
                     .then((result) => {
                       this.label = result;
                     })
                     .catch((error) => {
                       this.dispatchEvent(
                         new ShowToastEvent({
                           title: "Error",
                           message: error.body.message,
                           variant: "error"
                         })
                       );
                     });


                 }

                 handleSearchTerm(event) {
                   let searchValue = event.detail;
                   if (searchValue) {
                     this.switchResult(true);
                     this.message = "searching...";
                     this.showSpinner = true;
                     let searchParams = {
                       searchKeyWord: searchValue,
                       objectName: this.objectApi,
                       fieldSetName: this.fieldSet
                     };

                    fetchExtendedLookUpValues(searchParams)
                      .then((result) => this.setResult(result))
                      .catch((error) => this.handleError(error));

                   } else {
                     this.switchResult(false);
                     this.message = null;
                     this.showSpinner = false;
                     this.results = null;
                   }
                   this.lastSearchValue = searchValue;
                 }

                 dedupeArray(incoming) {
                   var uniqEs6 = (arrArg) => {
                     return arrArg.filter((elem, pos, arr) => {
                       return arr.indexOf(elem) === pos;
                     });
                   };
                   return uniqEs6(incoming);
                 }

                 setResult(newValues) {
                   this.showSpinner = false;
                   if (newValues && newValues.length > 0) {
                     this.message = null;
                     this.results = newValues;
                   } else {
                     this.message = "no results found";
                   }
                 }

                 /* Shows and hides the result area */
                 switchResult(on) {
                   this.resultClass = on
                     ? "slds-form-element slds-lookup slds-is-open"
                     : "slds-form-element slds-lookup slds-is-close";
                 }

                 handlePillRemove() {
                   this.selectedRecord = null;
                   this.dispatchSelectionResult();
                   // Restore last results
                   this.switchResult(this.lastSearchValue && this.results);
                 }

                 /* Sends back the result of a selection, compatible to extendedForm
       when the property fieldName is set
    */
                 dispatchSelectionResult() {
                   let eventName = this.fieldName
                     ? "valueChanged"
                     : "recordselected";
                   let payload = {
                     canceled: this.selectedRecord ? true : false,
                     recordId: this.selectedRecord,
                     value: this.selectedRecord,
                     name: this.fieldName
                   };
                   let selected = new CustomEvent(eventName, {
                     detail: payload,
                     bubbles: true,
                     cancelable: true
                   });
                   this.dispatchEvent(selected);
                 }

                 handleError(error) {
                   this.showSpinner = false;
                   this.message = "Sorry didn't work!";
                   let errorDispatch = new CustomEvent("failure", {
                     detail: error
                   });
                   this.dispatchEvent(errorDispatch);
                 }

                 handleRecordSelect(event) {
                   this.selectedRecord = event.detail;
                   this.dispatchSelectionResult();
                   this.switchResult(false);
                 }

                 updateObject(event) {
                  console.log('Enter '+JSON.stringify(this.selectedRecord));
                  const fields = {};
                  if (this.selectedRecord != null) {
                    for (let value of this.results) {
                    if(value["Id"] == this.selectedRecord["Id"]){
                      this.selectedRecord = value;
                      break;
                    }
                  }


                      Object.keys(this.selectedRecord).forEach(item => {
                         if(item !="Id" && item!= "Name"){
                          fields[item] = this.selectedRecord[item];
                         }else if(item =="Id"){
                          fields[this.fieldAPI] = this.selectedRecord.Id;
                         }
                       });
                 }else{
                   fields[this.fieldAPI]=null;
                 }
                       fields["Id"] = this.recordId;
                       const recordInput = {fields};
                       console.log(JSON.stringify(this.record));
                       console.log(JSON.stringify(recordInput));
                       updateRecord(recordInput)
                         .then(() => {
                           this.dispatchEvent(
                             new ShowToastEvent({
                               title: 'Success',
                               message: 'Updated',
                               variant: 'success'
                             })
                           );
                           console.log('Success');
                           // Display fresh data in the form
                           return refreshApex(this.record);
                         })
                         .catch(error => {
                           this.dispatchEvent(
                             new ShowToastEvent({
                               title: 'Error creating record',
                               message: error.body.message,
                               variant: 'error'
                             })
                           );
                           console.log('Error');
                         });
                       }
}