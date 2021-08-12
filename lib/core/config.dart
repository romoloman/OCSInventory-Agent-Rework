import 'dart:io';

import 'package:ocs_agent/core/json_utils.dart';
import 'package:ocs_agent/core/files_utils.dart';

class Config{
  final String inventoryFilename = "config/inventory.json";
  final String coreFilename = "config/core.json";
  final String templateFilename = "config/template.json";

  JsonUtils jsonUtils;
  FilesUtils filesUtils;

  File inventory;
  File core;
  File template;

  Config() {
    this.jsonUtils = JsonUtils();
    this.filesUtils = FilesUtils();
    this.inventory = File(inventoryFilename);
    this.core = File(coreFilename);
    this.template = File(templateFilename);
  }

  String getInventoryConfigs(){
    return jsonUtils.getContentFromFile(inventory).toString();
  }

  String getInventoryConfig(String key){
    return jsonUtils.getContentFromFileByKey(inventory, key);
  }

  void updateInventoryConfig(String _index, String _value){
    String str = jsonUtils.setContentFromFile(inventory, _index, _value);
    filesUtils.rewriteFile(inventory, str);
  }

  String getCoreConfigs(){
    return jsonUtils.getContentFromFile(core).toString();
  }

  String getCoreConfig(String key){
    return jsonUtils.getContentFromFileByKey(core, key);
  }

  void updateCoreConfig(String _index, String _value){
    String str = jsonUtils.setContentFromFile(core, _index, _value);
    filesUtils.rewriteFile(core, str);
  }

  Map<String, dynamic> getTemplate(){
    return jsonUtils.getContentFromFile(template);
  }

  String getTemplateKey(String key){
    return jsonUtils.getContentFromFileByKey(template, key);
  }

  void updateTemplate(String _index, String _value){
    String str = jsonUtils.setContentFromFile(template, _index, _value);
    filesUtils.rewriteFile(template, str);
  }

  void setTemplate(String strTemplate){
    filesUtils.rewriteFile(template, strTemplate);
  }

}