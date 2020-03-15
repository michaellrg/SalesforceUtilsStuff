/**
* 
* @author           Michaell Reis 
* Project:          
* Description:      Class responsible to the Rest Connection
*
*
* Changes (Version)
* -------------------------------------
*           No.     Date            Author                  Description
*           -----   ----------      --------------------    ---------------
* @version  1.0     2020-01-02      Michaell Reis   	     Created Class
***************************************************************************************************/
public with sharing class JWTRestConnection {

    @testVisible private ServicioIntegracion__mdt servicio {set; get;}
    @testVisible private PathIntegracion__mdt path {set; get;}
    private AccessToken token { set; get {
		token = token == null || token.expirationTime <=  (dateTime.now().getTime()/1000)+1 ? this.getToken() : token;
		return token;
	}}
    public JWTRestConnection(String name, String namePath) {

         this.servicio = [SELECT ISS__c, IsMock__c, MockClass__c, Secret_Key__c, URLBase__c, MasterLabel FROM ServicioIntegracion__mdt WHERE MasterLabel =: name LIMIT 1];

         this.path = [SELECT PathURL__c, Method__c, Headers__c, MasterLabel FROM PathIntegracion__mdt WHERE MasterLabel =: namePath LIMIT 1];

    }
    public HttpResponse callService (Map <String, Map<String,String>> connSetting, String body){
        //this.+
        String endpoint = servicio.URLBase__c +path;
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
	request.setMethod(method);
        if(connSetting.containsKey('path')) {            
            for(String param : connSetting.get('path').keyset()) {
                endpoint=endpoint+'/'+connSetting.get('path').get(param);
            }
        }
        if(connSetting.containsKey('query')){
            Integer i = 0;
            endpoint +=!connSetting.get('query').isEmpty()?'?':'';
            for(String param : connSetting.get('query').keyset()) {
                endpoint += param + '=' +connSetting.get('query').get(param);
                endpoint += ++i == connSetting.get('query').size() ? '' : '&';

            }
        }
        if(connSetting.containsKey('header')){
            connSetting.get('header').putAll(fillMapHeader(path.Headers__c));
            for(String param : connSetting.get('header').keySet()) {
                if(param =='Authorization'){
                    System.debug('Authorization');
                    request.setHeader(param,'Bearer '+ token.accessToken);
                }else{
                    System.debug('others');
                    request.setHeader(param,connSetting.get('header').get(param));
                }
                System.debug('Param Header :'+param+' Value : '+connSetting.get('header').get(param));

            }
        }

        System.debug('Header ' +request);

        request.setBody(body);
        System.debug('Body '+request.getBody());
        HttpResponse response;

        try {
            MockRestInterface mockClass = String.isNotBlank(this.servicio.MockClass__c)  ?  (MockRestInterface) Type.forName(this.servicio.MockClass__c).newInstance() :null ;

	    response = this.servicio.IsMock__c && mockClass !=null ? (HttpResponse)mockClass.respond(request) : new Http().send(request);

	   if(response.getStatusCode() != 200) {
                System.debug('Code '+response.getStatusCode());

	   }

        } catch(CalloutException ex) {
            throw new ServiceException(ex.getMessage(), ex);

        } catch(JSONException ex) {
              throw new ServiceException(EN_Utility.cleanupErrors(ex));
        }

        return response;

        //return null;
    }
    private AccessToken getToken() {
        JWTAuthentication jw = new JWTAuthentication('HS256');
        jw.iss= this.servicio.ISS__C;
        jw.privateKey = this.servicio.Secret_Key__c;
            //jw.claims (Añadir Name)
        String key = jw.issue();
        System.debug('Key '+ key);
		AccessToken token = new AccessToken( key, jw.validFor);
        System.debug('Access Token '+token);
        return token;
	}




        public class TypeParam {
            public String nameType  {get; private set;}
            public Object value    {get; private set;}

            public TypeParam (String nameType, Object value) {
                this.nameType = nameType;
                this.value    = value;
            }
        }

        private class AccessToken {
		    public String  accessToken    {get; private set;}
		    public Long    expirationTime {get; private set;}

		    public AccessToken(String  accessToken, Integer expirationTime ) {

			    this.accessToken    = accessToken;
			    this.expirationTime = expirationTime;
		    }

		public override String toString() {
			return this.accessToken;
		}
	}

    public class ServiceException extends Exception {

	}
}
