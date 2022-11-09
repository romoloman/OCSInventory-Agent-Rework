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

import 'package:ocs_agent/core/inventory/linux/commands.dart';

/// Format command result by type for Linux.
class LinuxFormat {
  LinuxCommand linuxCommand;

  /// Constructor.
  LinuxFormat() {
    this.linuxCommand = new LinuxCommand();
  }

  /// get result of [resultCommand] for each [fields].
  List<dynamic> getByArray(List<dynamic> fields, Map<String, dynamic> resultCommand) {
    List<Map<String, dynamic>> result = this.formatArray(resultCommand['main']['result']);
    List<dynamic> inventory = [];

    result.forEach((element) {
      Map<String, dynamic> subInventory = new Map();

      print(result);

      for (var field in fields) {
        if (resultCommand.containsKey(field['name'])) {
          subInventory.putIfAbsent(field['name'], () => this.getResult(field['retrival_output'], resultCommand[field['name']]['result'], field['retrival_value']));
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
  Map<String, dynamic> getByJson(List<dynamic> fields, Map<String, dynamic> resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var json = this.formatJson(resultCommand['main']['result']);

    for (var field in fields) {
      if (resultCommand.containsKey(field['name'])) {
        subInventory.putIfAbsent(field['name'], () => this.getResult(field['retrival_output'], resultCommand[field['name']]['result'], field['retrival_value']));
      } else {
        subInventory.putIfAbsent(field['name'], () => json[field['retrival_value']]);
      }
    }
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  Future<Map<String, dynamic>> getByPtxt(List<dynamic> fields, Map<String, dynamic> resultCommand) async {
    Map<String, dynamic> subInventory = new Map();
    var txt = resultCommand['main']['result'].split("\n").toList();

    for (var field in fields) {
      if (resultCommand.containsKey(field['name'])) {
        subInventory.putIfAbsent(field['name'], () => this.getResult(field['retrival_output'], resultCommand[field['name']]['result'], field['retrival_value']));
      } else {
        int line = int.parse(field['retrival_value']);
        subInventory.putIfAbsent(field['name'], () => txt[line - 1]);
      }
    }
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByRegx(List<dynamic> fields, Map<String, dynamic> resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var lines = resultCommand['main']['result'].split("\n").toList();

    for (var line in lines) {
      for (var field in fields) {
        if (resultCommand.containsKey(field['name'])) {
          subInventory.putIfAbsent(field['name'], () => this.getResult(field['retrival_output'], resultCommand[field['name']]['result'], field['retrival_value']));
        } else {
          var regex = RegExp(field['retrival_value']);
          if (regex.hasMatch(line)) {
            var match = regex.firstMatch(line);
            subInventory.putIfAbsent(field['name'], () => match.group(1));
          }
        }
      }
    }
    return subInventory;
  }

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByGrep(List<dynamic> fields, Map<String, dynamic> resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var lines = resultCommand['main']['result'].split("\n").toList();

    for (var line in lines) {
      for (var field in fields) {
        if (resultCommand.containsKey(field['name'])) {
          subInventory.putIfAbsent(field['name'], () => this.getResult(field['retrival_output'], resultCommand[field['name']]['result'], field['retrival_value']));
        } else {
          var grep = field['retrival_value'];
          if (line.contains(grep)) {
            subInventory.putIfAbsent(field['name'], () => line.substring(line.indexOf(grep) + grep.length +1));
          }
        }
      }
    }
    return subInventory;
  }

  String getResult(String type, String result, retrivalValue) {
    switch (type) {
        case "JSON":
          var json = this.formatJson(result);
          return json[retrivalValue];

          break;
        case "PTXT":
          var txt = result.split("\n").toList();
          int line = int.parse(retrivalValue);
          return txt[line - 1];

          break;
        case "REGX":
          var lines = result.split("\n").toList();
          var regex = RegExp(retrivalValue);
          for (var line in lines) {
            if (regex.hasMatch(line)) {
              var match = regex.firstMatch(line);
              return match.group(1);
            }
          }

          break;
        case "GREP":
          var lines = result.split("\n").toList();
          var grep = retrivalValue;
          for (var line in lines) {
            if (line.contains(grep)) {
              return line.substring(line.indexOf(grep) + grep.length +1);
            }
          }

          break;
        default:
          return "null";
          break;
      }
  }

  /// Format [result] text to a list of json.
  List<Map<String, dynamic>> formatArray(String result) {
    List<String> list = result.split("\n");
    String headerLine = list[0];
    list.removeAt(0);
    List<String> listIndex = headerLine.split(" ");
    listIndex.removeWhere((element) => element == "");
    Map<String, int> mapIndex = new Map<String, int>();
    List<int> listLines = [];
    List<Map<String, dynamic>> returnValue = [];

    int max = 0;
    listIndex.forEach((element) {
      int index = headerLine.indexOf(element, max);
      max = index;
      mapIndex.putIfAbsent(element, () => index);
      listLines.add(index);
    });

    list.forEach((element) {
      Map<String, dynamic> lineJson = new Map<String, dynamic>();
      print(element);
      print(mapIndex);
      mapIndex.forEach((key, value) {
        int start = listLines[listLines.indexOf(value)];
        int after;
        if (listLines.indexOf(value)+1 >= listLines.length) {
          after = null;
        } else {
          after = listLines[listLines.indexOf(value)+1];
        }
        String lineValue = element.substring(start, after);
        lineValue = lineValue.replaceAll(new RegExp(r'[\s]+$'), '');

        lineJson.putIfAbsent(key, () => lineValue);
      });
      returnValue.add(lineJson);
    });

    return returnValue;
  }

  /// format result [txt] to json.
  Map<String, dynamic> formatJson(String txt) {
    String json = "{\n";

    var list = txt.split("\n");
    list.removeWhere((element) => element == "");
    list.removeWhere((element) => element == "{");
    list.removeWhere((element) => element == "}");

    int n = 1;

    list.forEach((element) {
      //element = element.replaceAll(new RegExp(r"^ *"), '');
      element = element.replaceAll(new RegExp(r"^\s*"), '');

      var list2 = element.split(":");

      if (list2.asMap().containsKey(1)) {
        //list2[1] = list2[1].replaceAll(new RegExp(r"^ *"), '');
        list2[1] = list2[1].replaceAll(new RegExp(r"^\s*"), '');
        list2[1] = list2[1].replaceAll(new RegExp(r"\s*$"), '');

        String sep1;
        String sep2;

        if (list2[0].contains("\"")) {
          sep1 = "";
        } else {
          sep1 = "\"";
        }

        if (list2[1].contains("\"")) {
          sep2 = "";
        } else {
          sep2 = "\"";
        }

        if (n < list.length) {
          json += sep1 + list2[0] + "$sep1: $sep2" + list2[1] + "$sep2,\n";
        } else {
          json += sep1 + list2[0] + "$sep1: $sep2" + list2[1] + "$sep2\n";
        }
      }
      n++;
    });
    json += "}";

    return jsonDecode(json);
  }
}
