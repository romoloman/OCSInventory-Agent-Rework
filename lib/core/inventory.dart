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

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ocs_agent/core/common/files_utils.dart';
import 'package:sprintf/sprintf.dart';

import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/inventory/linux/commands.dart';
import 'package:ocs_agent/core/inventory/linux/format.dart';
import 'package:ocs_agent/core/inventory/macos/commands.dart';
import 'package:ocs_agent/core/inventory/macos/format.dart';
import 'package:ocs_agent/core/inventory/windows/commands.dart';
import 'package:ocs_agent/core/inventory/windows/format.dart';

class Inventory {
  late Config config;
  late Logger logger;

  late FilesUtils filesUtils;

  late LinuxCommand linuxCommand;
  late MacOSCommand macosCommand;
  late WindowsCommand windowsCommand;
  late LinuxFormat linuxFormat;
  late MacOSFormat macosFormat;
  late WindowsFormat windowsFormat;

  late String inventoryFileName;
  late File inventoryFile;
  late File inventoryBase64;

  /// Constructor.
  Inventory() {
    this.config = new Config();
    this.logger = new Logger();

    this.filesUtils = new FilesUtils();

    this.linuxCommand = new LinuxCommand();
    this.macosCommand = new MacOSCommand();
    this.windowsCommand = new WindowsCommand();
    this.linuxFormat = new LinuxFormat();
    this.macosFormat = new MacOSFormat();
    this.windowsFormat = new WindowsFormat();

    this.inventoryFileName = sprintf('%s/%s.json', [
      config.getInventoryConfig("data_dir"),
      DateFormat("yyyy-MM-dd_HH-mm-ss").format(DateTime.now())
    ]);
    this.inventoryFile = File(inventoryFileName);
    this.inventoryBase64 = File(sprintf(
        '%s/%s.json', [config.getInventoryConfig("data_dir"), "Base64"]));
  }

  /// Get the running mode of the agent.
  int getMode() {
    return int.parse(config.getInventoryConfig("mode"));
  }

  /// Get all informations present in the local [template]
  /// with a [os] verification and format it in json.
  Future<Map<String, dynamic>> getInventoryResult(
      Map<String, dynamic> template, String os) async {
    var format;

    // Check the os platform
    if (os == "LIN") {
      format = linuxFormat;
    } else if (template["os"] == "WIN" && Platform.isWindows) {
      format = windowsFormat;
    } else if (template["os"] == "MAC" && Platform.isMacOS) {
      format = macosFormat;
    } else {
      logger.error("OS does not match any of the supported OSs");
    }

    Map<String, dynamic> inventoryResult = new Map();

    List<dynamic> sections = template['sections'];

    for (var section in sections) {
      Map<String, dynamic> result = await getResult(os, template, section);
      var valueTarget;

      // Choose the retrieval format
      switch (section['retrival_output']) {
        case "TBLE":
          valueTarget = format.getByArray(section["fields"], result);
          break;
        case "JSON":
          valueTarget = format.getByJson(section["fields"], result);
          break;
        case "PTXT":
          valueTarget = await format.getByPtxt(section["fields"], result);
          break;
        case "REGX":
          valueTarget = format.getByRegx(section["fields"], result);
          break;
        case "GREP":
          valueTarget = format.getByGrep(section["fields"], result);
          break;
        default:
          valueTarget = null;
          break;
      }
      inventoryResult.putIfAbsent(section['name'], () => valueTarget);
    }

    return inventoryResult;
  }

  /// Get the result
  Future<Map<String, dynamic>> getResult(String os,
      Map<String, dynamic> template, Map<String, dynamic> section) async {
    late var command;
    Map<String, dynamic> result = new Map();

    // Check the os platform
    if (os == "LIN") {
      command = this.linuxCommand;
    } else if (template["os"] == "WIN" && Platform.isWindows) {
      command = this.windowsCommand;
    } else if (template["os"] == "MAC" && Platform.isMacOS) {
      command = this.macosCommand;
    } else {
      logger.error("OS does not match any of the supported OSs");
    }

    Map<String, dynamic> main = new Map<String, dynamic>();
    Map<String, dynamic> options = new Map<String, dynamic>();
    if (section['options'] != null) {
      options = section['options'];
    }

    String mainRes =
        await command.getResult(section["target"], section['retrival_method']);
    main.putIfAbsent('name', () => section['name']);
    main.putIfAbsent('type', () => section['retrival_output']);
    main.putIfAbsent('options', () => options);
    main.putIfAbsent('result', () => mainRes);
    result.putIfAbsent('main', () => main);
    List<dynamic> test = section['fields'];
    var fieldOver = test.where((element) => element["override_target"]);

    for (var field in fieldOver) {
      Map<String, dynamic> sub = new Map<String, dynamic>();
      String res = await command.getResult(
          field["new_target"], field['retrival_method']);
      sub.putIfAbsent('name', () => field['name']);
      sub.putIfAbsent('type', () => field['retrival_output']);
      sub.putIfAbsent('options', () => field['options']);
      sub.putIfAbsent('result', () => res);
      result.putIfAbsent(field['name'], () => sub);
    }

    return result;
  }

  /// Check if a local template exists or not.
  bool getLocalTemplate() {
    logger.info("Getting local template...");

    Map<String, dynamic> template = config.getTemplate();
    // Check if the local template exists
    if (template.isNotEmpty ||
        template.values.isNotEmpty ||
        template.keys.isNotEmpty ||
        template.length != 0) {
      logger.info("Local template found!");
      return true;
    } else {
      logger.error("Local template not found!");
      return false;
    }
  }

  /// Process the template and format template inventory.
  Future<Map<String, dynamic>> processTemplate() async {
    // Get the template from template.json
    var template = config.getTemplate();
    logger.info("Processing template...");
    var value = await getInventoryResult(template, template["os"]);
    var templateInventory;
    // If the value isn't empty, it creates an object with data
    // If not, return an error
    if (value.isNotEmpty) {
      templateInventory = {
        "values": value,
        "return": "true",
      };
      logger.info("Template processed successfully!");
    } else {
      templateInventory = {
        "return": "false",
      };
      logger.error("Can't process the template because it is empty!");
    }
    return templateInventory;
  }

  /// Create a local inventory in the JSON format.
  void sendLocalBaseInventory(Map<String, dynamic> body) {
    logger.info("Creating base inventory file...");
    logger.info("Writing base inventory locally...");
    // Create a file to save the new inventory
    inventoryFile.create(recursive: true);
    var encoder = JsonEncoder.withIndent("\t");
    // Write the new inventory inside
    filesUtils.writeFile(inventoryFile, encoder.convert(body));
    logger
        .info(sprintf("New base inventory created in %s", [inventoryFileName]));
  }

  /// Update the local inventory to add template inventory
  Future<void> sendLocalTemplateInventory() async {
    logger.info("Adding template inventory locally...");

    if (getLocalTemplate()) {
      var templateInventory = await processTemplate();

      if (templateInventory["return"] != false) {
        // Get the local inventory
        var content = jsonDecode(inventoryFile.readAsStringSync());
        var encoder = new JsonEncoder.withIndent("\t");
        content["template_inventory"] = templateInventory["values"];
        logger.verbose(content["template_inventory"].toString());
        // Write into inventory file
        filesUtils.writeFile(inventoryFile, encoder.convert(content));
        logger.info("Template inventory added to base inventory!");
      } else {
        logger.error("Failed to process template!");
      }
    } else {
      logger.error("Can't get local template!");
    }
  }
}
