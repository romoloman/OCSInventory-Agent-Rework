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

import 'package:ocs_agent/core/inventory/macos/commands.dart';

class MacOSFormat {
  MacOSCommand macosCommand;

  MacOSFormat() {
    this.macosCommand = new MacOSCommand();
  }

  Future<String> getbyArray(String command, String indexString) async {
    return null;
  }

  Future<String> getbyJson(String command, String key) async {
    return null;
  }

  Future<String> getbyPtxt(String command, String lineString) async {
    return null;
  }

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
