public with sharing class TesteContinuation {
 // Unique label corresponding to the continuation
 public String requestLabel;
 public String requestLabel2;
    // Result of callout
    public String result {get;set;}
    public String Token {get;set;}
    
    // Callout endpoint as a named credential URL 
    // or, as shown here, as the long-running service URL
    private static final String LONG_RUNNING_SERVICE_URL = 
    'URL AccessToken';
    private static final String LONG_RUNNING_SERVICE_URL2= 
    'URL CALL';
    
   // Action method
   public Object startRequest() {
      // Create continuation with a timeout
      Continuation con = new Continuation(40);
      // Set callback method
      con.continuationMethod='processResponse';
      
      ObtemToken();
      // Add callout request to continuation
      
      if(String.isNotBlank(this.Token) && String.isNotEmpty(this.Token)){
      	this.requestLabel2=con.addHttpRequest(SegundaRequisicao());
      } 

      // Return the continuation
      return con;  
  }

    // Callback method 
    public Object processResponse() {   
    	try{  
    		if(String.isNotBlank(this.Token) && String.isNotEmpty(this.Token)){

      	// Get the response of the second request
      	HttpResponse response2 = Continuation.getResponse(this.requestLabel2);

      	this.result = response2.getBody();
      	
      }
      }catch(CalloutException ex){
      	ObtemToken();
      	processResponse();
      }
      

      // Return null to re-render the original Visualforce page
      return null;
  }

  public HttpRequest SegundaRequisicao(){
    		 // Create second callout request
    		 HttpRequest req2 = new HttpRequest();
    		 req2.setMethod('GET');
    		 req2.setHeader('client_id', 'ClientID');
    		 req2.setHeader('access_token', 
    		 	this.Token); 
    		 req2.setEndpoint(LONG_RUNNING_SERVICE_URL2);
    		 return req2;

    		}
    		public void ObtemToken(){
    	 // Create callout request
    	 HttpRequest req = new HttpRequest();
    	 req.setMethod('POST');
    	 req.setHeader('client_id', 'ClientID');
    	 req.setHeader('Authorization', 
    	 	'Authorization'); 
    	 req.setEndpoint(LONG_RUNNING_SERVICE_URL);
    	 HttpResponse response = new HttpResponse();
    	 response= new Http().send(req);
    	 AccessToken access = (AccessToken)JSON.deserialize(response.getBody(), AccessToken.class);
    	 this.Token = access.access_token;

    	}

    	public class AccessToken {
    		public String access_token {get; set;}

    		public AccessToken(String access_token){
    			this.access_token = access_token;
    		}
    	}

    }