import 'dart:convert';
import 'dart:io';
import 'dart:io' show Platform;

import 'config.dart';
import 'inventory/linux/commands.dart';
import 'inventory/linux/format.dart';
import 'inventory/macos/commands.dart';
import 'inventory/macos/format.dart';
import 'inventory/windows/commands.dart';
import 'inventory/windows/format.dart';
import 'json_utils.dart';

import 'package:http/http.dart' as http;

class Api{
  Config config;
  JsonUtils jsonUtils;
  
  LinuxFormat linuxFormat;
  LinuxCommand linuxCommand;
  
  WindowsFormat windowsFormat;
  WindowsCommand windowsCommand;
  
  MacOSFormat macosFormat;
  MacOSCommand macosCommand;

  var url;

  Api(){
    this.config = new Config();
    this.jsonUtils = new JsonUtils();
    this.linuxFormat = new LinuxFormat();
    this.linuxCommand = new LinuxCommand();
    this.windowsFormat = new WindowsFormat();
    this.windowsCommand = new WindowsCommand();
    this.macosFormat = new MacOSFormat();
    this.macosCommand = new MacOSCommand();
    this.url = config.getInventoryConfig("url");
  }

  void generateToken() async {
    String username = config.getInventoryConfig("username");
    String password = config.getInventoryConfig("password");

    var response = await http.post(
      Uri.parse(this.url + "/api-auth/token"), 
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json'
      }, 
      body: jsonEncode({
        'username': username, 
        'password': password
      })
    );

    if (response.statusCode == 200){
      config.updateInventoryConfig("token", jsonUtils.getContentFromStringByKey(response.body, "token"));
    }
  }

  void apiCheck() async {
    var url = Uri.parse(this.url);

    var response = await http.get(
      url, 
      headers: this.getHeader()
    );

    if (response.statusCode != 200) {
      this.generateToken();      
    }
  }

  void sendInventory(Map<String, dynamic> body) async {
    var url = Uri.parse(this.url + "/asset/bases/");

    //print(body);

    var response = await http.post(
      url,
      headers: this.getHeader(),
      body: jsonEncode(body)
    );

    if (response.statusCode != 200){
      print("Error");
    }
  }

  Map<String, String> getHeader(){
    String token = config.getInventoryConfig("token");

    return {
        HttpHeaders.contentTypeHeader: 'application/json', 
        HttpHeaders.authorizationHeader: "Token $token"
    };
  }

  void getTemplate(id) async {
    var urlTemplates = Uri.parse(this.url + "/templates/$id/");
    var urlSections = Uri.parse(this.url + "/sections/");
    var urlFields = Uri.parse(this.url + "/fields/");

    var responseTemplates = await http.get(urlTemplates, headers: this.getHeader());
    var responseSections = await http.get(urlSections, headers: this.getHeader());
    var responseFields = await http.get(urlFields, headers: this.getHeader());

    if (responseTemplates.statusCode == 200 && responseSections.statusCode == 200 && responseFields.statusCode == 200) {
      Map<String, dynamic> template = json.decode(responseTemplates.body);
      List<dynamic> sections = json.decode(responseSections.body);
      List<dynamic> fields = json.decode(responseFields.body);

      sections.forEach((v) {
        var test = fields.where((map) => map['section'] == v['id']);
        v["fields"] = test.toList();
      });

      template["sections"] = sections;
      var encoder = new JsonEncoder.withIndent("\t");
      config.setTemplate(encoder.convert(template));
    }
  }

  Future<void> getInventory() async {
    Map<String, dynamic> template = config.getTemplate();
    Map<String, dynamic> inventory = new Map();
    if (template == null){
      print("Template is empty");
    } else {
      this.getInventoryResult(template, template["os"]).then((value) { 
        print("inventory 2 : $value");
        this.sendInventory(value);
      });
    }
  }

  Future<Map<String, dynamic>> getInventoryResult(Map<String, dynamic> template, String os) async {
    var format;

    if (os == "LIN") {
      format = this.linuxFormat;
    } else if (template["os"] == "WIN" && Platform.isWindows) {
      format = this.windowsFormat;
    } else if (template["os"] == "MAC" && Platform.isMacOS) {
      format = this.macosFormat;
    } else {
      print("error");
    }

    Map<String, dynamic> inventory = new Map();

    List<dynamic> sections = template['sections'];
    sections.forEach((section) {
      List<dynamic> fields = section['fields'];
      bool file;
      if (section['retrival_method'] == 'FILE') {
        file = true;
      } else {
        file = false;
      }
      
      fields.forEach((field) async {
        String valueTarget;
        switch (section['retrival_output']) {
          case "TBLE":
            print("table");
            await format.getbyArray(section["target"], field["retrival_value"], section['retrival_method']).then((value) => valueTarget = value);
            print(valueTarget);
            break;
          case "JSON":
            print("json");
            await format.getbyJson(section["target"], field["retrival_value"], section['retrival_method']).then((value) => valueTarget = value);
            print(valueTarget);
            break;
          case "PTXT":
            print("texte");
            await format.getbyPtxt(section["target"], field["retrival_value"], section['retrival_method']).then((value) => valueTarget = value);
            print(valueTarget);
            break;
          default:
            print("error");
            valueTarget = null;
            break;
        }
        print(inventory);
        inventory.putIfAbsent(field['name'], () => valueTarget);
      });
    });

    //print(inventory);
    return Future.delayed(Duration(seconds: 3), () => inventory);
    //return inventory;
  }
}

void main (List<String> args) async {
  Api api = new Api();

  //api.generateToken();
  //api.getTemplate(2);
  api.getInventory();
}
