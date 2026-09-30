/**
 * @description Runtime view of optional object-level Trigger framework settings.
 * @author Michaell Reis
 * @contact michaellrg@gmail.com
 */
public with sharing class TriggerObjectConfig {
  private static Map<String, TriggerObjectConfig> cache;

  public String SObjectName { get; private set; }
  public Boolean IsActive { get; private set; }

  private TriggerObjectConfig(TriggerObjectConfig__mdt metadata) {
    this.SObjectName = metadata.SObject__c;
    this.IsActive = metadata.Active__c;
  }

  public static TriggerObjectConfig getBySObjectType(Schema.SObjectType type) {
    if (type == null) {
      return null;
    }
    return getBySObjectName(type.getDescribe().getName());
  }

  public static TriggerObjectConfig getBySObjectName(String name) {
    if (String.isBlank(name)) {
      return null;
    }
    if (cache == null) {
      cache = new Map<String, TriggerObjectConfig>();
      for (TriggerObjectConfig__mdt metadata : TriggerObjectConfig__mdt.getAll().values()) {
        if (String.isNotBlank(metadata.SObject__c)) {
          cache.put(metadata.SObject__c.toLowerCase(), new TriggerObjectConfig(metadata));
        }
      }
    }
    return cache.get(name.toLowerCase());
  }

  @TestVisible
  static void clearCache() {
    cache = null;
  }
}
