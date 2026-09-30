/**
 * @author Michaell Reis
 * @date 12/01/2017
 * @description Salesforce Utils adapter for REST and SOAP callout logs
 * @contact michaellrg@gmail.com
 *                   NOTE - SOAP : If needed, uncomment all the [--SOAP--]>> lines/sections
 *                   NOTE - SOAP : If needed, uncomment all the [--SOAP--]>> lines/sections
 * <p>
 * Test Class: PayloadGenerator_Test
 * V1.0 -> 12/01/2017, Michaell Reis, Initial Commit + raw JSON support
 * V2.0 -> 02/14/2018, Michaell Reis, Basic SOAP hooks
 * V2.1 -> 05/01/2018, Michaell Reis, Truncate incoming payload
 * V2.2 -> 05/20/2018, Michaell Reis, Add log payload log record type
 * V2.3 -> 05/28/2018, Michaell Reis, Support log event
 * V2.4 -> 05/28/2018, Michaell Reis, Support custom inbound and outbound messages
 * V2.5 -> 05/28/2018, Michaell Reis, Add traceability id
 */
public with sharing class PayloadLog {
  public enum LOG_STAT {
    Failure,
    Success
  }

  public Integer StatusCode { get; set; }
  public String OperationName { get; set; }
  public String Endpoint { get; set; }
  public String SourceId { get; set; }
  public String Status { get; set; }
  public String OutgoingJSONPayload { get; set; }
  public String IncomingJSONPayload { get; set; }
  public String HMTLErrorMessage { get; set; }
  public String TracebilityId { get; set; }

  public Exception ExceptionObj { get; set; }
  public PayloadOperation Operation { get; set; }
  public String HTTPMethod { get; set; }

  @TestVisible
  private static final String RE_CLEAN_SOAP,
    LOG_CONTENT_BLOCK_MSG;
  private static final Boolean ENABLE_TRANSMIT_LOGS_CONTENT,
    ENABLE_TRANSMIT_LOGS;
  public static Boolean ENABLE_EVENT;
  public static final Id PAYLOAD_LOG_RECORDTYPE;

  static {
    LOG_CONTENT_BLOCK_MSG = 'Blocked';
    ENABLE_EVENT = false; // -- When true, logs are push as event
    RE_CLEAN_SOAP = '"[a-zA-Z\\_]+_type_info":\\[("[a-zA-Z0-9\\:\\_\\-\\.\\/]*"\\,?)*\\]\\,?';

    ENABLE_TRANSMIT_LOGS_CONTENT = true; //switch to enable logging outgoing and incoming data
    ENABLE_TRANSMIT_LOGS = true; //switch to enable log

    PAYLOAD_LOG_RECORDTYPE = Logger.RC_TYPES.get('Payload_Log').getRecordTypeId();
  }

  public PayloadLog() {
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Payload log consturctor for REST
   * @param PayloadOperation info, Operation instance to use for mappings
   * @param HttpRequest  request, REST request to consider
   * @param HttpResponse response, REST response to consider
   * @param Exception e, Exception to consider
   */
  public PayloadLog(
    PayloadOperation info,
    HttpRequest request,
    HttpResponse response,
    Exception e
  ) {
    init(info, request, response, e);
  }

  /**
   * @Name          PayloadLog
   * @Description   Allow custom payload logs
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-28
   * @Param         PayloadOperation info
   * @Param         HttpRequest request
   * @Param         HttpResponse response
   * @Param         Exception e
   * @Param         String customOutgoingPayload
   * @Param         String customInboundPayload
   * @Return        N/A
   */
  public PayloadLog(
    PayloadOperation info,
    HttpRequest request,
    HttpResponse response,
    Exception e,
    String customOutgoingPayload,
    String customInboundPayload
  ) {
    init(info, request, response, e);

    this.OutgoingJSONPayload = String.isNotBlank(customOutgoingPayload)
      ? customOutgoingPayload
      : this.OutgoingJSONPayload;
    this.IncomingJSONPayload = String.isNotBlank(customInboundPayload)
      ? customInboundPayload
      : this.IncomingJSONPayload;
    this.HMTLErrorMessage = String.isNotBlank(customInboundPayload)
      ? customInboundPayload
      : this.IncomingJSONPayload;
  }

  /**
   * @Name          init
   * @Description   Initialize payload log
   * @Author        Michaell Reis
   * @CreatedDate   2018-05-28
   * @Param         PayloadOperation info
   * @Param         HttpRequest request
   * @Param         HttpResponse response
   * @Param         Exception e
   * @Return        void
   */
  private void init(
    PayloadOperation info,
    HttpRequest request,
    HttpResponse response,
    Exception e
  ) {
    String headVal;
    Integer sc;

    this.Status = LOG_STAT.FAILURE.Name();
    this.ExceptionObj = e;
    this.HMTLErrorMessage =
      '<<Response is empty>>\n' +
      (request == null
        ? '<<Request is also null>>'
        : '<<Request:>> ' + request.toString());

    if (info != null) {
      this.SourceId = info.SourceId;
      this.OperationName = info.Name;
      this.Operation = info;
    }
    if (request != null) {
      this.Endpoint = request.getEndpoint();
      this.HTTPMethod = request.getMethod();
      this.OutgoingJSONPayload = request.getBody(); //be careful, could be big in size

      headVal = request.getHeader('uservice-traceability-id');
      this.TracebilityId = String.isBlank(headVal) ? '' : headVal;
    }
    if (response != null) {
      sc = response.getStatusCode();

      this.Status = (sc < 300 &&
        sc >= 100
        ? LOG_STAT.SUCCESS.Name()
        : this.Status);
      this.StatusCode = response.getStatusCode();

      this.IncomingJSONPayload = response.getBody(); //be careful, could be big in size
      this.HMTLErrorMessage = TruncateLog(this.IncomingJSONPayload, 5000);
    }
  }

  /**
   * @author Michaell Reis
   * @date 02/14/2018
   * @description Payload log consturctor for SOAP
   * @param PayloadOperation info, Operation instance to use for mappings
   * @param PayloadGenerator.SOAPObjectRequest request, SOAP request to consider
   * @param Object response, SOAP response to consider
   * @param Exception e, Exception to consider
   * @param String soapSrc, (Optional) source data that was used to build the request parameter
   */
  /* [--SOAP--]
    public PayloadLog(PayloadOperation info, PayloadGenerator.SOAPObjectRequest request, Object response, Exception e, String soapSrc)
    {
        this.ExceptionObj = e;
        if (info != null){
            this.SourceId = info.SourceId;
            this.OperationName = info.Name;
            this.Operation = info;
        }
        if (request != null){
            this.Endpoint = info.getEndpoint(null);
            this.HTTPMethod = PayloadGenerator.parseHttpMethod('SOAP');
            this.OutgoingJSONPayload = (String.isBlank(soapSrc) ? '' : '<<Source data:----->>\n' + soapSrc + '\n')
                + PayloadLog.cleanSoapPrefixFromRaw(JSON.serialize(request));
        }
        if (response != null){
            this.StatusCode = 200;
            this.Status = 'SUCCESS';
            this.IncomingJSONPayload = PayloadLog.cleanSoapPrefixFromRaw(JSON.serialize(response));
            //this.HMTLErrorMessage    = this.IncomingJSONPayload;
        } else {
            this.StatusCode = 500;
            this.Status = 'FAILURE';
            this.HMTLErrorMessage = '<<Response is empty>>\n'
                + (request == null ? '<<Request is also null>>' : '<<Request:>> ' + this.OutgoingJSONPayload);
        }
    }*/

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Entry point to create and insert system log
   */
  public Log__c push() {
    return PayloadLog.createSystemLog(this);
  }

  /**
 * @author Michaell Reis
   * @date 2018-05-11
   * @description Create and insert bulkified system logs
   * @param List<PayloadLog> syLogs, Log sources to insert
   * @return List<Payload_Log__c>, logs that was inserted
   */
  public static List<Log__c> createSystemLogs(List<PayloadLog> syLogs) {
    List<Log__c> insts = new List<Log__c>();

    if (ENABLE_TRANSMIT_LOGS && syLogs != null) {
      for (PayloadLog syLog : syLogs) {
        insts.add(initializeSystemLog(syLog));
      }
      Database.insert(insts);
    }
    return insts;
  }

  /**
   * @author Michaell Reis
   * @date 06/02/2021
   * @description Initialize a new log based on the given context
   * @param PayloadLog syLog, Log source to consider
   * @return Log__c, new log entry
   */
  public static Log__c generateLogObject(PayloadLog log) {
    return initializeSystemLog(log);
  }
  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Initialize a new log based on the given context
   * @param PayloadLog syLog, Log source to consider
   * @return Log__c, new log entry
   */
  private static Log__c initializeSystemLog(PayloadLog log) {
    Log__c oSL = new Log__c(RecordTypeId = PAYLOAD_LOG_RECORDTYPE);

    oSL.Status__c = log.Status;
    oSL.Source_Id__c = log.SourceId;
    oSL.Remote_Endpoint__c = log.Endpoint;
    oSL.HTTP_Status_Code__c = log.StatusCode;
    oSL.Outgoing_Payload__c = LOG_CONTENT_BLOCK_MSG;
    oSL.Incoming_Payload__c = LOG_CONTENT_BLOCK_MSG;
    oSL.Exception_Description_HTML__c = TruncateLog(
      log.HMTLErrorMessage,
      (Log__c.Exception_Description_HTML__c.getDescribe().getLength() / 2)
    );
    if (ENABLE_TRANSMIT_LOGS_CONTENT) {
      oSL.Outgoing_Payload__c = TruncateLog(
        log.OutgoingJSONPayload,
        Log__c.Outgoing_Payload__c.getDescribe().getLength()
      );
      oSL.Incoming_Payload__c = TruncateLog(
        log.IncomingJSONPayload,
        Log__c.Incoming_Payload__c.getDescribe().getLength()
      );
    }
    if (log.Operation != null) {
      oSL.Operation_Name__c = log.Operation.Name;
    }
    if (log.HTTPMethod != null) {
      osl.Operation_Method__c = log.HTTPMethod;
    }
    if (log.Status == 'FAILURE' && log.ExceptionObj != null) {
      oSL.Description__c = log.exceptionObj.getMessage();
      oSL.Exception_Type__c = log.exceptionObj.getTypeName();
      oSL.Exception_Stack_Trace__c = log.exceptionObj.getStackTraceString();
    }
    oSL.Traceability_Id__c = log.TracebilityId;

    Logger.formatGeneralLogs(oSL); // -- Attach general information

    return oSL;
  }
  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Truncate the given log string to the given length
   * @param String log, Log text to consider
   * @param Integer length, lenght to consider; will apply a buffer of 1000 characters
   * @return String, log text, as given as from input or trunctated to the given lenght minus 1000 changes
   */
  private static String TruncateLog(String log, Integer length) {
    return null == log
      ? log
      : log.left(
          Math.Min(
            log.length(),
            (log.length() >= length - 1000) ? length - 1000 : length
          )
        );
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Create and insert system log
   * @param PayloadLog syLog, Log source to insert
   * @return Log__c, log that was inserted
   */
  public static Log__c createSystemLog(PayloadLog syLog) {
    Log__c inst;

    if (ENABLE_TRANSMIT_LOGS)
      inst = initializeSystemLog(syLog);
    if (inst != null) {
      System.debug('inst: ' + inst);
      if (ENABLE_EVENT)
        Logger.insertLogEvent(inst);
      else
        Database.insert(inst);
    }
    return inst;
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Create and insert system log
   * @param PayloadLog syLog, Log source to insert
   * @return Log__c, log that is going to be inserted later (future)
   */
  public static Log__c createSystemLogFuture(PayloadLog syLog) {
    Log__c payloadLog = initializeSystemLog(syLog);

    if (ENABLE_TRANSMIT_LOGS)
      InsertFuture(JSON.serialize(initializeSystemLog(syLog)));

    return payloadLog;
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Insert the given object, but later
   * @param String pObj, Object to insert
   */
  @future
  private static void InsertFuture(String pObj) {
    if (ENABLE_EVENT)
      Logger.insertLogEvent(pObj);
    else
      Database.insert((SObject) json.deserialize(pObj, SObject.class));
  }

  /**
   * @author Michaell Reis
   * @date 02/19/2018
   * @description Builds a SOAP string prefix, by cleaning the namespace and type info, and setting the raw text last
   * @param String pVal, SOAP input string to clean
   * @return String Cleaned string
   */
  /* [--SOAP--]
    private static String cleanSoapPrefixFromRaw (String pVal)
    {
        return String.isBlank(pVal) ? ''
            : '<<Clean content:----->>\n'
                + (pVal.replaceAll('null','"null"')
                    .replaceAll(RE_CLEAN_SOAP, '')
                    .replaceAll('"null"','null')
                    .replaceAll(',}','}'))
                + '\n<<Raw info:----->>\n' + pVal;
    }*/
}
