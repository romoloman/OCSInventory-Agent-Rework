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

  /// get array [indexString] of [command] by [type].
  // ignore: missing_return
  Future<String> getbyArray(
      String command, String indexString, String type) async {
    String result;
    int index = int.parse(indexString);

    result = await linuxCommand.getResult(command, type);

    List<String> list = result.split("\n");
    list.removeAt(0);

    list.forEach((element) {
      var list2 = element.split(" ");
      list2.removeWhere((element2) => element2 == "");

      if (list2.asMap().containsKey(index)) {
        return list2[index];
      } else {
        return null;
      }
    });
  }

  /// get Json [key] of [command] result in terms of [type].
  Future<String> getbyJson(String command, String key, String type) async {
    String result = await linuxCommand.getResult(command, type);

    var json = this.formatJson(result);

    return json[key];
  }

  /// Get text [lineString] of [command] result in term of [type].
  Future<String> getbyPtxt(
      String command, String lineString, String type) async {
    String result;
    int line = int.parse(lineString);

    result = await linuxCommand.getResult(command, type);

    var txt = result.split("\n").toList();

    return txt[line - 1];
  }

  /// format result [txt] to json.
  Map<String, dynamic> formatJson(String txt) {
    String json = "{\n";

    var list = txt.split("\n");
    list.removeWhere((element) => element == "");

    int n = 1;

    list.forEach((element) {
      //element = element.replaceAll(new RegExp(r"^ *"), '');
      element = element.replaceAll(new RegExp(r"^\s*"), '');

      var list2 = element.split(":");

      if (list2.asMap().containsKey(1)) {
        //list2[1] = list2[1].replaceAll(new RegExp(r"^ *"), '');
        list2[1] = list2[1].replaceAll(new RegExp(r"^\s*"), '');
        list2[1] = list2[1].replaceAll(new RegExp(r"\s*$"), '');

        if (n < list.length) {
          json += "\"" + list2[0] + "\": \"" + list2[1] + "\",\n";
        } else {
          json += "\"" + list2[0] + "\": \"" + list2[1] + "\"\n";
        }
      }
      n++;
    });
    json += "}";

    return jsonDecode(json);
  }
}
