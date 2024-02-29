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

import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/inventory/macos/commands.dart';

class MacOSFormat {
  late Logger logger;

  late MacOSCommand macosCommand;

  MacOSFormat() {
    this.logger = new Logger();

    this.macosCommand = new MacOSCommand();
  }

  /// get result of [resultCommand] for each [fields].
  List<dynamic> getByJson(List<dynamic> fields,
      Map<String, dynamic> resultCommand, String commandLine) {
    var fieldsOver = fields.where((element) => element["override_target"]);
    var json = new Map<String, dynamic>();
    late Map<String, dynamic> result;
    List<dynamic> subInventory = new List.empty(growable: true);
    commandLine = commandLine.split(" ")[1];

    resultCommand.keys.forEach((element) {
      try {
        if (resultCommand[element]['options'] != null &&
            resultCommand[element]['options'].containsKey('need_format') &&
            !resultCommand[element]['options']['need_format']) {
          json[element] = jsonDecode(resultCommand[element]['result']);
        } else {
          json[element] = this.formatJson(resultCommand[element]['result']);
        }
      } catch (e) {
        json[element] = null;
        logger.verbose("Next Json object won't be well formated!");
      }
    });

    json["main"] = json["main"][commandLine];

    if (json["main"] != null) {
      if (json["main"] is List<dynamic>) {
        json["main"].forEach((element) {
          result = new Map();
          fields.forEach((field) {
            if (element.containsKey(field["retrival_value"])) {
              result.putIfAbsent(field['name'],
                  () => element[field['retrival_value']].toString().trim());
            } else {
              result.putIfAbsent(field['name'], () => null);
            }
          });
          subInventory.add(result);
        });
   
      } else {
        result = new Map();
        fields.forEach((field) {
          if (json["main"].containsKey(field["retrival_value"])) {
            result.putIfAbsent(field['name'],
                () => json["main"][field['retrival_value']].toString().trim());
          } else {
            result.putIfAbsent(field['name'], () => null);
          }
        });
        subInventory.add(result);
      }
    } else {
      result = new Map();
      fields.forEach((field) {
        result.putIfAbsent(field['name'], () => null);
      });
      subInventory.add(result);
    }

    fieldsOver.forEach((fieldOver) {
      if (json[fieldOver["name"]] != null) {
        if (json[fieldOver["name"]] is List<dynamic>) {
          json[fieldOver["name"]].forEach((element) {
            result = new Map();
            if (element.containsKey(fieldOver["retrival_value"])) {
              result.update(
                  fieldOver['name'],
                  (dynamic) =>
                      element[fieldOver['retrival_value']].toString().trim());
            } else {
              result.update(fieldOver['name'], (dynamic) => null);
            }
            subInventory.add(result);
          });
        } else {
          if (json[fieldOver["name"]]
              .containsKey(fieldOver["retrival_value"])) {
            result.update(
                fieldOver['name'],
                (dynamic) => json[fieldOver["name"]]
                        [fieldOver['retrival_value']]
                    .toString()
                    .trim());
          }
        }
      }
    });

    logger.verbose(subInventory.toString());

    return subInventory;
  }


  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByGrep(
    List<dynamic> fields, Map<String, dynamic> resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    Map<String, dynamic> json = new Map();

    resultCommand.keys.forEach((element) {
      try {
        json[element] = resultCommand[element]['result'];
      } catch (e) {
        logger.verbose("Next Grep object won't be well formated!");
      }
    });

    json.forEach((key, value) {
      var lines = value.split("\n").toList();

      for (var line in lines) {
        for (var field in fields) {
          String grep = field['retrival_value'];
          if (line.contains(grep)) {
            subInventory.putIfAbsent(field['name'],
                () => line.substring(line.indexOf(grep) + grep.length + 1));
          }
        }
      }
    });

    return subInventory;
  }

  String? getResult(String type, String result, retrivalValue) {
    switch (type) {
      case "JSON":
        var json = this.formatJson(result);
        return json[retrivalValue];

      case "PTXT":
        var txt = result.split("\n").toList();
        int line = int.parse(retrivalValue);
        return txt[line - 1];

      case "REGX":
        var lines = result.split("\n").toList();
        var regex = RegExp(retrivalValue);
        for (var line in lines) {
          if (regex.hasMatch(line)) {
            var match = regex.firstMatch(line);
            return match!.group(1);
          }
        }

        break;
      case "GREP":
        var lines = result.split("\n").toList();
        String grep = retrivalValue;
        for (var line in lines) {
          if (line.contains(grep)) {
            return line.substring(line.indexOf(grep) + grep.length + 1);
          }
        }

        break;
      default:
        return "null";
    }
    return null;
  }
}
