@IsTest
private class PayloadLogFrameworkTest {
  @IsTest
  static void capturesRestRequestAndResponse() {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.test/resource');
    request.setMethod('POST');
    request.setBody('{"request":true}');

    HttpResponse response = new HttpResponse();
    response.setStatusCode(200);
    response.setBody('{"success":true}');

    PayloadLog logEntry = new PayloadLog(null, request, response, null);

    System.assertEquals('POST', logEntry.HTTPMethod);
    System.assertEquals('https://example.test/resource', logEntry.Endpoint);
    System.assertEquals('{"request":true}', logEntry.OutgoingJSONPayload);
    System.assertEquals('{"success":true}', logEntry.IncomingJSONPayload);
    System.assertEquals('Success', logEntry.Status);
    System.assertEquals(200, logEntry.StatusCode);
  }
}
