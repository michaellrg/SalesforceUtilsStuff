/**
 * @author Michaell Reis
 * @date 12/01/2017
 * @description Salesforce Utils transport helper for REST and SOAP callouts
 * @contact michaellrg@gmail.com
 *                   NOTE - SOAP : If needed, uncomment all the [--SOAP--]>> lines/sections
 *                   NOTE - SOAP : If needed, uncomment all the [--SOAP--]>> lines/sections
 * <p>
 * Test Class: PayloadGenerator_Test
 * V1.0 -> 12/01/2017, Michaell Reis, Initial Commit + raw JSON support
 * V1.5 -> 01/12/2018, Michaell Reis, Refactoring
 * V2.0 -> 02/14/2018, Michaell Reis, Basic SOAP hooks
 * V2.1 -> 03/03/2018, Michaell Reis, HTTP Certificate usage
 * V3.0 -> 2026-09-30, Michaell Reis, Salesforce Utils adaptation
 */
global with sharing class TransmitUtils {
  public static final List<PayloadTransaction> TRANSACTIONS;
  private static final List<Integer> HTTP_OK = new List<Integer>{
    200,
    201,
    204
  };
  public static String SFSESSION;

  static {
    TRANSACTIONS = new List<PayloadTransaction>();

    SFSESSION = UserInfo.getSessionId();
  }

  public static void setSFSession(String pSession) {
    SFSESSION = String.isBlank(pSession) ? SFSESSION : pSession;
  }
  private static String getSFAuth() {
    return 'Bearer ' + SFSESSION;
  }

  /**
   * @author Michaell Reis
   * @date 02/14/2018
   * @description PayloadTransaction class encapsulation for both protocols
   */
  global class PayloadTransaction {
    public HttpRequest request = new HttpRequest();
    public HTTPResponse response = new HTTPResponse();

    PayloadGenerator.SOAPObjectRequest soapRequest;
    String soapSource;
    Object soapResponse;

    public PayloadOperation ops;
    public Exception err;
    public PayloadResponseProcessor.ResponseResult responseResult;

    public Boolean isOk {
      get {
        return (HTTP_OK.contains(statusCode));
      }
    }
    public Boolean isGet {
      get {
        return null != this.ops && 'GET' == this.ops.HttpMethod;
      }
    }
    public Boolean isSoap {
      get {
        return null != this.soapRequest;
      }
    }

    public Boolean hasException {
      get {
        return null != this.err;
      }
    }
    public Integer statusCode {
      get {
        return this.response.getStatusCode();
      }
    }
    public String detailInfo {
      get {
        return String.valueOf(this.response.getStatusCode()) +
          ' :: ' +
          this.textResponse;
      }
    }
    public String textResponse {
      get {
        return this.hasException
          ? 'Error: ' + this.err.getMessage()
          : (this.isSoap
              ? JSON.serialize(this.soapResponse)
              : this.response.getBody());
      }
    }
    public Boolean isMock {
      get {
        return this.ops.Mock;
      }
    }
    public String mockClass {
      get {
        return this.ops.MockClass;
      }
    }

    /**
     * @author Michaell Reis
     * @date 02/14/2018
     * @description Manage the HTTP request headers based on the current context
     * @param Map<String,String> headers, extra headers to consider
     */
    public void manageHeaders(Map<String, String> headers) {
      if (this.ops.isSFDCLoopback)
        this.request.setHeader('Authorization', getSFAuth());

      if (this.ops.HttpHeaders != null) {
        for (String v : this.ops.HttpHeaders.keySet())
          this.request.setHeader(v, this.ops.HttpHeaders.get(v));
      }
      if (headers != null) {
        for (String v : headers.keySet())
          this.request.setHeader(v, headers.get(v));
      }
    }

    /**
     * @author Michaell Reis
     * @date 02/14/2018
     * @description Prepare the HTTP request based on the current context
     * @param List<String> endpointFormat, HTTP endpoint format values to use
     */
    public void prepareRequest(List<String> endpointFormat) {
      this.request.setTimeout(this.ops.Timeout);
      this.request.setMethod(this.ops.HttpMethod);
      this.request.setEndpoint(this.ops.getEndpoint(endpointFormat));

      if (String.isNotBlank(this.ops.Certificate))
        this.request.setClientCertificateName(this.ops.Certificate);
    }

    /**
     * @author Michaell Reis
     * @date 02/19/2018
     * @description Build the proper lod entry contextual to this transaction
     * @return PayloadLog, Log associated to this transaction
     */
    public PayloadLog generateLog() {
      return new PayloadLog(this.ops, this.request, this.response, this.err);
      // [--SOAP--]>> return (this.isSoap
      // [--SOAP--]>>     ? new PayloadLog(this.ops, this.soapRequest, this.soapResponse, this.err, this.soapSource)
      // [--SOAP--]>>     : new PayloadLog(this.ops, this.request, this.response, this.err)
      // [--SOAP--]>> );
    }
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Persists past TRANSACTIONS - used to perform DMLs after multiple API calls done via [getTransmit*] APIs
   */
  global static void persistTransmitResponses() {
    for (PayloadTransaction trx : TransmitUtils.TRANSACTIONS) {
      trx.generateLog().push();
      System.debug('TRX ' + trx);
    }
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Two API signatures : REST transmissions
   * @param PayloadGenerator.ObjectNode objNode, Object Node instance to use for mappings
   * @param String opsName, Payload operation name to use
   * @param Map<String,String> headers, HTTP headers to use
   * @param List<String> endpointFormat, HTTP endpoint format values to use
   * @return Log__c, Log entry that was persisted
   */
  global static Log__c transmit(
    PayloadGenerator.ObjectNode objNode,
    String opsName
  ) {
    return TransmitUtils.transmit(objNode, opsName, null, null);
  }
  global static Log__c transmit(
    PayloadGenerator.ObjectNode objNode,
    String opsName,
    Map<String, String> headers,
    List<String> endpointFormat
  ) {
    return TransmitUtils.performTransmit(
        objNode,
        opsName,
        headers,
        endpointFormat
      )
      .generateLog()
      .push();
  }

  /**
   * @author Michaell Reis
   * @date 01/12/2018
   * @description Provides the transmission text response wihtout persisting a log - Use [persistTransmitResponses] to perform the DMLs
   * @param PayloadGenerator.ObjectNode objNode, Object Node instance to use for mappings
   * @param String opsName, Payload operation name to use
   * @param Map<String,String> headers, HTTP headers to use
   * @param List<String> endpointFormat, HTTP endpoint format values to use
   * @return String, Transmission response
   */
  global static String getTransmitResponse(
    PayloadGenerator.ObjectNode objNode,
    String opsName,
    Map<String, String> headers,
    List<String> endpointFormat
  ) {
    PayloadTransaction trx = performTransmit(
      objNode,
      opsName,
      headers,
      endpointFormat
    );
    TransmitUtils.TRANSACTIONS.add(trx);
    return trx.textResponse;
  }

  /**
   * @author Michaell Reis
   * @date 01/12/2018
   * @description Provides the transmission object response wihtout persisting a log - Use [persistTransmitResponses] to perform the DMLs
   * @param PayloadGenerator.ObjectNode objNode, Object Node instance to use for mappings
   * @param String opsName, Payload operation name to use
   * @param Map<String,String> headers, HTTP headers to use
   * @param List<String> endpointFormat, HTTP endpoint format values to use
   * @return HttpResponse, Transmission response
   */
  global static HttpResponse getTransmitHttpResponse(
    PayloadGenerator.ObjectNode objNode,
    String opsName,
    Map<String, String> headers,
    List<String> endpointFormat
  ) {
    return getTransmitTransaction(objNode, opsName, headers, endpointFormat)
      .response;
  }
  global static PayloadTransaction getTransmitTransaction(
    PayloadGenerator.ObjectNode objNode,
    String opsName,
    Map<String, String> headers,
    List<String> endpointFormat
  ) {
    PayloadTransaction trx = performTransmit(
      objNode,
      opsName,
      headers,
      endpointFormat
    );
    TransmitUtils.TRANSACTIONS.add(trx);
    return trx;
  }

  /**
   * @author Michaell Reis
   * @date 12/01/2017
   * @description Performs HTTP REST protocol transmissions
   * @param PayloadGenerator.ObjectNode objNode, Object Node instance to use for mappings
   * @param String opsName, Payload operation name to use
   * @param Map<String,String> headers, HTTP headers to use
   * @param List<String> endpointFormat, HTTP endpoint format values to use
   * @return PayloadTransaction, Transaction structure containing details of a transmission
   */
  global static PayloadTransaction performTransmit(
    PayloadGenerator.ObjectNode objNode,
    String opsName,
    Map<String, String> headers,
    List<String> endpointFormat
  ) {
    PayloadTransaction trx = new PayloadTransaction();

    try {
      trx.ops = PayloadOperation.getByName(opsName);
      System.debug('OPERATION ' + trx.ops);

      if (objNode != null)
        trx.ops.SourceId = objNode.ObjectId;

      String jsonData = null == objNode
        ? null
        : PayloadGenerator.Serialize(objNode, opsName, trx.ops.HttpMethod);

      trx.manageHeaders(headers);
      trx.prepareRequest(endpointFormat);

      // -- Don't set a body in the context of a GET
      if (!trx.isGet && null != jsonData)
        trx.request.setbody(jsonData);

      HttpCalloutMock mockClass = String.isNotBlank(trx.ops.MockClass)
        ? (HttpCalloutMock) Type.forName(trx.ops.MockClass).newInstance()
        : null;
      System.debug('MOCK CLASS ' + mockClass);
      trx.response = trx.ops.Mock && mockClass != null
        ? (HttpResponse) mockClass.respond(trx.request)
        : new Http().send(trx.request);
      System.debug('MOCK RESPONSE ' + trx.response.getBody());
      processConfiguredResponse(trx);
    } catch (exception e) {
      trx.err = e;
      System.debug(e.getMessage() + ' - ' + e.getStackTraceString());
    }
    TransmitUtils.TRANSACTIONS.add(trx);
    return trx;
  }
  global static PayloadTransaction performTransmit(
    PayloadGenerator.ObjectNode objNode,
    String opsName,
    Map<String, String> headers,
    List<String> endpointFormat,
    String body
  ) {
    PayloadTransaction trx = new PayloadTransaction();
    try {
      trx.ops = PayloadOperation.getByName(opsName);

      if (objNode != null)
        trx.ops.SourceId = objNode.ObjectId;

      String jsonData = null == objNode
        ? null
        : PayloadGenerator.Serialize(objNode, opsName, trx.ops.HttpMethod);

      trx.manageHeaders(headers);
      trx.prepareRequest(endpointFormat);

      // -- Don't set a body in the context of a GET
      if (!trx.isGet && null != body)
        trx.request.setbody(body);

      HttpCalloutMock mockClass = String.isNotBlank(trx.ops.MockClass)
        ? (HttpCalloutMock) Type.forName(trx.ops.MockClass).newInstance()
        : null;
      System.debug('MOCK CLASS ' + mockClass);
      trx.response = trx.ops.Mock && mockClass != null
        ? (HttpResponse) mockClass.respond(trx.request)
        : new Http().send(trx.request);
      processConfiguredResponse(trx);
    } catch (exception e) {
      trx.err = e;
      System.debug(e.getMessage() + ' - ' + e.getStackTraceString());
    }
    TransmitUtils.TRANSACTIONS.add(trx);
    return trx;
  }

  private static void processConfiguredResponse(PayloadTransaction trx) {
    if (
      trx.ops != null &&
      trx.response != null &&
      trx.isOk &&
      trx.ops.ResponseMode != 'Ignore' &&
      String.isNotBlank(trx.response.getBody())
    ) {
      trx.responseResult = PayloadResponseProcessor.process(
        trx.ops.Name,
        trx.response.getBody()
      );
    }
  }
  /**
   * @author Michaell Reis
   * @date 02/14/2018
   * @description SOAP transmissions : 2 APIs
   * @param String pOpName, Payload operation name to use
   * @param PayloadGenerator.SOAPObjectStub pStub, SOAP Stub sub-class from WSDL2Apex code generation
   * @param PayloadGenerator.SOAPObjectRequest pRequest, SOAP Request sub-class from WSDL2Apex code generation
   * @param Map<String, Object> pResp, SOAP WebServiceCallout response handling structure
   * @param String[] pInfoArray,  SOAP WebServiceCallout external service callout elements
   * @param String pSrcData, (Optional) source data that was used to build the pRequest parameter
   * @return Log__c, Log entry that was persisted
   */
  /* [--SOAP--]
    global static Log__c transmit(String pOpName, PayloadGenerator.SOAPObjectStub pStub, PayloadGenerator.SOAPObjectRequest pRequest, Map<String, Object> pResp, String[] pInfoArray)
    {
        return transmit(pOpName, pStub, pRequest, pResp, pInfoArray, null);
    }
    global static Log__c transmit(String pOpName, PayloadGenerator.SOAPObjectStub pStub, PayloadGenerator.SOAPObjectRequest pRequest, Map<String, Object> pResp, String[] pInfoArray, String pSrcData)
    {
        return TransmitUtils.performTransmit(pOpName, pStub, pRequest, pResp, pInfoArray, pSrcData)
            .generateLog()
            .push();
    } */

  /**
   * @author Michaell Reis
   * @date 02/14/2018
   * @description Provides the transmission text response wihtout persisting a log - Use [persistTransmitResponses] to perform the DMLs
   * @param String pOpName, Payload operation name to use
   * @param PayloadGenerator.SOAPObjectStub pStub, SOAP Stub sub-class from WSDL2Apex code generation
   * @param PayloadGenerator.SOAPObjectRequest pRequest, SOAP Request sub-class from WSDL2Apex code generation
   * @param Map<String, Object> pResp, SOAP WebServiceCallout response handling structure
   * @param String[] pInfoArray,  SOAP WebServiceCallout external service callout elements
   * @param String pSrcData, (Optional) source data that was used to build the pRequest parameter
   * @return String, Transmission response
   */
  /* [--SOAP--]
    global static Object getTransmitResponse(String pOpName, PayloadGenerator.SOAPObjectStub pStub, PayloadGenerator.SOAPObjectRequest pRequest, Map<String, Object> pResp, String[] pInfoArray)
    {
        return getTransmitResponse(pOpName, pStub, pRequest, pResp, pInfoArray, null);
    }
    global static Object getTransmitResponse(String pOpName, PayloadGenerator.SOAPObjectStub pStub, PayloadGenerator.SOAPObjectRequest pRequest, Map<String, Object> pResp, String[] pInfoArray, String pSrcData)
    {
        PayloadTransaction trx = performTransmit(pOpName, pStub, pRequest, pResp, pInfoArray, pSrcData);
        TransmitUtils.TRANSACTIONS.add(trx);
        return trx.soapResponse;
    }*/

  /**
   * @author Michaell Reis
   * @date 02/14/2018
   * @description Performs HTTP SOAP protocol transmissions
   * @param String pOpName, Payload operation name to use
   * @param PayloadGenerator.SOAPObjectStub pStub, SOAP Stub sub-class from WSDL2Apex code generation
   * @param PayloadGenerator.SOAPObjectRequest pRequest, SOAP Request sub-class from WSDL2Apex code generation
   * @param Map<String, Object> pResp, SOAP WebServiceCallout response handling structure
   * @param String[] pInfoArray,  SOAP WebServiceCallout external service callout elements
   * @param String pSrcData, (Optional) source data that was used to build the pRequest parameter
   * @return PayloadTransaction, Transaction structure containing details of a transmission
   */
  /* [--SOAP--]
    global static PayloadTransaction performTransmit(String pOpName, PayloadGenerator.SOAPObjectStub pStub, PayloadGenerator.SOAPObjectRequest pRequest, Map<String, Object> pResp, String[] pInfoArray, String pSrcData)
    {
        PayloadTransaction trx = new PayloadTransaction();

        try
        {
            trx.ops         = PayloadOperation.getByName(pOpName);
            trx.soapSource  = String.isBlank(pSrcData) ? '' : pSrcData;
            trx.soapRequest = pRequest;

            if (null != trx.ops)
            {
                trx.ops.SourceId = UserInfo.getUserId();

                // -- Use endpoint from the PayloadOperation
                List<String> infoArray = new List<String>(pInfoArray);
                infoArray[0] = trx.ops.getEndpoint(null);

                WebServiceCallout.invoke(pStub, pRequest, pResp, infoArray);

                trx.soapResponse = pResp.get('response_x');
            }
        }
        catch(exception e)
        {
            trx.err = e;
            System.debug(e.getMessage() + ' - ' + e.getStackTraceString());
        }
        return trx;
    }*/
}
