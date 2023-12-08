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

import 'package:ocs_agent/core/inventory/windows/commands.dart';

/// Format command result by type for Windows.
class WindowsFormat {
  late WindowsCommand windowsCommand;

  /// Constructor.
  WindowsFormat() {
    this.windowsCommand = new WindowsCommand();
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

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByJson(
      List<dynamic> fields, Map<String, dynamic> resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var json;
    bool isList = false;

    if (resultCommand['main']['options'] != null &&
        resultCommand['main']['options'].containsKey('is_list') &&
        resultCommand['main']['options']['is_list']) {
      isList = true;
    }
    try {
      if (resultCommand['main']['options'] != null &&
          resultCommand['main']['options'].containsKey('need_format') &&
          !resultCommand['main']['options']['need_format']) {
        json = jsonDecode(resultCommand['main']['result']);
      } else {
        json =
            this.formatJson(resultCommand.toString().replaceAll("\\", "\\\\"));
      }

      if (resultCommand['main']['options'] != null &&
          resultCommand['main']['options'].containsKey('submap')) {
        var maps = resultCommand['main']['options']['need_format'].split(',');
        if (isList) {
          json.forEach((element) {
            maps.forEach((element2) {
              element = element[element2];
            });
          });
        } else {
          maps.forEach((element) {
            json = json[element];
          });
        }
      }
    } catch (e) {
      json = null;
    }

    if (isList) {
      List<dynamic> subList = new List<dynamic>.empty();
      json.forEach((element) {
        Map<String, dynamic> subInventory2 = new Map();
        for (var field in fields) {
          try {
            subInventory2.putIfAbsent(
                field['name'], () => element[field['retrival_value']]);
          } catch (e) {}
        }
        subList.add(subInventory2);
      });
      subInventory.putIfAbsent("TEST", () => subList);
    } else {
      for (var field in fields) {
        try {
          subInventory.putIfAbsent(
              field['name'], () => json[field['retrival_value']]);
        } catch (e) {}
      }
    }

    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByPtxt(List<dynamic> fields, String resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var txt = resultCommand.split("\n").toList();

    for (var field in fields) {
      int line = int.parse(field['retrival_value']);
      subInventory.putIfAbsent(field['name'], () => txt[line - 1]);
    }
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByRegx(List<dynamic> fields, String resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var lines = resultCommand.split("\n").toList();

    for (var line in lines) {
      for (var field in fields) {
        var regex = RegExp(field['retrival_value']);
        if (regex.hasMatch(line)) {
          var match = regex.firstMatch(line);
          subInventory.putIfAbsent(field['name'], () => match!.group(1));
        }
      }
    }
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByGrep(List<dynamic> fields, String resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var lines = resultCommand.split("\n").toList();

    for (var line in lines) {
      for (var field in fields) {
        String grep = field['retrival_value'];
        if (line.contains(grep)) {
          subInventory.putIfAbsent(field['name'],
              () => line.substring(line.indexOf(grep) + grep.length + 1));
        }
      }
    }
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

  /// Format [result] text to a list of json.
  List<Map<String, dynamic>> formatArray(
      String result, Map<String, dynamic> options) {
    List<String> list = result.split("\n");

    String? headerLine;
    List<String>? listIndex;

    if (options.containsKey("use_index") && options['use_index']) {
      headerLine = list[0];
      list.removeAt(0);
      listIndex = headerLine.split(" ");
      listIndex.removeWhere((element) => element == "");
    } else {
      list.removeAt(0);
    }

    //print(headerLine);
    Map<String, int> mapIndex = new Map<String, int>();
    List<int> listLines = [];
    List<Map<String, dynamic>> returnValue = [];

    if (options.containsKey("use_index") && options['use_index']) {
      int max = 0;
      listIndex!.forEach((element) {
        int index = headerLine!.indexOf(element, max);
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
}
