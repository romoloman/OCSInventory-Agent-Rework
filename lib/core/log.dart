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
import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/common/http_utils.dart';

import 'package:sprintf/sprintf.dart';

/// Insert log in console or file if configured in inventory.json.
class Logger {
  late Config config;
  late bool _isFile;
  late String _logLevel;
  late String _url;
  late File file;
  late DateFormat dateFormat;

  /// Constructor.
  Logger() {
    config = new Config();
    _logLevel = config.getInventoryConfig("log_level");
    _isFile = (config.getInventoryConfig("log_file").toLowerCase() == 'true');
    _url = config.getInventoryConfig("url");

    if (_isFile) {
      file = File(config.getInventoryConfig("log_filename"));
    }

    dateFormat = DateFormat('yyyy-MM-dd H:m:s');
  }

  /// Print info message.
  void info(String info) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date INFO: $info\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  /// Print warning message.
  void warning(String warning) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date WARNING: $warning\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  /// Print error message.
  void error(String error) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date ERROR: $error\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  /// Print verbose message.
  void verbose(String verbose) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date VERBOSE: $verbose\n";
    if (_logLevel == "1") {
      if (_isFile) {
        file.writeAsStringSync(txt, mode: FileMode.append);
      } else {
        print(txt);
      }
    }
  }

  /// Send formated logs to the server
  void serverLogger(int assetID, String? errorCode, String comment) async {
    if (assetID != -1) {
      HTTPUtils query = new HTTPUtils();
      String token = config.getInventoryConfig("token");
      Map<String, dynamic> content = new Map();
      content["asset"] = assetID;
      content["scope"] = errorCode;
      content["comment"] = comment;
      try {
        await query.post(
            "serverLogger",
            Uri.parse("$_url/asset/logs/"),
            {
              HttpHeaders.contentTypeHeader: 'application/json',
              HttpHeaders.authorizationHeader: "Token $token"
            },
            jsonEncode(content));
      } catch (exception) {
        error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      }
    } else {
      error("Failed to send remote logs!");
    }
  }
}
