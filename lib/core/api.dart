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
  }

  int getMode() {
    return int.parse(config.getInventoryConfig("mode"));
  }

  /// Check if api is working and generate token if not.
  Future<bool> apiCheck() async {
    String username = config.getInventoryConfig("username");
    String password = config.getInventoryConfig("password");

    logger.info("Checking API...");

    try {
      var response = await http.post(Uri.parse(this.url + "/api-auth/token"),
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          body: jsonEncode({'username': username, 'password': password}));
      if (response.statusCode == 200) {
        logger.info("API status's up !");
        await this.generateToken();
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

    var response = await http.post(Uri.parse(this.url + "/api-auth/token"),
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'username': username, 'password': password}));

    if (response.statusCode == 200) {
      logger.info("Token has been retreive from server !");
      if (jsonUtils.getContentFromStringByKey(response.body, "token") !=
          token) {
        logger.info(
            "Local token has been changed with token retreive from server !");
        config.updateInventoryConfig("token",
            jsonUtils.getContentFromStringByKey(response.body, "token"));
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

  Future<bool> checkInventory(Map<String, dynamic> body) async {
    String uuid = await body['uuid'];
    uuid = uuid.isEmpty ? 'none' : uuid;

    logger.info("Checking if there is existing inventory of the machine...");

    var response = await http.get(Uri.parse(url + "/asset/bases/?uuid=$uuid"),
        headers: this.getHeader());
    if (response.statusCode == 200) {
      if (response.body.contains(uuid)) {
        logger.info("Existing inventory found !");
        return true;
      } else {
        logger.error("Checking existing inventory error !");
        return false;
      }
    } else {
      logger.info("No inventory found !");

      var response = await http.post(Uri.parse(this.url + "/asset/bases/"),
          headers: this.getHeader(), body: jsonEncode(body));

      if (response.statusCode == 200) {
        logger.info("New inventory has been sent to the server !");
        return true;
      } else {
        logger.error("Checking new inventory error !");
        return false;
      }
    }
  }

  Future<bool> sendRemoteAssetInventory(Map<String, dynamic> body) async {
    if (await this.checkInventory(body)) {
      String uuid = await body['uuid'];
      uuid = uuid.isEmpty ? 'none' : uuid;

      logger.info("Sending Asset base to server...");

      var response = await http.get(Uri.parse(url + "/asset/bases/?uuid=$uuid"),
          headers: this.getHeader());
      if (response.statusCode == 200) {
        if (response.body.contains(uuid)) {
          logger.info("Existing inventory found ! Updating inventory...");

          var id = jsonDecode(response.body)[0]['id'];
          var responseGet = await http.put(Uri.parse(url + "/asset/bases/$id/"),
              headers: this.getHeader(), body: jsonEncode(body));
          if (responseGet.statusCode == 200) {
            logger.info("Update inventory has been sent to the server !");
            return true;
          } else {
            logger.error("Failed to send inventory update !");
            return false;
          }
        } else {
          logger.info("No inventory found ! Creating new inventory...");

          var responsePost = await http.post(
              Uri.parse(this.url + "/asset/bases/"),
              headers: this.getHeader(),
              body: jsonEncode(body));

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

  Future<bool> sendLocalAssetInventory(Map<String, dynamic> body) async {
    return false;
  }

  /// Send [body] to api /asset/bases.
  void sendInventory(Map<String, dynamic> body) async {
    /// Get the UUID of the body
    String uuid = await body['uuid'];

    uuid = uuid.isEmpty ? 'none' : uuid;
    var urlGet = Uri.parse(this.url + "/asset/bases/?uuid=$uuid");

    /// Get the inventory of this [uuid] in asset bases
    var responseGet = await http.get(urlGet, headers: this.getHeader());
    if (responseGet.statusCode == 200) {
      /// test if the body exist in asset bases or not
      if (responseGet.body.contains(uuid)) {
        /// Get the ID
        var getID = jsonDecode(responseGet.body);
        var id = getID[0]['id'];
        var urlUpdate = Uri.parse(this.url + "/asset/bases/$id/");
        var responseUpdate = await http.put(urlUpdate,
            headers: this.getHeader(), body: jsonEncode(body));
        if (responseUpdate.statusCode != 200) {
          logger.error("Error to update body");
        } else {
          logger.info("Inventory updating");
        }
      } else {
        var urlPost = Uri.parse(this.url + "/asset/bases/");
        var responsePost = await http.post(urlPost,
            headers: this.getHeader(), body: jsonEncode(body));

        if (responsePost.statusCode != 200) {
          logger.error("Error to send body");
        } else {
          logger.info("Inventory sending");
        }
      }
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

  /// Get and generate template with his [id].
  void getTemplate(id) async {
    var urlTemplates = Uri.parse(this.url + "/templates/$id/");
    var urlSections = Uri.parse(this.url + "/sections/");
    var urlFields = Uri.parse(this.url + "/fields/");

    var responseTemplates =
        await http.get(urlTemplates, headers: this.getHeader());
    var responseSections =
        await http.get(urlSections, headers: this.getHeader());
    var responseFields = await http.get(urlFields, headers: this.getHeader());

    if (responseTemplates.statusCode == 200 &&
        responseSections.statusCode == 200 &&
        responseFields.statusCode == 200) {
      Map<String, dynamic> template = json.decode(responseTemplates.body);
      List<dynamic> sections = json.decode(responseSections.body);
      List<dynamic> fields = json.decode(responseFields.body);

      sections.forEach((v) {
        var listfield = fields.where((map) => map['section'] == v['id']);
        v["fields"] = listfield.toList();
      });

      template["sections"] =
          sections.where((sec) => sec['template'] == id).toList();
      var encoder = new JsonEncoder.withIndent("\t");
      config.setTemplate(encoder.convert(template));
    }
  }

  /// Check if config file exist and save it if not
  Future<void> checkAndApplyConfig() async {
    List<dynamic> confFile = this.config.getCoreConfigs();

    if (confFile.isEmpty) {
      await this.saveConfig();
    }
  }

  /// Save the server configs in config/core.json
  Future<void> saveConfig() async {
    var urlConfig = Uri.parse(this.url + "/config/");
    var responseConfig = await http.get(urlConfig, headers: this.getHeader());
    List<dynamic> config = json.decode(responseConfig.body);

    var encoder = new JsonEncoder.withIndent("\t");
    this.config.setCore(encoder.convert(config));
  }

  /// Get Template ID
  int getIdTemplate() {
    Map<String, dynamic> template = config.getTemplate();
    var idTemplate;
    if (template.isNotEmpty) {
      idTemplate = template["id"];
    } else {
      idTemplate = config.getInventoryConfig('template_id');
    }
    if (idTemplate is int) {
      return idTemplate;
    } else {
      return int.parse(idTemplate);
    }
  }

  /// Find template if agent hstatusCodeasn't one
  Future<void> findTemplate() async {
    // Find OS
    var os;
    if (Platform.isMacOS) {
      os = "MAC";
    } else if (Platform.isLinux) {
      os = "LIN";
    } else if (Platform.isWindows) {
      os = "WIN";
    } else {
      logger.error("What is your OS ?");
    }

    var url = Uri.parse(this.url + "/templates?os=" + os);
    var response = await http.get(url, headers: this.getHeader());

    if (response.statusCode == 200) {
      var templates = json.decode(response.body);
      var id = 1000000;

      templates.forEach((t) {
        if (id > t['id']) {
          id = t['id'];
        }
      });
      this.getTemplate(id);
    }
  }

  /// Check if the template is not empty, get all informations from template
  /// and send inventory.
  Future<void> getInventory() async {
    Map<String, dynamic> template = config.getTemplate();

    if (template.isEmpty ||
        template.values.isEmpty ||
        template.keys.isEmpty ||
        template.length == 0) {
      logger.error("Template is empty");
    } else {
      var value = await this.getInventoryResult(template, template["os"]);
      logger.info("inventory 2 : " + jsonEncode(value));
      this.sendTemplate(value);
    }
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

    Map<String, dynamic> inventory = new Map();

    List<dynamic> sections = template['sections'];

    for (var section in sections) {
      Map<String, dynamic> result = await this.getResult(os, template, section);
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
      inventory.putIfAbsent(section['name'], () => valueTarget);
    }

    return inventory;
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

  /// Send [Template] to api /asset/bases.
  void sendTemplate(Map<String, dynamic> template) async {
    /// [idTemplate] proved to the template [getInventory()]
    /// Get the associed inventory to the template
    var id = this.getIdTemplate();
    var urlGetTemplate = Uri.parse(this.url + "/asset/bases/?template=$id");
    var responseGetTemplate =
        await http.get(urlGetTemplate, headers: this.getHeader());

    /// Get ID the inventory to patch
    var getTemplate = jsonDecode(responseGetTemplate.body);
    print(responseGetTemplate.statusCode);
    var idToPatch = getTemplate[0]['id'];

    /// Set a PATCH request to send the template inventory
    /// Before sending test the Last Update
    if (DateTime.now().isAfter(DateTime.parse(getTemplate[0]['last_update']))) {
      var urlUpdateTemplate = Uri.parse(this.url + "/asset/bases/$idToPatch/");
      var responseUpdateTemplate = await http.patch(urlUpdateTemplate,
          headers: this.getHeader(), body: jsonEncode(template));
      if (responseUpdateTemplate.statusCode != 200) {
        logger.error("Error to send template inventory ");
      } else {
        logger.info("Inventory template are sending");
      }
    }
  }
}
