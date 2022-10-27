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
  List<dynamic> getByArray(List<dynamic> fields, String resultCommand) {
    List<String> list = resultCommand.split("\n");
    list.removeAt(0);
    List<dynamic> inventory = [];

    list.forEach((element) {
      var list2 = element.split(" ");
      list2.removeWhere((element2) => element2 == "");
      Map<String, dynamic> subInventory = new Map();

      for (var field in fields) {
        int index = int.parse(field["retrival_value"]);

        if (list2.asMap().containsKey(index)) {
          subInventory.putIfAbsent(field['name'], () => list2[index]);
        } else {
          subInventory.putIfAbsent(field['name'], () => "null");
        }
      }
      inventory.add(subInventory);
    });
    return inventory;
  }

  /// get result of [resultCommand] for each [fields].
  Map<String, dynamic> getByJson(List<dynamic> fields, String resultCommand) {
    Map<String, dynamic> subInventory = new Map();
    var json = this.formatJson(resultCommand);

    for (var field in fields) {
      subInventory.putIfAbsent(field['name'], () => json[field['retrival_value']]);
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
