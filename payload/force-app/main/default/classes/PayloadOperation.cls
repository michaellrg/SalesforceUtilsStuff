/**
 * @File Name:   PayloadOperation.cls
 * @Description: Payload Operation Class
 * @Author:      Michaell Reis
 * @Email:       michaellrg@gmail.com
 * @Project:     Salesforce Utils
 * @Group:       Apex
 * @Last Modified by:   Michaell Reis
 * @Last Modified time: 2017-09-07 16:53:02
 * @Modification Log :
 *-------------------------------------------------------------------------------------
 * Ver       Date        Author           Modification
 * 1.0       2017-05-13  Michaell Reis         Created the file/class
 * 2.0       2017-06-14  Michaell Reis         Added Timeout
 * 2.1       2017-06-16  Michaell Reis         Added FormatURL
 * 3.0       2026-09-30  Michaell Reis         Adapted for Salesforce Utils
 */
public without sharing class PayloadOperation { //without sharing is needed to query object/fields the user may not have access ex
  private static final String SFDC_LOOPURL;
  private static Map<String, PayloadOperation> Operations;

  static {
    SFDC_LOOPURL = 'my.salesforce.com';
    Operations = new Map<String, PayloadOperation>();
  }

  public Id Id { get; private set; }

  public Boolean Active { get; private set; }
  public String Direction { get; private set; }
  public String ResponseMode { get; private set; }
  public Boolean FormatURL { get; private set; }
  public Integer Timeout { get; private set; }
  public String Certificate { get; private set; }
  public String Name { get; private set; }
  public String URLBase { get; private set; }
  public String URLPath { get; set; }
  public String HttpMethod { get; private set; }
  public String SourceId { get; set; }
  public Boolean Mock { get; private set; }
  public String MockClass { get; private set; }

  public Boolean isSFDCLoopback {
    get {
      return (null != this.URLBase) &&
        this.URLBase.containsIgnoreCase(SFDC_LOOPURL);
    }
  }

  public Map<String, String> HttpHeaders { get; private set; }
  private String headers { get; set; }

  private PayloadOperation() {
  }

  /**
   * @Name          getByName
   * @Description   Get Operation By Name
   * @Author        Michaell Reis
   * @CreatedDate   2017-05-13
   * @Param         String name
   * @Return        PayloadOperation
   */
  public static PayloadOperation getByName(String name) {
    name = name == null ? null : name.trim();
    if (String.isBlank(name)) {
      throw new PayloadOperationException(
        'Invalid input - unable to instantiate payload operation'
      );
    }

    if (Operations.containsKey(name)) {
      return Operations.get(name);
    }

    List<Payload_Operation__c> ops = [
      SELECT
        Id,
        Name,
        Active__c,
        Direction__c,
        Response_Mode__c,
        Certificate_Name__c,
        URL_Format__c,
        Http_Method__c,
        Http_Headers__c,
        URL_Base__c,
        URL_Path__c,
        Http_Timeout__c,
        Is_Mock__c,
        Mock_Class__c
      FROM Payload_Operation__c
      WHERE Name = :name
      LIMIT 1
    ];

    if (ops.isEmpty())
      throw new PayloadOperationException(
        'Missing definition for the requested operation - ' + name
      );
    else if (ops.size() == 1) {
      PayloadOperation operation = new PayloadOperation();
      operation.Name = ops[0].Name;
      operation.Id = ops[0].Id;
      operation.Active = ops[0].Active__c;
      operation.Direction = String.isBlank(ops[0].Direction__c)
        ? 'Both'
        : ops[0].Direction__c;
      operation.ResponseMode = String.isBlank(ops[0].Response_Mode__c)
        ? 'Ignore'
        : ops[0].Response_Mode__c;
      operation.Certificate = ops[0].Certificate_Name__c;
      operation.FormatURL = ops[0].URL_Format__c;
      operation.HttpMethod = ops[0].Http_Method__c;
      operation.headers = ops[0].Http_Headers__c;
      operation.URLBase = String.isBlank(ops[0].URL_Base__c)
        ? ''
        : ops[0].URL_Base__c;
      operation.URLPath = String.isBlank(ops[0].URL_Path__c)
        ? ''
        : ops[0].URL_Path__c;
      operation.Timeout = Integer.valueof(ops[0].Http_Timeout__c);
      operation.Mock = ops[0].Is_Mock__c;
      operation.MockClass = ops[0].Mock_Class__c;

      try {
        if (String.isNotBlank(operation.headers)) {
          operation.HttpHeaders = new Map<String, String>();

          for (String l : operation.headers.split('\r\n|\n|\r')) {
            if (String.isNotBlank(l)) {
              String[] nameValues = l.trim().split(':');
              operation.HttpHeaders.put(
                nameValues[0].trim(),
                nameValues[1].trim()
              );
            }
          }
        }
      } catch (Exception e) {
        throw new PayloadOperationException('Corrupted Http Header values');
      }

      Operations.put(name, operation);
      return operation;
    }
    return null;
  }

  /**
   * @Name          getEndpoint
   * @Description   Get endpoint
   * @Author        Michaell Reis
   * @CreatedDate   2017-06-16
   * @Param         List<String> endpointFormat
   * @Return        String
   */
  public String getEndpoint(List<String> endpointFormat) {
    String endpoint = this.URLBase + this.URLPath;
    if (this.FormatURL && endpointFormat != null && !endpointFormat.isEmpty()) {
      endpoint = String.format(endpoint, endpointFormat);
    }

    return endpoint;
  }

  public class PayloadOperationException extends Exception {
  }
}
