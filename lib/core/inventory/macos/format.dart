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

  final Map<String, String> transcriptVariables = {
    "spext_incomplete": "incomplete",
    "spext_complete": "complete",
    "spext_no": "No",
    "spext_yes": "Yes",
    "spext_not_signed": "Not Signed",
    "spext_signed": "Signed",
  };

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
            // Check if the value is a transcript variable
            element[field['retrival_value']] = transcriptVariables.containsKey(
                    element[field['retrival_value']].toString().trim())
                ? transcriptVariables[
                    element[field['retrival_value']].toString().trim()]
                : element[field['retrival_value']];
            // Check if the value of element[field['retrival_value']] is a map
            if (element[field['retrival_value']] is Map) {
              element[field['retrival_value']].forEach((key, value) {
                // Add the sub element to this element
                element[key] = value;
              });
            }
            if (element[field['retrival_value']] is List) {
              element[field['retrival_value']].forEach((subElement) {
                subElement.forEach((key, value) {
                  // Add the sub element to this element
                  element[key] = value;
                });
              });
            }

            if (element.containsKey(field["retrival_value"])) {
              if (element[field["retrival_value"]] is! List &&
                  element[field["retrival_value"]] is! Map &&
                  element[field["retrival_value"]] != null) {
                result.putIfAbsent(field['name'],
                    () => element[field['retrival_value']].toString().trim());
              }
            } else {
              result.putIfAbsent(field['name'], () => null);
            }
          });
          subInventory.add(result);
        });
      } else {
        result = new Map();
        fields.forEach((field) {
          // Check if the value is a transcript variable
          json["main"][field['retrival_value']] =
              transcriptVariables.containsKey(
                      json["main"][field['retrival_value']].toString().trim())
                  ? transcriptVariables[
                      json["main"][field['retrival_value']].toString().trim()]
                  : json["main"][field['retrival_value']];

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
  List<dynamic> getByGrep(
      List<dynamic> fields, Map<String, dynamic> resultCommand) {
    List<dynamic> subInventory = new List.empty(growable: true);
    Map<String, dynamic> result = new Map();
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
            result.putIfAbsent(
                field['name'],
                () => line
                    .substring(line.indexOf(grep) + grep.length + 1)
                    .toString()
                    .trimLeft());
          }
        }
      }
    });
    subInventory.add(result);

    logger.verbose(subInventory.toString());
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  List<dynamic> getByRegx(
      List<dynamic> fields, Map<String, dynamic> resultCommand) {
    List<dynamic> subInventory = new List.empty(growable: true);
    Map<String, dynamic> result = new Map();
    var lines = resultCommand['main']['result'].split("\n").toList();

    if (resultCommand['main']['options'] != null &&
        resultCommand['main']['options'].containsKey('multiple') &&
        resultCommand['main']['options']['multiple']) {
      String regexSource = "";
      for (var field in fields) {
        regexSource = regexSource + field['retrival_value'];
      }

      var regex = RegExp(regexSource, multiLine: true);

      var matches =
          regex.allMatches(resultCommand['main']['result'].toString());

      for (var match in matches) {
        for (int i = 0; i < fields.length; i++) {
          result.putIfAbsent(
              fields.elementAt(i)['name'], () => match.group(i + 1));
        }
        subInventory.add(result);
        result = new Map();
      }
    } else {
      for (var line in lines) {
        for (var field in fields) {
          if (resultCommand.containsKey(field['name'])) {
            result.putIfAbsent(
                field['name'],
                () => this.getResult(
                    field['retrival_output'],
                    resultCommand[field['name']]['result'],
                    field['retrival_value']));
          } else {
            var regex = RegExp(field['retrival_value']);
            if (regex.hasMatch(line)) {
              var match = regex.firstMatch(line);
              result.putIfAbsent(field['name'], () => match!.group(1));
            }
          }
        }
      }
      subInventory.add(result);
    }

    logger.verbose(subInventory.toString());
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  List<dynamic> getByPtxt(
      List<dynamic> fields, Map<String, dynamic> resultCommand) {
    List<dynamic> subInventory = new List.empty(growable: true);
    Map<String, dynamic> result = new Map();
    var txt = resultCommand['main']['result'].split("\n").toList();

    for (var field in fields) {
      if (resultCommand.containsKey(field['name'])) {
        result.putIfAbsent(
            field['name'],
            () => this.getResult(
                field['retrival_output'],
                resultCommand[field['name']]['result'],
                field['retrival_value']));
      } else {
        int line = int.parse(field['retrival_value']);
        result.putIfAbsent(field['name'], () => txt[line - 1]);
      }
    }
    subInventory.add(result);

    logger.verbose(subInventory.toString());
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  List<dynamic> getByArray(
      List<dynamic> fields, Map<String, dynamic> resultCommand) {
    List<Map<String, dynamic>> result = this.formatArray(
        resultCommand['main']['result'], resultCommand['main']['options']);
    List<dynamic> inventory = [];
    result.forEach((element) {
      Map<String, dynamic> subInventory = new Map();

      for (var field in fields) {
        if (resultCommand.containsKey(field['name'])) {
          subInventory.putIfAbsent(
              field['name'],
              () => this.getResult(
                  field['retrival_output'],
                  resultCommand[field['name']]['result'],
                  field['retrival_value']));
        } else {
          String index = field["retrival_value"];
          if (element.containsKey(index)) {
            subInventory.putIfAbsent(field['name'], () => element[index]);
          } else {
            subInventory.putIfAbsent(field['name'], () => "null");
          }
        }
      }
      inventory.add(subInventory);
    });
    return inventory;
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

  /// format result [txt] to json.
  Map<String, dynamic> formatJson(String txt) {
    String json = "{\r\n";

    var list = txt.split("\r");
    list.removeWhere((element) => element == "");

    int n = 1;

    list.forEach((element) {
      element = element.replaceAll(new RegExp(r"^ *"), '');
      element = element.replaceAll(new RegExp(r"^\s*"), '');

      var list2 = element.split(":");

      if (list2.asMap().containsKey(1)) {
        list2[0] = list2[0].replaceAll(new RegExp(r" *$"), '');
        list2[0] = list2[0].replaceAll(new RegExp(r"\s*$"), '');
        list2[1] = list2[1].replaceAll(new RegExp(r"^ *"), '');
        list2[1] = list2[1].replaceAll(new RegExp(r"^\s*"), '');

        if (list2[1].isEmpty || list2[1] == "") {
          list2[1] = list2[0];
        }

        if (n < list.length) {
          json += "\"" + list2[0] + "\": \"" + list2[1] + "\",\r\n";
        } else {
          json += "\"" + list2[0] + "\": \"" + list2[1] + "\"\r\n";
        }
      }
      n++;
    });
    json += "}";

    return jsonDecode(json);
  }

  /// Format [result] text to a list of json.
  List<Map<String, dynamic>> formatArray(
      String result, Map<String, dynamic> options) {
    List<String> list = result.split("\n");

    late String headerLine;
    late List<String> listIndex;

    if (options.containsKey("use_index") && options['use_index']) {
      headerLine = list[0].replaceAll(":", "");
      list.removeAt(0);
      listIndex = headerLine.split(" ");
      listIndex.removeWhere((element) => element == "");
    } else {
      list.removeAt(0);
    }

    Map<String, int> mapIndex = new Map<String, int>();
    List<int> listLines = [];
    List<Map<String, dynamic>> returnValue = [];

    if (options.containsKey("use_index") && options['use_index']) {
      int max = 0;
      listIndex.forEach((element) {
        int index = headerLine.indexOf(element, max);
        max = index;
        mapIndex.putIfAbsent(element, () => index);
        listLines.add(index);
      });

      list.forEach((element) {
        Map<String, dynamic> lineJson = new Map<String, dynamic>();
        mapIndex.forEach((key, value) {
          int start = listLines[listLines.indexOf(value)];
          int? after;
          if (listLines.indexOf(value) + 1 >= listLines.length) {
            after = null;
          } else {
            after = listLines[listLines.indexOf(value) + 1];
          }
          String lineValue = element.substring(start, after);
          lineValue = lineValue.replaceAll(new RegExp(r'[\s]+$'), '');

          lineJson.putIfAbsent(key, () => lineValue);
        });
        returnValue.add(lineJson);
      });
    } else {
      list.forEach((element) {
        Map<String, dynamic> lineJson = new Map<String, dynamic>();
        var test = element.split(' ');
        test.removeWhere((element2) => element2 == "");
        int index = 0;
        test.forEach((element) {
          lineJson.putIfAbsent(index.toString(), () => element);
          index++;
        });
        returnValue.add(lineJson);
      });
    }

    return returnValue;
  }
}
