/**
 * Classe utilitária responsável por fornecer informações sobre RecordTypes.
 * @author Caio Del Fava [Avanxo]
 */
global class RecordTypeUtils {

	//mensagens de erro das exceptions
	private static final String ERR_INVALID_RECORDTYPE_ID = 'Record type not found. Invalid id: {0}';
	private static final String ERR_INVALID_RECORDTYPE_NAME = 'Record type not found. Invalid name: {0}';
	private static final String ERR_INVALID_RECORDTYPE_DEVELOPERNAME = 'Record type not found. Invalid developer name: {0}';
	private static final String ERR_HAS_NO_RECORDTYPE = 'Record type not found. There is no record types defined for the sObject: {0}';

	//mapas de RecordTypeInfos
	private static final Map<Id, Schema.RecordTypeInfo> mapRecordTypeInfoByRecordTypeId;
	private static final Map<String, Map<String, Id>> mapRecordTypeIdBySObjectAndRecordTypeName;
	private static final Map<String, Map<String, Id>> mapRecordTypeIdBySObjectAndRecordTypeDeveloperName;

	//retorna sObjects carregados
	private static Set<String> sObjectsLoaded { get {
		return mapRecordTypeIdBySObjectAndRecordTypeName.keySet();
	}}

	//retorna sObjects carregados pelo developer name (carregodos por SOQL)
	private static Set<String> sObjectsLoadedByDeveloperName { get {
		return mapRecordTypeIdBySObjectAndRecordTypeDeveloperName.keySet();
	}}

	static {
		mapRecordTypeInfoByRecordTypeId = new Map<Id, Schema.RecordTypeInfo>();
		mapRecordTypeIdBySObjectAndRecordTypeName = new Map<String, Map<String, Id>>();
		mapRecordTypeIdBySObjectAndRecordTypeDeveloperName = new Map<String, Map<String, Id>>();
	}

	@TestVisible
	private RecordTypeUtils() {
	}

	/**
	 * Retorna uma lista com os ids dos tipos de registro baseado no nome do sObject e
	 * nos nomes dos tipos de registro, na ordem informada.
	 * Pode ser acessado externamente utilizando o Salesforce.com AJAX Toolkit.
	 * @param  sObjectName     Nome do sObject
	 * @param  recordTypeNames Lista de nomes do tipo de registro
	 * @return                 Lista de ids dos tipos de registro, na ordem informada
	 */
	webservice static List<Id> getRecordTypeIdsByName(String sObjectName, List<String> recordTypeNames) {

		List<Id> recordTypeIds = new List<Id>();
		
		for(String recordTypeName : recordTypeNames) {		
			Id recordTypeId = getRecordTypeIdByName(sObjectName, recordTypeName);
			recordTypeIds.add(recordTypeId);
		}

		return recordTypeIds;
	}

	/**
	 * Retorna uma lista com os ids dos tipos de registro baseado no nome do sObject e
	 * nos developer names dos tipos de registro, na ordem informada.
	 * Este método força a execução de um SOQL. É preferível buscar o record type pelo seu nome ou id.
	 * Pode ser acessado externamente utilizando o Salesforce.com AJAX Toolkit.
	 * @param  sObjectName    Nome do sObject
	 * @param  developerNames Lista de developer names dos tipos de registro
	 * @return                Lista de ids dos tipos de registro, na ordem informada
	 */
	webservice static List<Id> getRecordTypeIdsByDeveloperName(String sObjectName, List<String> developerNames) {

		List<Id> recordTypeIds = new List<Id>();

		for(String developerName : developerNames) {
			Id recordTypeId = getRecordTypeIdByDeveloperName(sObjectName, developerName);
			recordTypeIds.add(recordTypeId);
		}

		return recordTypeIds;
	}

	/**
	 * Retorna o id do tipo de registro baseado no nome do sObject e no nome do tipo de registro.
	 * Pode ser acessado externamente utilizando o Salesforce.com AJAX Toolkit.
	 * @param  sObjectName    Nome do sObject
	 * @param  recordTypeName Nome do tipo de registro
	 * @return                Id do tipo de registro
	 */
	webservice static Id getRecordTypeIdByName(String sObjectName, String recordTypeName) {
		
		RecordType recordType = getRecordTypeByName(sObjectName, recordTypeName);
		Id recordTypeId = recordType.Id;

		return recordTypeId;
	}

	/**
	 * Retorna o id do tipo de registro baseado no nome do sObject e no developer name do tipo de registro.
	 * Este método força a execução de um SOQL. É preferível buscar o record type pelo seu nome ou id.
	 * Pode ser acessado externamente utilizando o Salesforce.com AJAX Toolkit.
	 * @param  sObjectName   Nome do sObject
	 * @param  developerName Developer name do tipo de registro
	 * @return               RecordType
	 */
	webservice static Id getRecordTypeIdByDeveloperName(String sObjectName, String developerName) {
	
		RecordType recordType = getRecordTypeByDeveloperName(sObjectName, developerName);
		Id recordTypeId = recordType.Id;

		return recordTypeId;
	}

	/**
	 * Retorna um objeto RecordType baseado no nome do sObject e no id do tipo de registro.
	 * @param  sObjectName  Nome do sObject
	 * @param  recordTypeId Id do tipo de registro
	 * @return              RecordType
	 */
	public static RecordType getRecordTypeById(String sObjectName, Id recordTypeId) {

		Schema.RecordTypeInfo recordTypeInfo = getRecordTypeInfoById(sObjectName, recordTypeId);
		RecordType recordType = getRecordType(sObjectName, recordTypeInfo);

		return recordType;
	}

	/**
	 * Retorna um objeto RecordType baseado no nome do sObject e no nome do tipo de registro.
	 * @param  sObjectName    Nome do sObject
	 * @param  recordTypeName Nome do tipo de registro
	 * @return                RecordType
	 */
	public static RecordType getRecordTypeByName(String sObjectName, String recordTypeName) {
		RecordType recordType;
		Schema.RecordTypeInfo recordTypeInfo;
		try{
			recordTypeInfo = getRecordTypeInfoByName(sObjectName, recordTypeName);
			recordType = getRecordType(sObjectName, recordTypeInfo);	
		}
		catch(NullPointerException e) {
			if(recordTypeInfo == null) {
				throw new RecordTypeUtilsException(StringUtils.format(ERR_INVALID_RECORDTYPE_NAME, recordTypeName));
			}
		}
			
		return recordType;
	}

	/**
	 * Retorna um objeto RecordType baseado no nome do sObject e no developer name do tipo de registro.
	 * Este método força a execução de um SOQL. É preferível buscar o record type pelo seu nome ou id.
	 * @param  sObjectName   Nome do sObject
	 * @param  developerName Developer name do tipo de registro
	 * @return               RecordType
	 */
	public static RecordType getRecordTypeByDeveloperName(String sObjectName, String developerName) {

		Schema.RecordTypeInfo recordTypeInfo = getRecordTypeInfoByDeveloperName(sObjectName, developerName);
		RecordType recordType = getRecordType(sObjectName, recordTypeInfo, developerName);

		return recordType;
	}

	/**
	 * Retorna um objeto RecordType populado baseado em um RecordTypeInfo.
	 * @param  sObjectName    Nome do sObject
	 * @param  recordTypeInfo RecordTypeInfo do tipo de registro
	 * @return                RecordType
	 */
	private static RecordType getRecordType(String sObjectName, Schema.RecordTypeInfo recordTypeInfo) {

		RecordType recordType = new RecordType(
			Id = recordTypeInfo.getRecordTypeId(),
			Name = recordTypeInfo.getName(),
			SobjectType = sObjectName
		);

		return recordType;
	}

	/**
	 * Retorna um objeto RecordType populado baseado em um RecordTypeInfo e seu developer name.
	 * @param  sObjectName    Nome do sObject
	 * @param  recordTypeInfo RecordTypeInfo do tipo de registro
	 * @param  developerName  Developer name do tipo de registro
	 * @return                RecordType
	 */
	private static RecordType getRecordType(String sObjectName, Schema.RecordTypeInfo recordTypeInfo, String developerName) {

		RecordType recordType = getRecordType(sObjectName, recordTypeInfo);
		recordType.DeveloperName = developerName;

		return recordType;
	}

	/**
	 * Retorna um objeto RecordTypeInfo baseado no nome do sObject e no id do tipo de registro.
	 * @param  sObjectName  Nome do sObject
	 * @param  recordTypeId Id do tipo de registro
	 * @return              RecordTypeInfo
	 */
	public static Schema.RecordTypeInfo getRecordTypeInfoById(String sObjectName, Id recordTypeId) {

		Schema.RecordTypeInfo recordTypeInfo;

		recordTypeInfo = mapRecordTypeInfoByRecordTypeId.get(recordTypeId);

		if(recordTypeInfo == null) {
			loadRecordTypeInfos(sObjectName);
			recordTypeInfo = mapRecordTypeInfoByRecordTypeId.get(recordTypeId);

			if(recordTypeInfo == null) {
				throw new RecordTypeUtilsException(StringUtils.format(ERR_INVALID_RECORDTYPE_ID, recordTypeId));
			}
		}

		return recordTypeInfo;
	}

	/**
	 * Retorna um objeto RecordTypeInfo baseado no nome do sObject e no nome do tipo de registro.
	 * @param  sObjectName    Nome do sObject
	 * @param  recordTypeName Nome do tipo de registro
	 * @return                RecordTypeInfo
	 */
	public static Schema.RecordTypeInfo getRecordTypeInfoByName(String sObjectName, String recordTypeName) {

		Schema.RecordTypeInfo recordTypeInfo;

		try {
			Id recordTypeId = mapRecordTypeIdBySObjectAndRecordTypeName.get(sObjectName).get(recordTypeName);
			recordTypeInfo = mapRecordTypeInfoByRecordTypeId.get(recordTypeId);
		}
		catch(NullPointerException e) {	
			loadRecordTypeInfos(sObjectName);
			recordTypeInfo = getRecordTypeInfoByName(sObjectName, recordTypeName);
			if(recordTypeInfo == null) {
				throw new RecordTypeUtilsException(StringUtils.format(ERR_INVALID_RECORDTYPE_NAME, recordTypeName));
			}						
		}

		return recordTypeInfo;
	}

	/**
	 * Retorna um objeto RecordTypeInfo baseado no nome do sObject e no developer name do tipo de registro.
	 * Este método força a execução de um SOQL. É preferível buscar o record type pelo seu nome ou id.
	 * @param  sObjectName   Nome do sObject
	 * @param  developerName Developer name do tipo de registro
	 * @return               RecordTypeInfo
	 */
	public static Schema.RecordTypeInfo getRecordTypeInfoByDeveloperName(String sObjectName, String developerName) {

		Schema.RecordTypeInfo recordTypeInfo;

		try {
			Id recordTypeId = mapRecordTypeIdBySObjectAndRecordTypeDeveloperName.get(sObjectName).get(developerName);
			recordTypeInfo = mapRecordTypeInfoByRecordTypeId.get(recordTypeId);
		}
		catch(NullPointerException e) {
			loadRecordTypeInfos(sObjectName);
			loadRecordTypeIdsByDeveloperName(sObjectName);
			recordTypeInfo = getRecordTypeInfoByDeveloperName(sObjectName, developerName);

			if(recordTypeInfo == null) {
				throw new RecordTypeUtilsException(StringUtils.format(ERR_INVALID_RECORDTYPE_DEVELOPERNAME, developerName));
			}
		}

		return recordTypeInfo;
	}

	/**
	 * Carrega todos os RecordTypeInfos de um sObject.
	 * @param sObjectName Nome do sObject
	 */
	private static void loadRecordTypeInfos(String sObjectName) {

		Schema.DescribeSObjectResult sObjectDescribe = SObjectUtils.getSObjectDescribe(sObjectName);

		loadRecordTypeInfosById(sObjectDescribe);
		loadRecordTypeIdsByName(sObjectDescribe);
	}

	/**
	 * Carrega todos os RecordTypeInfos de um sObject em um mapa cuja chave é o id do tipo de registro.
	 * @param sObjectDescribe Describe do sObject
	 */
	private static void loadRecordTypeInfosById(Schema.DescribeSObjectResult sObjectDescribe) {
		mapRecordTypeInfoByRecordTypeId.putAll(sObjectDescribe.getRecordTypeInfosById());
	}

	/**
	 * Carrega todos os ids de RecordTypes de um sObject em um mapa cuja a chave é o nome do tipo de registro.
	 * @param sObjectDescribe Describe do sObject
	 */
	private static void loadRecordTypeIdsByName(Schema.DescribeSObjectResult sObjectDescribe) {

		Map<String, Id> recordTypeIdsByName = new Map<String, Id>();

		for(Schema.RecordTypeInfo recordTypeInfo : sObjectDescribe.getRecordTypeInfos()) {
			recordTypeIdsByName.put(recordTypeInfo.getName(), recordTypeInfo.getRecordTypeId());
		}

		mapRecordTypeIdBySObjectAndRecordTypeName.put(sObjectDescribe.getName(), recordTypeIdsByName);
	}

	/**
	 * Carrega todos os ids de RecordTypes dos sObjects até então carregados em um mapa cuja a chave é o developer name do tipo de registro.
	 * Este método força a execução de um SOQL. É preferível buscar o record type pelo seu nome ou id.
	 */
	private static void loadRecordTypeIdsByDeveloperName(String sObjectName) {

		Set<String> sObjectsToQuery = new Set<String>(sObjectsLoaded);
		sObjectsToQuery.removeAll(sObjectsLoadedByDeveloperName);

		if(!sObjectsToQuery.isEmpty()) {

			List<RecordType> recordTypes = [
				SELECT Id, SobjectType, DeveloperName FROM RecordType
				 WHERE SobjectType IN :sObjectsToQuery
			];

			if(recordTypes.isEmpty()) {
				throw new RecordTypeUtilsException(StringUtils.format(ERR_HAS_NO_RECORDTYPE, sObjectName));
			}

			for(RecordType recordType : recordTypes) {

				Map<String, Id> recordTypeIdsByDeveloperName =
					mapRecordTypeIdBySObjectAndRecordTypeDeveloperName.get(recordType.SobjectType);

				if(recordTypeIdsByDeveloperName == null) {
					recordTypeIdsByDeveloperName = new Map<String, Id>();
					mapRecordTypeIdBySObjectAndRecordTypeDeveloperName.put(recordType.SobjectType, recordTypeIdsByDeveloperName);
				}

				recordTypeIdsByDeveloperName.put(recordType.DeveloperName, recordType.Id);
			}
		}
	}
}