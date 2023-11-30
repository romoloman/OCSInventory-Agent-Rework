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
import 'package:ocs_agent/core/log.dart';

import 'config.dart';
import 'inventory/linux/commands.dart';
import 'inventory/linux/format.dart';
import 'inventory/macos/commands.dart';
import 'inventory/macos/format.dart';
import 'inventory/windows/commands.dart';
import 'inventory/windows/format.dart';
import 'json_utils.dart';

import 'package:sprintf/sprintf.dart';
import 'package:http/http.dart' as http;

/// This class communicate with the server.
class Api {
  late Config config;
  late JsonUtils jsonUtils;
  late Logger logger;

  late LinuxFormat linuxFormat;
  late LinuxCommand linuxCommand;

  late WindowsFormat windowsFormat;
  late WindowsCommand windowsCommand;

  late MacOSFormat macosFormat;
  late MacOSCommand macosCommand;

  late String inventoryFileName;
  late File inventory;

  var url;

  /// Constructor.
  Api() {
    this.config = new Config();
    this.jsonUtils = new JsonUtils();
    this.linuxFormat = new LinuxFormat();
    this.linuxCommand = new LinuxCommand();
    this.windowsFormat = new WindowsFormat();
    this.windowsCommand = new WindowsCommand();
    this.macosFormat = new MacOSFormat();
    this.macosCommand = new MacOSCommand();
    this.logger = new Logger();
    this.url = config.getInventoryConfig("url");

    this.inventoryFileName = sprintf('%s/%s.json', [
      config.getInventoryConfig("data_dir"),
      DateFormat("yyyy-MM-dd_HH-mm-ss").format(DateTime.now())
    ]);
    this.inventory = File(inventoryFileName);
  }

  /// Get the running mode of the agent.
  int getMode() {
    return int.parse(config.getInventoryConfig("mode"));
  }

  /// Check if api is working and generate token if not.
  Future<bool> apiCheck() async {
    String username = config.getInventoryConfig("username");
    String password = config.getInventoryConfig("password");

    logger.info("Checking API...");
    try {
      var response = await http.post(Uri.parse(url + "/api-auth/token"),
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'username': username, 'password': password}));
      if (response.statusCode == 200) {
        logger.info("API status's up !");
        await generateToken();
        return true;
      } else if (response.statusCode == 401) {
        logger.error(
            "Unauthorized ! (Check username or password in the configuration file)");
        return false;
      } else {
        logger.error("API check error !");
        return false;
      }
    } catch (exception) {
      logger.error(
          sprintf("API not found ! (%s)", [exception.toString().trim()]));
      return false;
    }
  }

  /// Send to Api the username and password and
  /// save it in inventory.json.
  Future<bool> generateToken() async {
    String username = config.getInventoryConfig("username");
    String password = config.getInventoryConfig("password");
    String token = config.getInventoryConfig("token");

    logger.info("Generating token...");
    var response = await http.post(Uri.parse(url + "/api-auth/token"),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'username': username, 'password': password}));
    if (response.statusCode == 200) {
      logger.info("Token has been retreive from server !");
      if (jsonUtils.getContentFromStringByKey(response.body, "token") !=
          token) {
        config.updateInventoryConfig("token",
            jsonUtils.getContentFromStringByKey(response.body, "token"));
        logger.info(
            "Local token has been changed with token retreived from server !");
        return true;
      } else {
        logger.info(
            "Local token is the same as the token from server. Keep the local token.");
        return true;
      }
    } else {
      logger.error("Generate token error !");
      return false;
    }
  }

  /// return header in json format.
  Map<String, String> getHeader() {
    String token = config.getInventoryConfig("token");

    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: "Token $token"
    };
  }

  /// Save the server configs in config/core.json
  Future<void> saveConfig() async {
    logger.info("Getting remote config...");

    var responseConfig =
        await http.get(Uri.parse(url + "/config/"), headers: getHeader());
    List<dynamic> config = json.decode(responseConfig.body);

    if (responseConfig.statusCode == 200) {
      logger.info("Remote config found !");
      var encoder = new JsonEncoder.withIndent("\t");
      this.config.setCore(encoder.convert(config));
      logger.info("Remote config saved in local !");
    } else {
      logger.error("Remote config not found !");
    }
  }

  /// Check if config file exist and save it if not
  Future<void> checkAndApplyConfig() async {
    List<dynamic> confFile = config.getCoreConfigs();

    logger.info("Checking local config...");

    if (confFile.isEmpty) {
      logger.info("local config not found ! Creating one...");
      await saveConfig();
    } else {
      logger.info("Local config found !");
    }
  }

  /// Check if an inventory already exist on the server.
  Future<bool> checkInventory(Map<String, dynamic> body) async {
    String uuid = await body['uuid'];
    uuid = uuid.isEmpty ? 'none' : uuid;

    logger.info("Checking if there is existing inventory of the machine...");
    var response = await http.get(Uri.parse(url + "/asset/bases?uuid=$uuid"),
        headers: getHeader());
    if (response.statusCode == 200) {
      if (response.body.contains(uuid)) {
        logger.info("Existing inventory found !");
        return true;
      } else {
        logger.error("No existing inventory found !");
        return true;
      }
    } else {
      logger.info("No inventory found !");
      var response = await http.post(Uri.parse(url + "/asset/bases/"),
          headers: getHeader(), body: jsonEncode(body));
      if (response.statusCode == 200) {
        logger.info("New inventory has been sent to the server !");
        return true;
      } else {
        logger.error("Checking new inventory error !");
        return false;
      }
    }
  }

  /// Create or update the inventory and send it to the server.
  Future<bool> sendRemoteBaseInventory(Map<String, dynamic> body) async {
    if (await checkInventory(body)) {
      String uuid = await body['uuid'];
      uuid = uuid.isEmpty ? 'none' : uuid;

      logger.info("Sending base inventory to server...");
      var response = await http.get(Uri.parse(url + "/asset/bases/?uuid=$uuid"),
          headers: getHeader());
      if (response.statusCode == 200) {
        if (response.body.contains(uuid)) {
          logger.info("Updating inventory...");
          var id = jsonDecode(response.body)[0]['id'];
          var responsePut = await http.put(Uri.parse(url + "/asset/bases/$id/"),
              headers: getHeader(), body: jsonEncode(body));
          if (responsePut.statusCode == 200) {
            logger.info("Update base inventory has been sent to the server !");
            return true;
          } else {
            logger.error("Failed to send inventory update !");
            return false;
          }
        } else {
          logger.info("Creating new inventory...");
          var responsePost = await http.post(Uri.parse(url + "/asset/bases/"),
              headers: getHeader(), body: jsonEncode(body));
          if (responsePost.statusCode == 200) {
            logger.info("New inventory has been sent to the server !");
            return true;
          } else {
            logger.error("Failed to send new inventory !");
            return false;
          }
        }
      } else {
        logger.error("Can't get inventory from server !");
        return false;
      }
    } else {
      logger.error("Can't check inventory !");
      return false;
    }
  }

  /// Create a local inventory in the JSON format.
  bool sendLocalBaseInventory(Map<String, dynamic> body) {
    logger.info("Sending base inventory to local...");
    logger.info("Creating base inventory file...");
    inventory.create(recursive: true);
    var encoder = JsonEncoder.withIndent("\t");
    inventory.writeAsStringSync(encoder.convert(body));
    logger
        .info(sprintf("New base inventory created in %s", [inventoryFileName]));
    return true;
  }

  /// Get the remote template id and last update.
  Future<Map<String, String>> getRemoteTemplateInfo(
      Map<String, dynamic> body) async {
    Map<String, String> info;
    String uuid = await body['uuid'];
    uuid = uuid.isEmpty ? 'none' : uuid;

    var responseAsset = await http.get(
        Uri.parse(url + "/asset/bases?uuid=" + uuid),
        headers: getHeader());

    if (responseAsset.statusCode == 200 && responseAsset.body.isNotEmpty) {
      logger.info("Base inventory found !");
      var responseTemplate = await http.get(
          Uri.parse(url +
              "/templates/" +
              jsonDecode(responseAsset.body)[0]['template'].toString()),
          headers: getHeader());
      if (responseTemplate.statusCode == 200) {
        info = {
          "id": jsonDecode(responseTemplate.body)['id'].toString(),
          "last_update":
              jsonDecode(responseTemplate.body)['last_update'].toString(),
          "return": "true",
        };
      } else {
        logger.error("Remote template not found !");
        info = {
          "return": "false",
        };
      }
    } else {
      logger.error("Asset base not found !");
      info = {
        "return": "false",
      };
    }
    return info;
  }

  /// Get the local template id and last update.
  Map<String, String> getLocalTemplateInfo() {
    Map<String, String> info;
    if (getLocalTemplate()) {
      var template = config.getTemplate();
      info = {
        "id": template["id"].toString(),
        "last_update": template["last_update"].toString(),
      };
    } else {
      info = {
        "return": "false",
      };
    }
    return info;
  }

  /// Compare the both template to know if we need to create or update the local template.
  int compareTemplate(
      Map<String, String> localInfo, Map<String, String> remoteInfo) {
    if (remoteInfo["id"] == localInfo["id"]) {
      logger.info("Local template exist on the server !");
      if (remoteInfo["last_update"] == localInfo["last_update"]) {
        logger.info("Local template's up to date !");
        return 0;
      } else {
        logger.info("Local template isn't up to date !");
        return 1;
      }
    } else {
      logger.info("Local template doesn't exist on the server !");
      return 2;
    }
  }

  /// Get the remote template values to create or update the local template.
  Future<bool> getRemoteTemplate(Map<String, dynamic> body) async {
    var remoteInfo = await getRemoteTemplateInfo(body);
    var localInfo = getLocalTemplateInfo();

    logger.info("Getting remote template...");

    if (remoteInfo["return"] != "false" || localInfo["return"] != "false") {
      var compareResult = compareTemplate(localInfo, remoteInfo);
      if (compareResult == 0) {
        logger.info("No need to erase current template.");
        return true;
      } else if (compareResult == 1 || compareResult == 2) {
        var id = remoteInfo["id"];

        logger.info("Creating or updating the local template...");

        var responseTemplates = await http
            .get(Uri.parse(url + "/templates/$id/"), headers: getHeader());

        if (responseTemplates.statusCode == 200) {
          logger.info("Remote template found !");
          Map<String, dynamic> template = json.decode(responseTemplates.body);
          var encoder = new JsonEncoder.withIndent("\t");
          config.setTemplate(encoder.convert(template));
          logger.info("Remote template has been saved into local !");
          return true;
        } else {
          logger.error("Remote template not found !");
          return false;
        }
      } else {
        logger.error("Compare result not found !");
        return false;
      }
    } else {
      logger.error("Can't get local or remote template info !");
      return false;
    }
  }

  /// Return if a local template is existing or not.
  bool getLocalTemplate() {
    logger.info("Getting local template...");

    Map<String, dynamic> template = config.getTemplate();

    if (template.isNotEmpty ||
        template.values.isNotEmpty ||
        template.keys.isNotEmpty ||
        template.length != 0) {
      logger.info("Local template found !");
      return true;
    } else {
      logger.error("Local template not found !");
      return false;
    }
  }

  Future<Map<String, dynamic>> getResult(String os,
      Map<String, dynamic> template, Map<String, dynamic> section) async {
    Map<String, dynamic> result = new Map<String, dynamic>();
    var command;

    if (os == "LIN") {
      command = this.linuxCommand;
    } else if (template["os"] == "WIN" && Platform.isWindows) {
      command = this.windowsCommand;
    } else if (template["os"] == "MAC" && Platform.isMacOS) {
      command = this.macosCommand;
    } else {
      logger.error("Error to get the result");
    }

    Map<String, dynamic> main = new Map<String, dynamic>();
    Map<String, dynamic> options = new Map<String, dynamic>();
    if (section['options'] != null) {
      options = section['options'];
    }

    String mainRes =
        await command.getResult(section["target"], section['retrival_method']);
    main.putIfAbsent('result', () => mainRes);
    main.putIfAbsent('type', () => section['retrival_output']);
    main.putIfAbsent('name', () => section['name']);
    main.putIfAbsent('options', () => options);
    result.putIfAbsent('main', () => main);
    List<dynamic> test = section['fields'];
    var fieldOver = test.where((element) => element["override_target"]);

    for (var field in fieldOver) {
      Map<String, dynamic> sub = new Map<String, dynamic>();
      String res = await command.getResult(
          field["new_target"], field['retrival_method']);
      sub.putIfAbsent('result', () => res);
      sub.putIfAbsent('type', () => field['retrival_output']);
      sub.putIfAbsent('name', () => field['name']);
      result.putIfAbsent(field['name'], () => sub);
    }

    return result;
  }

  /// Get all informations present in the [template] from the computer
  /// with a [os] verification and format it in json.
  Future<Map<String, dynamic>> getInventoryResult(
      Map<String, dynamic> template, String os) async {
    var format;

    if (os == "LIN") {
      format = this.linuxFormat;
    } else if (template["os"] == "WIN" && Platform.isWindows) {
      format = this.windowsFormat;
    } else if (template["os"] == "MAC" && Platform.isMacOS) {
      format = this.macosFormat;
    } else {
      logger.error("Error to get the result");
    }

    Map<String, dynamic> inventoryResult = new Map();

    List<dynamic> sections = template['sections'];

    for (var section in sections) {
      Map<String, dynamic> result = await getResult(os, template, section);
      var valueTarget;

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

  /// Execute the template and format template inventory.
  Future<Map<String, dynamic>> executeTemplate() async {
    var template = config.getTemplate();
    logger.info("Executing template...");
    var value = await getInventoryResult(template, template["os"]);
    var templateInventory;
    if (value.isNotEmpty) {
      templateInventory = {
        "values": value,
        "return": "true",
      };
      logger.info("Template executed successfully !");
      return templateInventory;
    } else {
      templateInventory = {
        "return": "false",
      };
      logger.error("Can't execute the template because he is empty !");
      return templateInventory;
    }
  }

  /// Update the remote inventory to add template inventory
  Future<void> sendRemoteTemplateInventory(Map<String, dynamic> body) async {
    if (await getRemoteTemplate(body)) {
      var templateInventory = await executeTemplate();
      if (templateInventory["return"] != false) {
        logger.info("Sending template inventory to server...");
        String uuid = await body['uuid'];
        uuid = uuid.isEmpty ? 'none' : uuid;
        var response = await http.get(
            Uri.parse(url + "/asset/bases/?uuid=$uuid"),
            headers: getHeader());
        if (response.statusCode == 200) {
          if (response.body.contains(uuid)) {
            logger.info("Updating inventory...");
            var id = jsonDecode(response.body)[0]['id'];
            var content = jsonDecode(response.body)[0];
            var encoder = new JsonEncoder.withIndent("\t");
            content["template_inventory"] = templateInventory["values"];
            var responsePut = await http.put(
                Uri.parse(url + "/asset/bases/$id/"),
                headers: getHeader(),
                body: encoder.convert(content));
            if (responsePut.statusCode == 200) {
              logger
                  .info("Template inventory added to remote base inventory !");
            } else {
              logger.error(
                  "Can't upload template inventory to remote base inventory !");
            }
          } else {
            logger.error("Base inventory not found !");
          }
        } else {
          logger.error("Can't get base inventory from server !");
        }
      } else {
        logger.error("Can't execute template !");
      }
    } else {
      logger.error("Can't get remote template !");
    }
  }

  /// Update the local inventory to add template inventory
  Future<void> sendLocalTemplateInventory() async {
    logger.info("Sending template inventory to local...");

    if (getLocalTemplate()) {
      var templateInventory = await executeTemplate();

      if (templateInventory["return"] != false) {
        var content = jsonDecode(inventory.readAsStringSync());
        var encoder = new JsonEncoder.withIndent("\t");
        content["template_inventory"] = templateInventory["values"];
        inventory.writeAsStringSync(encoder.convert(content));
        logger.info("Template inventory added to base inventory !");
      } else {
        logger.error("Can't execute template !");
      }
    } else {
      logger.error("Can't get local template !");
    }
  }
}
