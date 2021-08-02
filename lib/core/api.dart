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
    this.url = Uri.parse(config.getInventoryConfig("url") + "/api-auth/token");
  }

  void generateToken() async {
    String username = config.getInventoryConfig("username");
    String password = config.getInventoryConfig("password");

    var response = await http.post(
      url, 
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
    String token = config.getInventoryConfig("token");
    var url = Uri.parse(config.getInventoryConfig("url"));

    var response = await http.get(
      url, 
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json', 
        HttpHeaders.authorizationHeader: "Token $token"
      }
    );

    if (response.statusCode != 200) {
      this.generateToken();      
    }
  }
}
