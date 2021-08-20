import 'dart:io';

import 'package:ocs_agent/core/json_utils.dart';
import 'package:ocs_agent/core/files_utils.dart';

/// Class to get config in config folder.
class Config{
  final String inventoryFilename = "config/inventory.json";
  final String coreFilename = "config/core.json";
  final String templateFilename = "config/template.json";

  JsonUtils jsonUtils;
  FilesUtils filesUtils;

  File inventory;
  File core;
  File template;

  /// Constructor.
  Config() {
    this.jsonUtils = JsonUtils();
    this.filesUtils = FilesUtils();
    this.inventory = File(inventoryFilename);
    this.core = File(coreFilename);
    this.template = File(templateFilename);
  }

  /// Return all content in inventory config file.
  String getInventoryConfigs(){
    return jsonUtils.getContentFromFile(inventory).toString();
  }

  /// return [key] content in inventory file.
  String getInventoryConfig(String key){
    return jsonUtils.getContentFromFileByKey(inventory, key);
  }

  /// Update inventory config file by [_index] and [_value].
  void updateInventoryConfig(String _index, String _value){
    String str = jsonUtils.setContentFromFile(inventory, _index, _value);
    filesUtils.rewriteFile(inventory, str);
  }

  /// Return all content in core config file.
  String getCoreConfigs(){
    return jsonUtils.getContentFromFile(core).toString();
  }

  /// return [key] content in core file.
  String getCoreConfig(String key){
    return jsonUtils.getContentFromFileByKey(core, key);
  }

  /// Update core config file by [_index] and [_value].
  void updateCoreConfig(String _index, String _value){
    String str = jsonUtils.setContentFromFile(core, _index, _value);
    filesUtils.rewriteFile(core, str);
  }

  /// return template file in json format.
  Map<String, dynamic> getTemplate(){
    return jsonUtils.getContentFromFile(template);
  }

  /// return [key] content in template file.
  String getTemplateKey(String key){
    return jsonUtils.getContentFromFileByKey(template, key);
  }

  /// Update core template file by [_index] and [_value].
  void updateTemplate(String _index, String _value){
    String str = jsonUtils.setContentFromFile(template, _index, _value);
    filesUtils.rewriteFile(template, str);
  }

  /// Update all template file.
  void setTemplate(String strTemplate){
    filesUtils.rewriteFile(template, strTemplate);
  }

}