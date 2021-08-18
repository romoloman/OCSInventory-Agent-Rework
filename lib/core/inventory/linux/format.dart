import 'dart:convert';

import 'package:ocs_agent/core/inventory/linux/commands.dart';

class LinuxFormat{
  LinuxCommand linuxCommand;

  LinuxFormat() {
    this.linuxCommand = new LinuxCommand();
  }

  Future<String> getbyArray(String command, String indexString, String type) async {
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

  Future<String> getbyJson(String command, String key, String type) async {
    String result = await linuxCommand.getResult(command, type);

    var json = this.formatJson(result);

    return json[key];
  }

  Future<String> getbyPtxt(String command, String lineString, String type) async {
    String result;
    int line = int.parse(lineString);
    
    result = await linuxCommand.getResult(command, type);

    var txt = result.split("\n").toList();

    return txt[line - 1];
  }

  Map<String, dynamic> formatJson(String txt){
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