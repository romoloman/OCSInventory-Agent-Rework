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

// External package imports
import 'dart:io';

// Common imports
import 'package:ocs_agent/core/common/files_utils.dart';
import 'package:ocs_agent/core/common/json_utils.dart';

/// Class to get config in config folder.
class Config {
  late FilesUtils filesUtils = new FilesUtils();
  late JsonUtils jsonUtils = new JsonUtils();

  final String coreFilename = "/core.json";
  final String inventoryFilename = "/inventory.json";
  final String templateFilename = "/template.json";

  late File inventory;
  late File core;
  late File template;

  /// Constructor.
  Config(String configPath, String inventoryContent) {
    createInventoryConfigFile(configPath, inventoryContent);
  }

  /// Create inventory config file and set the content.
  void createInventoryConfigFile(String configPath, String inventoryContent) {
    try {
      Directory configDir = Directory(configPath);
      if (!configDir.existsSync()) {
        configDir.createSync(recursive: true);
      }
      this.inventory = File(configPath + this.inventoryFilename);
      if (!this.inventory.existsSync()) {
        // Create the file and write the default content to {}
        this.inventory.createSync(recursive: true);
        this.inventory.writeAsStringSync(inventoryContent);
      }
      await createOthersConfigFiles(configPath);
    } catch (e) {
      print('Error creating inventory config file: ${e.toString()}');
      rethrow;
    }
  }

  /// Create core and template config files.
  Future<void> createOthersConfigFiles(String configPath) async {
    try {
      this.core = File(configPath + this.coreFilename);
      if (!this.core.existsSync()) {
        // Create the file and write the default content to []
        this.core.createSync(recursive: true);
        this.core.writeAsStringSync("[]");
      }

      this.template = File(configPath + this.templateFilename);
      if (!this.template.existsSync()) {
        // Create the file and write the default content to {}
        this.template.createSync(recursive: true);
        this.template.writeAsStringSync("{}");
      }
    } catch (e) {
      print('Error creating other config files: ${e.toString()}');
      rethrow;
    }
  }

  /// Generic method to update a config file
  void updateConfigFile(File file, String key, dynamic value) {
    try {
      String str = this.jsonUtils.setContentFromFile(file, key, value);
      if (!str.isEmpty) {
        this.filesUtils.rewriteFile(file, str);
      }
    } catch (e) {
      print('Error updating config file: ${e.toString()}');
      rethrow;
    }
  }

  /// Generic method to get content from a config file
  T getConfigContent<T>(File file, T defaultValue) {
    try {
      return this.jsonUtils.getContentFromFile(file);
    } catch (e) {
      print('Error reading config content: ${e.toString()}');
      return defaultValue;
    }
  }

  /// Generic method to get content from a config file by key
  T getConfigContentByKey<T>(File file, String key, T defaultValue) {
    try {
      return this.jsonUtils.getContentFromFileByKey(file, key);
    } catch (e) {
      print('Error reading config content by key: ${e.toString()}');
      return defaultValue;
    }
  }

  /// Generic method to set content in a config file
  void setConfigContent(File file, String content) {
    try {
      this.filesUtils.rewriteFile(file, content);
    } catch (e) {
      print('Error setting config content: ${e.toString()}');
      rethrow;
    }
  }

  /// Return all content in inventory config file.
  String getInventoryConfigs() {
    return getConfigContent<String>(this.inventory, "{}");
  }

  /// return [key] content in inventory file.
  dynamic getInventoryConfig(String key) {
    return getConfigContentByKey<dynamic>(this.inventory, key, null);
  }

  /// Update inventory config file by [key] and [value].
  void updateInventoryConfig(String key, dynamic value) {
    updateConfigFile(this.inventory, key, value);
  }

  /// Return all content in core config file.
  List<dynamic> getCoreConfigs() {
    return getConfigContent<List<dynamic>>(this.core, []);
  }

  /// return [key] content in core file.
  dynamic getCoreConfig(String module, String key) {
    try {
      dynamic result = false;
      getCoreConfigs().forEach((element) {
        if (element["name"] == module) {
          element["value"].forEach((value) {
            if (value["name"] == key) {
              result = value["value"];
            }
          });
        }
      });
      return result;
    } catch (e) {
      print('Error reading core config for module $module and key $key: ${e.toString()}');
      return false;
    }
  }

  /// Update core config file by [key] and [value].
  void updateCoreConfig(String key, String value) {
    updateConfigFile(this.core, key, value);
  }

  /// Update all core file.
  void setCore(String content) {
    setConfigContent(this.core, content);
  }

  /// return template file in json format.
  Map<String, dynamic> getTemplate() {
    return getConfigContent<Map<String, dynamic>>(this.template, {});
  }

  /// return [key] content in template file.
  String getTemplateKey(String key) {
    return getConfigContentByKey<String>(this.template, key, "");
  }

  /// Update core template file by [key] and [value].
  void updateTemplate(String key, String value) {
    updateConfigFile(this.template, key, value);
  }

  /// Update all template file.
  void setTemplate(String content) {
    setConfigContent(this.template, content);
  }
}
