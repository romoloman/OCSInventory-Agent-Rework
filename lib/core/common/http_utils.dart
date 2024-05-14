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

// External packages imports
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sprintf/sprintf.dart';

// Core imports
import 'package:ocs_agent/core/log.dart';

/// This class will execute and log the status of the query
class HTTPUtils {
  late Logger logger;

  /// Constructor
  HTTPUtils(Logger logger) {
    this.logger = logger;
  }

  /// Return header in json format.
  Map<String, String> getHeader(dynamic config) {
    // Get data from inventory.json file
    String token = config.getInventoryConfig("token");

    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: "Token $token"
    };
  }

  /// Return the statusCode message
  String? statusCodeMessage(
      String type, int statusCode, String detail, String currentMethod) {
    var statusMessage = new Map<int, String>();
    statusMessage[200] =
        sprintf("%s: 200: %s (From %s method)", [type, detail, currentMethod]);
    statusMessage[201] =
        sprintf("%s: 201: %s (From %s method)", [type, detail, currentMethod]);
    statusMessage[400] =
        sprintf("%s: 400: %s (From %s method)", [type, detail, currentMethod]);
    statusMessage[401] =
        sprintf("%s: 401: %s (From %s method)", [type, detail, currentMethod]);
    statusMessage[403] =
        sprintf("%s: 403: %s (From %s method)", [type, detail, currentMethod]);
    statusMessage[404] =
        sprintf("%s: 404: %s (From %s method)", [type, detail, currentMethod]);
    statusMessage[500] =
        sprintf("%s: 500: %s (From %s method)", [type, detail, currentMethod]);
    return statusMessage[statusCode];
  }

  /// Do a delete HTTP query
  Future<Map<String, dynamic>> delete(
      String currentMethod, Uri uri, Map<String, String>? headers) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await http.delete(uri, headers: headers);
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] = statusCodeMessage(
          "DELETE", query.statusCode, query.body, currentMethod);
    } catch (exception) {
      logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a get HTTP query
  Future<Map<String, dynamic>> get(
      String currentMethod, Uri uri, Map<String, String>? headers) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await http.get(uri, headers: headers);
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] =
          statusCodeMessage("GET", query.statusCode, query.body, currentMethod);
    } catch (exception) {
      logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a patch HTTP query
  Future<Map<String, dynamic>> patch(String currentMethod, Uri uri,
      Map<String, String>? headers, Object? body) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await http.patch(uri, headers: headers, body: body);
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] = statusCodeMessage(
          "PATCH", query.statusCode, query.body, currentMethod);
    } catch (exception) {
      logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a post HTTP query
  Future<Map<String, dynamic>> post(String currentMethod, Uri uri,
      Map<String, String>? headers, Object? body) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await http.post(uri, headers: headers, body: body);
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] = statusCodeMessage(
          "POST", query.statusCode, query.body, currentMethod);
    } catch (exception) {
      logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }

  /// Do a put HTTP query
  Future<Map<String, dynamic>> put(String currentMethod, Uri uri,
      Map<String, String>? headers, Object? body) async {
    var returnObject = new Map<String, dynamic>();
    try {
      var query = await http.put(uri, headers: headers, body: body);
      returnObject["body"] = query.body;
      returnObject["status_code"] = query.statusCode;
      returnObject["message"] =
          statusCodeMessage("PUT", query.statusCode, query.body, currentMethod);
    } catch (exception) {
      logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      returnObject["error"] = true;
    }
    return returnObject;
  }
}
