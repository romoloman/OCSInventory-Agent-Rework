import 'dart:convert';
import 'dart:io';

import 'package:ocs_agent/core/config.dart';

import 'package:http/http.dart' as http;
import 'package:ocs_agent/core/json_utils.dart';

class Api{
  Config config;
  JsonUtils jsonUtils;

  var url;

  Api(){
    this.config = new Config();
    this.jsonUtils = new JsonUtils();
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

  void sendInventory(Map<String, String> body) async {
    var url = Uri.parse(this.url + "/asset/bases/");

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
}


void main(List<String> args) async{
  Api api = new Api();
  
  api.apiCheck();
  Map<String, String> body = {
    "name":"PC-0001",
    "description":"Une super description",
    "serial":"24 Ans !",
    "osname":"Windows",
    "osversion":"Something something",
    "uuid":"40890b0b-8166-4907-8f0d-4d41520413f3",
    "srcip":"172.18.15.152",
    "srcmac":"33-FC-AA-6E-96-C6",
    "domain":"blablabla"
  };

  //api.sendInventory(body);
  api.getTemplate(1);
}