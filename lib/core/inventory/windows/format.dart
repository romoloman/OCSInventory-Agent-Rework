import 'dart:convert';

import 'package:ocs_agent/core/inventory/windows/commands.dart';

class WindowsFormat{
  WindowsCommand windowsCommand;

  WindowsFormat() {
    this.windowsCommand = new WindowsCommand();
  }

  Future<String> getbyArray(String command, String indexString, String type) async {
    String result;
    int index = int.parse(indexString);

    switch (type) {
      case "FILE":
        await windowsCommand.readFile(command).then((value) => result = value);
        break;
      case "PW":
        await windowsCommand.commandPowershell(command).then((value) => result = value);
        break;
      case "CMD":
        await windowsCommand.commandCmd(command).then((value) => result = value);
        break;
    }

    List<String> list = result.split("\r\n");
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
    String result;
    
    switch (type) {
      case "FILE":
        await windowsCommand.readFile(command).then((value) => result = value);
        break;
      case "PW":
        await windowsCommand.commandPowershell(command).then((value) => result = value);
        break;
      case "CMD":
        await windowsCommand.commandCmd(command).then((value) => result = value);
        break;
    }

    var json = this.FormatJson(result);

    return json[key];
  }

  Future<String> getbyPtxt(String command, String lineString, String type) async {
    String result;
    int line = int.parse(lineString);
    
    switch (type) {
      case "FILE":
        await windowsCommand.readFile(command).then((value) => result = value);
        break;
      case "PW":
        await windowsCommand.commandPowershell(command).then((value) => result = value);
        break;
      case "CMD":
        await windowsCommand.commandCmd(command).then((value) => result = value);
        break;
    }

    var txt = result.split("\r\n").toList();

    return txt[line - 1];
  }

  Map<String, dynamic> FormatJson(String txt){
    String json = "{\r\n";

    var list = txt.split("\r\n");
    print("TEST : $list");
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

        if (list2[1] == null || list2[1] == ""){
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