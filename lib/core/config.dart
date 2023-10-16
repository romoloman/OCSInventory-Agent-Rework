// OCSInventory Agent
// Copyright (C) OCSInventory-NG
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:ocs_agent/core/json_utils.dart';
import 'package:ocs_agent/core/files_utils.dart';

/// Class to get config in config folder.
class Config {
  final String inventoryFilename = "config/inventory.json";
  final String coreFilename = "config/core.json";
  final String templateFilename = "config/template.json";

  late JsonUtils jsonUtils;
  late FilesUtils filesUtils;

  late File inventory;
  late File core;
  late File template;

  /// Constructor.
  Config() {
    this.jsonUtils = JsonUtils();
    this.filesUtils = FilesUtils();
    this.inventory = File(inventoryFilename);
    this.core = File(coreFilename);
    this.template = File(templateFilename);
  }

  /// Return all content in inventory config file.
  String getInventoryConfigs() {
    return jsonUtils.getContentFromFile(inventory).toString();
  }

  /// return [key] content in inventory file.
  String getInventoryConfig(String key) {
    var returnValue = jsonUtils.getContentFromFileByKey(inventory, key);
    if (returnValue is int) {
      return returnValue.toString();
    } else {
      return returnValue;
    }
  }

  /// Update inventory config file by [_index] and [_value].
  void updateInventoryConfig(String _index, String _value) {
    String str = jsonUtils.setContentFromFile(inventory, _index, _value);
    filesUtils.rewriteFile(inventory, str);
  }

  /// Return all content in core config file.
  List<dynamic> getCoreConfigs() {
    return jsonUtils.getContentFromFile(core);
  }

  /// return [key] content in core file.
  String getCoreConfig(String key) {
    return jsonUtils.getContentFromFileByKey(core, key);
  }

  /// Update core config file by [_index] and [_value].
  void updateCoreConfig(String _index, String _value) {
    String str = jsonUtils.setContentFromFile(core, _index, _value);
    filesUtils.rewriteFile(core, str);
  }

  /// Update all core file.
  void setCore(String strCore) {
    filesUtils.rewriteFile(core, strCore);
  }

  /// return template file in json format.
  Map<String, dynamic> getTemplate() {
    return jsonUtils.getContentFromFile(template);
  }

  /// return [key] content in template file.
  String getTemplateKey(String key) {
    return jsonUtils.getContentFromFileByKey(template, key);
  }

  /// Update core template file by [_index] and [_value].
  void updateTemplate(String _index, String _value) {
    String str = jsonUtils.setContentFromFile(template, _index, _value);
    filesUtils.rewriteFile(template, str);
  }

  /// Update all template file.
  void setTemplate(String strTemplate) {
    filesUtils.rewriteFile(template, strTemplate);
  }
}
