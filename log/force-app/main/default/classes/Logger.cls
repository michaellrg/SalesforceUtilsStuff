/**
 * @File Name:   Logger.cls
 * @Description: Salesforce Utils logger for application and integration diagnostics
 *               Logger.Instance.log('Trace Information');
 *               Logger.Instance.log(e);
 *               Logger.Instance.push();//push all logs
 *               Logger.Instance.pushAsync();//push all logs
 * @Author:      Michaell Reis
 * @Email:       michaellrg@gmail.com
 * @Project:     Salesforce Utils
 * @Group:       Apex
 * @Last Modified by:   Michaell Reis
 * @Last Modified time: 2018-06-03 01:56:09
 * @Modification Log :
 *-------------------------------------------------------------------------------------
 * Ver       Date        Author      Modification
 * 1.0       2017-05-21  Michaell Reis    Created the file/class
 * 1.1       2018-05-12  Michaell Reis    Support error handling for upsert Result
 * 1.2       2018-05-12  Michaell Reis    Add new constructor to aceept nameValues
 * 1.3       2018-05-24  Michaell Reis    Support event logs
 * 1.4       2026-09-30  Michaell Reis    Adapted for Salesforce Utils
 */
public with sharing class Logger {
  public static final String FRAMEWORK_NAME = 'Salesforce Utils';
  public enum SEVERITY_TYPES {
    ERROR,
    CONFIRM,
    FATAL,
    INFO,
    WARNING
  } // -- Types of log

    public  static final Map<String, Schema.RecordTypeInfo> RC_TYPES;

  public static final Id DEFAULT_LOG_RECORDTYPE;
  private static final Integer MAX_LENGTH_DESCRIPTION,
    MAX_LENGTH_STACK_TRACE,
    MAX_LENGTH_COMMENT;
  private static final Boolean ENABLE_LOGS;
  public static Boolean ENABLE_EVENT;
  private static String PRJCATEG_DEF;
  public static SEVERITY_TYPES DEFAULT_LOG_TYPE;

  private List<SObject> lsLogs = new List<SObject>(); // -- Caching for DML
  private Boolean isFutureBatch {
    get {
      return System.isFuture() || System.isBatch();
    }
  }

    static
    {
        RC_TYPES = new Map<String, Schema.RecordTypeInfo>();
        for(Schema.RecordTypeInfo rt : Schema.getGlobalDescribe().get('Log__c').getDescribe().getRecordTypeInfos()) { 
          RC_TYPES.put(rt.getDeveloperName(), rt); }

        DEFAULT_LOG_RECORDTYPE = RC_TYPES.get('Application_Log').getRecordTypeId();

    DEFAULT_LOG_TYPE = SEVERITY_TYPES.ERROR; // -- Default type of log
    ENABLE_LOGS = true; // -- Switch for all logs, can be associate with a custom setting
    ENABLE_EVENT = false; // -- When true, logs are push as event

    MAX_LENGTH_DESCRIPTION = 32768; // -- Max length of description
    MAX_LENGTH_STACK_TRACE = 32768; // -- Max length of stack trace
    MAX_LENGTH_COMMENT = 1000; // -- Max length of comment

        PRJCATEG_DEF = 'Default';
    }

  /**
   * @Name          log
   * @Description   Add new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-12
   * @Param         Map<String, Object> keyValues
   * @Return        Logger
   */
  public Logger log(Map<String, Object> keyValues) {
    if (keyValues == null)
      return this;

    Type t = null;
    if (
      keyValues.containsKey('ClassObject') &&
      keyValues.get('ClassObject') != null
    ) {
      t = (Type) keyValues.get('ClassObject');
      keyValues.put('ClassObject', null);
    }

    Exception e = null;
    if (
      keyValues.containsKey('ExceptionObj') &&
      keyValues.get('ExceptionObj') != null
    ) {
      e = (Exception) keyValues.get('ExceptionObj');
      keyValues.put('ExceptionObj', null);
    }

    String jsonStr = JSON.serialize(keyValues);
    Log l = (Log) JSON.deserializeStrict(jsonStr, Log.class);

    //process object which that are not support in JSON
    if (t != null)
      l.ClassObject = t;
    if (e != null)
      l.ExceptionObj = e;
    if (l.Severity == null)
      l.Severity = l.ExceptionObj == null
        ? DEFAULT_LOG_TYPE
        : SEVERITY_TYPES.ERROR;

    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          add
   * @Description   Add new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Param         Exception e
   * @Return        Logger
   */
  public Logger log(Exception e) {
    Log l = new Log();
    l.ExceptionObj = e;
    l.Severity = DEFAULT_LOG_TYPE;
    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          add
   * @Description   Add new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Param         String comments
   * @Return        Logger
   */
  public Logger log(String comments) {
    return log(comments, SEVERITY_TYPES.INFO);
  }

  /**
   * @Name          log
   * @Description   Add new String log
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-05
   * @Param         String comments
   * @Param         Logger.SEVERITY_TYPES severity
   * @Return        Logger
   */
  public Logger log(String comments, Logger.SEVERITY_TYPES severity) {
    Log l = new Log();
    l.Comments = comments;
    l.Severity = severity;
    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          add
   * @Description   Add new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Param         Exception e
   * @Param         Type t   Apex Class
   * @Return        Logger
   */
  public Logger log(Exception e, Type t) {
    Log l = new Log();
    l.ClassObject = t;
    l.ExceptionObj = e;
    l.Severity = DEFAULT_LOG_TYPE;
    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          log
   * @Description   Add a new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-02
   * @Param         Exception e
   * @Param         Type t
   * @Param         String sourceId
   * @Return        Logger
   */
  public Logger log(Exception e, String sourceId, Type t) {
    Log l = new Log();
    l.ClassObject = t;
    l.ExceptionObj = e;
    l.Severity = DEFAULT_LOG_TYPE;
    l.SourceId = sourceId;
    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          add
   * @Description   Add new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Param         Exception e
   * @Param         Type t   Apex Class
   * @Param         String category
   * @Return        Logger
   */
  public Logger log(Exception e, Type t, String category) {
    Log l = new Log();
    l.ClassObject = t;
    l.Severity = DEFAULT_LOG_TYPE;
    l.ExceptionObj = e;
    l.Category = category;
    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          add
   * @Description   Add new log
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Param         Exception e
   * @Param         Type t   Apex Class
   * @Param         String category
   * @Param         SEVERITY_TYPES type
   * @Param         String sourceId
   * @Return        Logger
   */
  public Logger log(
    Exception e,
    Type t,
    String category,
    SEVERITY_TYPES type,
    String sourceId
  ) {
    Log l = new Log();
    l.SourceId = sourceId;
    l.ClassObject = t;
    l.Severity = type;
    l.ExceptionObj = e;
    l.Category = category;
    lsLogs.add(l.createSystemLog());
    return this;
  }

  /**
   * @Name          log
   * @Description   Log Database.SaveResult
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-05
   * @Param         List<SaveResult> results
   * @Return        Logger
   */
  public Logger log(List<Database.SaveResult> results) {
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        String error = String.valueOf(i + 1) + '. ';
        for (Database.Error err : results[i].getErrors())
          error += err.getMessage() + '; ';
        this.log('Database Error: ' + error, SEVERITY_TYPES.Error);
      }
    }
    return this;
  }
  public Logger log(List<Database.UpsertResult> results) {
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        String error = String.valueOf(i + 1) + '. ';
        for (Database.Error err : results[i].getErrors())
          error += err.getMessage() + '; ';
        this.log('Database Error: ' + error, SEVERITY_TYPES.Error);
      }
    }
    return this;
  }
  /**
   * @Name          add
   * @Description   Add new log
 * @Author        Michaell Reis
   * @CreatedDate   2021-06-06
   * @Param         Exception e
   * @Return        Log__c
   */
  public Log__c logObject(Exception e) {
    Log l = new Log();
    l.ExceptionObj = e;
    l.Severity = DEFAULT_LOG_TYPE;
    return l.createSystemLog();
  }

  /**
   * @Name          add
   * @Description   Add new log
 * @Author        Michaell Reis
   * @CreatedDate   2021-06-06
   * @Param         String comments
   * @Return        Log__c
   */
  public Log__c logObject(String comments) {
    return logObject(comments, SEVERITY_TYPES.INFO);
  }

  /**
   * @Name          log
   * @Description   Add new String log
 * @Author        Michaell Reis
   * @CreatedDate   2018-05-05
   * @Param         String comments
   * @Param         Logger.SEVERITY_TYPES severity
   * @Return        Log__c
   */
  public Log__c logObject(String comments, Logger.SEVERITY_TYPES severity) {
    Log l = new Log();
    l.Comments = comments;
    l.Severity = severity;
    return l.createSystemLog();
  }

  /**
   * @Name          add
   * @Description   Add new log
 * @Author        Michaell Reis
   * @CreatedDate   2021-06-06
   * @Param         Exception e
   * @Param         Type t   Apex Class
   * @Return        Log__c
   */
  public Log__c logObject(Exception e, Type t) {
    Log l = new Log();
    l.ClassObject = t;
    l.ExceptionObj = e;
    l.Severity = DEFAULT_LOG_TYPE;
    return l.createSystemLog();
  }

  /**
   * @Name          log
   * @Description   Add a new log
 * @Author        Michaell Reis
   * @CreatedDate   2018-02-02
   * @Param         Exception e
   * @Param         Type t
   * @Param         String sourceId
   * @Return        Log__c
   */
  public Log__c logObject(Exception e, String sourceId, Type t) {
    Log l = new Log();
    l.ClassObject = t;
    l.ExceptionObj = e;
    l.Severity = DEFAULT_LOG_TYPE;
    l.SourceId = sourceId;
    return l.createSystemLog();
  }

  /**
   * @Name          add
   * @Description   Add new log
 * @Author        Michaell Reis
   * @CreatedDate   2021-06-06
   * @Param         Exception e
   * @Param         Type t   Apex Class
   * @Param         String category
   * @Return        Log__c
   */
  public Log__c logObject(Exception e, Type t, String category) {
    Log l = new Log();
    l.ClassObject = t;
    l.Severity = DEFAULT_LOG_TYPE;
    l.ExceptionObj = e;
    l.Category = category;
    return l.createSystemLog();
  }

  /**
   * @Name          add
   * @Description   Add new log
 * @Author        Michaell Reis
   * @CreatedDate   2021-06-06
   * @Param         Exception e
   * @Param         Type t   Apex Class
   * @Param         String category
   * @Param         SEVERITY_TYPES type
   * @Param         String sourceId
   * @Return        Log__c
   */
  public Log__c logObject(
    Exception e,
    Type t,
    String category,
    SEVERITY_TYPES type,
    String sourceId
  ) {
    Log l = new Log();
    l.SourceId = sourceId;
    l.ClassObject = t;
    l.Severity = type;
    l.ExceptionObj = e;
    l.Category = category;
    return l.createSystemLog();
  }
  /**
   * @Name          save
   * @Description   Commit the logs into database
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Return        void
   */
  public void push() {
    if (ENABLE_LOGS == false || lsLogs.isEmpty())
      return;

    if (ENABLE_EVENT)
      insertLogEvents(getJSONData());
    else {
      if (!lsLogs.isEmpty())
        insert lsLogs;
    }

    this.flush();
  }

  /**
   * @Name          pushAsync
   * @Description   Save log to Salesforce asynchronously
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Return        void
   */
  public void pushAsync() {
    if (ENABLE_LOGS == false || lsLogs.isEmpty())
      return;

    // -- If already in a batch/@future, don't @future again - perform a normal [push]
    if (this.isFutureBatch)
      push();
    else {
      String[] jsonStrs = getJSONData();
      if (ENABLE_EVENT)
        insertLogEventsFuture(jsonStrs);
      else
        insertFuture(jsonStrs);

      this.flush();
    }
  }

  /**
   * @Name          getJSONData
   * @Description   convert current log list to a list of json
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-24
   * @Return        List<String>
   */
  @testVisible
  private List<String> getJSONData() {
    List<String> jsonStrs;
    if (lsLogs.size() > 0) {
      jsonStrs = new List<String>();
      for (SObject obj : lsLogs) {
        Log__c sLog = (Log__c) obj;
        jsonStrs.add(JSON.serialize(sLog));
      }
    }
    return jsonStrs;
  }

  /**
   * @Name          flush
   * @Description   flush the cache
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Return        void
   */
  private void flush() {
    lsLogs.clear();
  }

  /**
   * @Name          insertFuture
   * @Description   Insert sobject in asynchronous mode
   * @Author        Michaell Reis
   * @CreatedDate   2017-05-21
   * @Param         string jsonStr
   * @Return        void
   */
  @future
  private static void insertFuture(String jsonStr) {
    insertFuture(new List<String>{ jsonStr });
  }

  /**
   * @Name          insertFuture
   * @Description   Insert list of sobject in asynchronous mode
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   * @Param         List<String> jsonStr
   * @Return        void
   */
  @future
  private static void insertFuture(List<String> jsonStrs) {
    List<SObject> toInsert = new List<SObject>();

    for (String j : jsonStrs) {
      toInsert.add((SObject) JSON.deserialize(j, SObject.class));
    }
    insert toInsert;
  }

  /**
   * @Name          insertEvents
   * @Description   insert log as platform events
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-24
   * @Param         List<String> jsonStrs
   * @Return        void
   */
  @testVisible
  private static void insertLogEvents(List<String> jsonStrs) {
    if (jsonStrs == null || jsonStrs.size() == 0)
      return;

    List<LogEvent__e> events = new List<LogEvent__e>();
    for (String j : jsonStrs) {
      events.add(new LogEvent__e(JSON_Data__c = j));
    }

    EventBus.publish(events);
  }

  /**
   * @Name          insertLogEvent
   * @Description   insert a new log event
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-28
   * @Param         Log__c sLog
   * @Return        void
   */
  public static void insertLogEvent(Log__c sLog) {
    if (sLog == null)
      return;

    String jsonData = JSON.serialize(sLog);
    insertLogEvents(new List<String>{ jsonData });
  }

  /**
   * @Name          insertLogEvent
   * @Description   insert a new log event
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-28
   * @Param         String jsonData
   * @Return        void
   */
  public static void insertLogEvent(String jsonData) {
    if (String.isBlank(jsonData))
      return;

    insertLogEvents(new List<String>{ jsonData });
  }

  /**
   * @Name          insertEventsFuture
   * @Description   insert log as platform events, comparing to direct DML, this can avoid rolling back when
   *                uncaught exceptions
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-24
   * @Param         List<String> jsonStrs
   * @Return        void
   */
  @future
  @testVisible
  private static void insertLogEventsFuture(List<String> jsonStrs) {
    insertLogEvents(jsonStrs);
  }

  /**
   * @Name          formatGeneralLogs
   * @Description   attach general information for EN logs
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-29
   * @Param         Log__c oSL
   * @Return        void
   */
  public static void formatGeneralLogs(Log__c oSL) {
    oSL.Application_Id__c = oSL.Source_Id__c; // will be new application object id
    oSL.Is_Logged_In__c = UserInfo.getUserType() == 'Guest' ? 'No' : 'Yes';
    oSL.Language__c = UserInfo.getLanguage();
    oSL.Session_Id__c = UserInfo.getSessionId();
    oSL.Category__c = String.isEmpty(oSL.Category__c)
      ? PRJCATEG_DEF
      : oSL.Category__c;
  }

  /**
   * @Name          Log Object
   * @Description   Warpper class to contain log information
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-01
   */
  private class Log {
    public SEVERITY_TYPES Severity { get; set; } //severity type

    public Type ClassObject { get; set; } //class type
    public Exception ExceptionObj { get; set; } //exception instance

    public String SourceId { get; set; } //source record id
    public String Category { get; set; } //category of system log
    public String Comments { get; set; } //comment of the log

    /**
     * @Name          createSystemLog
     * @Description   Create and insert system log
     * @Author        Michaell Reis
     * @CreatedDate   2017-05-21
     * @Param         Logger sysLog
     * @Return        void
     */
    public Log__c createSystemLog() {
      return initializeSystemLog();
    }

    /**
     * @Name          initializeSystemLog
     * @Description   Extract and generate sobject
     * @Author        Michaell Reis
     * @CreatedDate   2017-05-21
     * @Param         Logger log
     * @Return        Log__c
     */
    private Log__c initializeSystemLog() {
      Log__c oSL = new Log__c(RecordTypeId = DEFAULT_LOG_RECORDTYPE);

      oSL.Severity__c = String.valueOf(this.Severity);
      oSL.Category__c = String.isBlank(this.Category)
        ? 'Default'
        : this.Category;
      oSL.Source_Id__c = String.isBlank(this.SourceId) ? '' : this.SourceId;
      oSL.Comment__c = String.isBlank(this.Comments)
        ? ''
        : truncate(this.Comments, MAX_LENGTH_COMMENT);
      oSL.Apex_Class__c = null == this.ClassObject
        ? ''
        : String.valueOf(this.ClassObject).split(':')[0];

      if (this.exceptionObj != null) {
        oSL.Description__c = truncate(
          'Cause: ' +
            this.exceptionObj.getCause() +
            '\r\n' +
            this.exceptionObj.getMessage(),
          MAX_LENGTH_DESCRIPTION
        );
        oSL.Exception_Stack_Trace__c = truncate(
          this.exceptionObj.getStackTraceString(),
          MAX_LENGTH_STACK_TRACE
        );
        oSL.Exception_Type__c = this.exceptionObj.getTypeName();
      }
      Logger.formatGeneralLogs(oSL);

      return oSL;
    }

    /**
     * @Name          truncate
     * @Description   truncate log if oversized
     * @Author        Michaell Reis
     * @CreatedDate   2017-05-21
     * @Param         string log
     * @Param         Integer length
     * @Return        string
     */
    private string truncate(String field, Integer length) {
      return field == null
        ? field
        : field.substring(0, Math.Min(field.length(), length));
    }
  }

  /**
   * @Name          LoggerException
   * @Description   Exception Class
   * @Author        Michaell Reis
   * @CreatedDate   2018-02-03
   */
  public class LoggerException extends Exception {
  }
}
