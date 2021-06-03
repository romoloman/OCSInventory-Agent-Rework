import 'dart:io';
import 'dart:convert';


class JsonUtils{

  /// Return all Json data.
  Map<String, dynamic> getContent(File file){
    try {
      var jsonContent = file.readAsStringSync();
      Map<String, dynamic> json = jsonDecode(jsonContent);
      return json;
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Return specific value from Json key.
  dynamic getContentByKey(File file, String key){
    try {
      var jsonContent = file.readAsStringSync();
      Map<String, dynamic> json = jsonDecode(jsonContent);
      return json[key];
    } catch (e) {
      print(e);
      return null;
    }
  }

  /// Set new value from key in Json file.
  String setContent(File file, String _index, String _value){
      var jsonContent = file.readAsStringSync();
      Map<String, dynamic> json = jsonDecode(jsonContent);
      json.forEach((key, value) {
        if (key == _index) {
          json[key] = _value;
        }
      });

      return serializeJson(file, json);
  }

  /// Serialize and write Json.
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
    }
  }
}