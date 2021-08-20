import 'dart:io';
import 'dart:convert';


/// functions utils for json management.
class JsonUtils{

  /// Return all Json data from [file].
  Map<String, dynamic> getContentFromFile(File file){
    try {
      var jsonContent = file.readAsStringSync();
      Map<String, dynamic> json = jsonDecode(jsonContent);
      return json;
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Return specific [key] from Json [file].
  dynamic getContentFromFileByKey(File file, String key){
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
  dynamic getContentFromStringByKey(String str, String key){
    try {
      Map<String, dynamic> json = jsonDecode(str);
      return json[key];
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Set new [_value] from [_index] in Json [file].
  String setContentFromFile(File file, String _index, String _value){
      var jsonContent = file.readAsStringSync();
      Map<String, dynamic> json = jsonDecode(jsonContent);
      json.forEach((key, value) {
        if (key == _index) {
          json[key] = _value;
        }
      });

      return serializeJson(file, json);
  }

  /// Serialize and write [file] with [json].
  String serializeJson(File file, Map<String, dynamic> json){
    String str = "";
    try {
      int n = 1;
      str += "{\n";
      json.forEach((key, value) {
        if (n >= json.length) {
          str += "\t\"$key\":\"$value\"\n";
        } else {
          str += "\t\"$key\":\"$value\",\n";
        }
        n++;
      });
      str += "}\n";
      return str;
    } catch(e) {
      print(e);
      return "";
    }
  }
}