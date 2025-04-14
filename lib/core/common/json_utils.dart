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

import 'dart:io';
import 'dart:convert';

/// functions utils for json management.
class JsonUtils {
  /// Return all Json data from [file].
  dynamic getContentFromFile(File file) {
    try {
      var jsonContent = file.readAsStringSync();
      var json = jsonDecode(jsonContent);
      return json;
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Return specific [key] from Json [file].
  dynamic getContentFromFileByKey(File file, String key) {
    try {
      var jsonContent = file.readAsStringSync();
      Map<String, dynamic> json = jsonDecode(jsonContent);
      return json[key];
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Return specific [key] from Json [str].
  dynamic getContentFromStringByKey(String str, String key) {
    try {
      Map<String, dynamic> json = jsonDecode(str);
      return json[key];
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Set new [_value] from [_index] in Json [file].
  String setContentFromFile(File file, String _index, dynamic _value) {
    var jsonContent = file.readAsStringSync();
    Map<String, dynamic> json = jsonDecode(jsonContent);
    json.forEach((key, value) {
      if (key == _index) {
        json[key] = _value;
      }
    });

    return serializeJson(file, json);
  }

  /// Function to replace single backslashes with double backslashes on windows
  String escapeBackslashes(String input) {
    return input.replaceAllMapped(
        RegExp(r'(?<!\\)(\\)(?!\\)'), (match) => '\\\\');
  }

  /// Serialize and write [file] with [json].
  String serializeJson(File file, Map<String, dynamic> json) {
    try {
      String str = jsonEncode(json);
      return str;
    } catch (e) {
      print(e);
      return "";
    }
  }
}