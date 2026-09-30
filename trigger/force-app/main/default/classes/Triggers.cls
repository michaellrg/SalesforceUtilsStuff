/**
 * @File Name:   Triggers.cls
 * @Description: Wrapper for triggers
 * @Author:      Michaell Reis
 * @Email:       michaellrg@gmail.com
 * @Project:     Salesforce Utils
 * @Group:       Apex
 * @Modification Log :
 *-------------------------------------------------------------------------------------
 * Ver       Date        Author       Modification
 * 1.0       2018-06-26  Michaell Reis  Created the file/class
 * 3.0       2026-09-30  Michaell Reis         Adapted for Salesforce Utils
 */
public without sharing virtual class Triggers {
  public enum TRG_STATE {
    UNDEL,
    DEL,
    INS,
    UPD,
    INS_UPD,
    INS_DEL,
    BEFR,
    AFTR
  }

  private static final String FLD_RCTYPE, TRG_INS, TRG_UPD, TRG_DEL, TRG_UDEL; // TRG_UPS
  private static final String[] ADDR_FLDS;

  static {
    FLD_RCTYPE = 'RecordTypeId';

    TRG_INS = 'INSERT';
    TRG_UPD = 'UPDATE';
    TRG_DEL = 'DELETE';
    TRG_UDEL = 'UNDELETE';
    //TRG_UPS  = 'UPSERT';

    ADDR_FLDS = new List<String>{
      'City',
      'Country',
      'CountryCode',
      'GeocodeAccuracy',
      'Latitude',
      'Longitude',
      'PostalCode',
      'State',
      'StateCode',
      'Street'
    };
  }

  public static Boolean isExec() {
    return Trigger.isExecuting;
  }

  public List<SObject> newLst {
    get {
      return (null == newLst) ? new List<SObject>() : newLst;
    }
    protected set;
  }
  public List<SObject> oldLst {
    get {
      return (null == oldLst) ? new List<SObject>() : oldLst;
    }
    protected set;
  }
  public Map<Id, SObject> newMap {
    get {
      return (null == newMap) ? new Map<Id, SObject>() : newMap;
    }
    protected set;
  }
  public Map<Id, SObject> oldMap {
    get {
      return (null == oldMap) ? new Map<Id, SObject>() : oldMap;
    }
    protected set;
  }
  public Integer size {
    get {
      return (null == size) ? 0 : size;
    }
    protected set;
  }

  protected Map<TRG_STATE, Boolean> context {
    get {
      return (null == context) ? new Map<TRG_STATE, Boolean>() : context;
    }
    protected set;
  }

  public Boolean isBchORFut {
    get {
      return System.isBatch() || System.isFuture();
    }
  }
  public Boolean hasNewObjs {
    get {
      return !this.newMap.isEmpty();
    }
  }
  public Boolean hasOldObjs {
    get {
      return !this.oldMap.isEmpty();
    }
  }

  public Boolean isBefore {
    get {
      return this.context.get(TRG_STATE.BEFR);
    }
  }
  public Boolean isAfter {
    get {
      return this.context.get(TRG_STATE.AFTR);
    }
  }
  public Boolean isUndelete {
    get {
      return this.context.get(TRG_STATE.UNDEL);
    }
  }
  public Boolean isDelete {
    get {
      return this.context.get(TRG_STATE.DEL);
    }
  }
  public Boolean isInsert {
    get {
      return this.context.get(TRG_STATE.INS);
    }
  }
  public Boolean isUpdate {
    get {
      return this.context.get(TRG_STATE.UPD);
    }
  }
  public Boolean isInsOrUpd {
    get {
      return this.context.get(TRG_STATE.INS_UPD);
    }
  }
  public Boolean isInsOrDel {
    get {
      return this.context.get(TRG_STATE.INS_DEL);
    }
  }
  public String eventName {
    get {
      return (this.isInsert
        ? TRG_INS
        : (this.isUpdate
            ? TRG_UPD
            : (this.isDelete ? TRG_DEL : (this.isUndelete ? TRG_UDEL : ''))));
    }
  }

  public Set<Id> newIds {
    get {
      return this.newMap.keySet();
    }
  }
  public Set<Id> oldIds {
    get {
      return this.oldMap.keySet();
    }
  }
  public List<SObject> allLst() {
    List<SObject> rVal = new List<SObject>(this.newLst);
    rVal.addAll(this.oldLst);
    return rVal;
  }

  /**
   * @Name          Triggers
   * @Description   Constructors and Initialization
   * @Author        Michaell Reis
   */
  public Triggers() {
    this.initialize();
  }
  public virtual void initialize() {
    Boolean canInit = isExec();

    if (canInit || System.Test.isRunningTest()) {
      this.newLst = (Trigger.new != null)
        ? (List<SObject>) Trigger.new
        : new List<SObject>();
      this.oldLst = (Trigger.old != null)
        ? (List<SObject>) Trigger.old
        : new List<SObject>();
      this.newMap = (Trigger.newMap != null)
        ? (Map<Id, SObject>) Trigger.newMap
        : new Map<Id, SObject>();
      this.oldMap = (Trigger.oldMap != null)
        ? (Map<Id, SObject>) Trigger.oldMap
        : new Map<Id, SObject>();
      this.size = Trigger.size;

      this.context = new Map<TRG_STATE, Boolean>{
        TRG_STATE.BEFR => canInit ? Trigger.isBefore : false,
        TRG_STATE.AFTR => canInit ? Trigger.isAfter : false,
        TRG_STATE.UNDEL => canInit ? Trigger.isUnDelete : false,
        TRG_STATE.DEL => canInit ? Trigger.isDelete : false,
        TRG_STATE.INS => canInit ? Trigger.isInsert : false,
        TRG_STATE.UPD => canInit ? Trigger.isUpdate : false,
        TRG_STATE.INS_UPD => canInit
          ? Trigger.isInsert || Trigger.isUpdate
          : false,
        TRG_STATE.INS_DEL => canInit
          ? Trigger.isInsert || Trigger.isDelete
          : false
      };
    }
  }

  /**
   *  @return      Boolean
   *  @description Indicates if an object's field value changed from an old instance
   *  @author      Michaell Reis
   *  @date        2018-06-15
   */
  public Boolean isChanged(SObject pObj, String pFld) {
    // -- Short-circuit checks
    if (this.isInsOrDel)
      return true;
    if (null == pObj || String.isBlank(pFld))
      return false;

    pFld = pFld.trim();
    Boolean rVal = false;
    String[] flds = new List<String>{ pFld };

    SObject oOld = this.oldMap.containsKey(pObj.Id)
        ? this.oldMap.get(pObj.Id)
        : null,
      oNew = this.newMap.containsKey(pObj.Id) ? this.newMap.get(pObj.Id) : null;

    Map<String, Object> fOld = (null == oOld)
        ? new Map<String, Object>()
        : oOld.getPopulatedFieldsAsMap(),
      fNew = (null == oNew)
        ? new Map<String, Object>()
        : oNew.getPopulatedFieldsAsMap();

    if (pFld.endsWith('Address')) {
      // -- Address type/compound field : check all component pieces
      String adrPFix = pFld.replace('Address', '');
      for (String nm : ADDR_FLDS)
        flds.add(adrPFix + nm);
    }
    for (String fld : flds) {
      rVal =
        rVal ||
        ((null != oOld) && (null != oNew)) &&
        (((fOld.containsKey(fld) && !fNew.containsKey(fld)) ||
        (!fOld.containsKey(fld) && fNew.containsKey(fld))) ||
        (fOld.containsKey(fld) &&
        fNew.containsKey(fld) &&
        oOld.get(fld) != oNew.get(fld)));
    }
    return rVal;
  }

  /**
   *  @return      Boolean
   *  @description Indicates if an object's field value changed from an old instance and is now set to a specific value
   *  @author      Michaell Reis
   *  @date        2018-06-15
   */
  public Boolean isChangedTo(SObject pObj, String pFld, Object pVal) {
    return (pObj != null) &&
      this.isChanged(pObj, pFld) &&
      this.newMap.get(pObj.Id).get(pFld) == pVal;
  }

  /**
   *  @return      Boolean
   *  @description Indicates if an object's field value changed from blank to not blank
   *                 ONLY working for string fields at this time
   *                 Enhance behavior as needed
   *
   *  @author      Michaell Reis
   *  @date        2018-06-15
   */
  public Boolean isChangedFromBlank(SObject pObj, String pFld) {
    return this.isInsert
      ? false
      : ((pObj != null) &&
        this.isChanged(pObj, pFld) &&
        String.isBlank((String) this.oldMap.get(pObj.Id).get(pFld)) &&
        String.isNotBlank((String) this.newMap.get(pObj.Id).get(pFld)));
  }

  /**
   * @return        Boolean
   * @description   Indicate if one of the given values have changed; returns true for insert trigger
   * @author        Michaell Reis
   * @date          2018-10-01
   */
  public Boolean hasChangedOR(SObject pObj, List<String> pFlds) {
    Boolean rVal = false;

    for (String fld : null == pFlds ? new List<String>() : pFlds)
      rVal = rVal || this.isChanged(pObj, fld);

    return rVal;
  }

  /**
   * @return        Boolean
   * @description   Indicate if all of the given values have changed; returns true for insert trigger
   * @author        Michaell Reis
   * @date          2018-10-01
   */
  public Boolean hasChangedAND(SObject pObj, List<String> pFlds) {
    Boolean rVal = false;

    for (String fld : null == pFlds ? new List<String>() : pFlds)
      rVal = rVal && this.isChanged(pObj, fld);

    return rVal;
  }

  /**
   * @return        List<SObject>
   * @description   Select SObjects by record type id
   * @author        Michaell Reis
   * @date          2018-10-01
   */
  public List<SObject> filterByRCTypeId(Id pId) {
    List<SObject> rVal = new List<SObject>();

    for (SObject obj : this.hasNewObjs ? this.newLst : this.oldLst) {
      if (obj.get(FLD_RCTYPE) == pId)
        rVal.add(obj);
    }
    return rVal;
  }

  /**
   * @Description   Provides
   *                     1) a new wrapper from a JSON
   *                     2) this existing wrapper as a JSON
   * @Author        Michaell Reis
   * @CreatedDate   2018-06-26
   * @Return        String JSON of this wrapper
   */
  public virtual String asJSON() {
    return JSON.serialize(this);
  }
  public virtual Triggers fromJSON(String pData) {
    return (Triggers) JSON.deserializeStrict(pData, Triggers.class);
  }
}
