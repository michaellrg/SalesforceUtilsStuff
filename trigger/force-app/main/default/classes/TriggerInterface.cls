/**
 * @File Name    :   TriggerInterface
 * @Description  :   Trigger Interface
 * @Date Created :   2017-05-09
 * @Author       :   Michaell Reis
 * @Email        :   michaellrg@gmail.com
 * @Project      :   Salesforce Utils
 * @group        :   Interface
 * @Modification Log:
 **************************************************************************************
 * Ver       Date        Author              Modification
 * 1.0       2017-05-09  Michaell Reis            Craeted the file/class
 * 2.0       2026-09-30  Michaell Reis         Adapted for Salesforce Utils
 **/
public interface TriggerInterface {
  void bulkBefore();
  void bulkAfter();
  void andFinally();

  void beforeInsert();
  void beforeUpdate();
  void beforeDelete();

  void afterInsert();
  void afterUpdate();
  void afterDelete();
  void afterUndelete();

  void execute();
}
