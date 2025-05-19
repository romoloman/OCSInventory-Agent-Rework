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

// External package imports
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:sprintf/sprintf.dart';

// Core imports
import 'package:ocs_agent/core/log.dart';
import 'package:ocs_agent/core/inventory/linux/commands.dart';

// Common imports
import 'package:ocs_agent/core/common/files_utils.dart';
import 'package:ocs_agent/core/common/json_utils.dart';

class BaseLinux {
  late Logger logger;
  late LinuxCommand linuxCommand;
  late FilesUtils filesUtils;
  late JsonUtils jsonUtils;
  final String serialFileName = "/serialNumber.json";

  /// Constructor
  BaseLinux(Logger logger, LinuxCommand linuxCommand, FilesUtils filesUtils,
      JsonUtils jsonUtils) {
    this.logger = logger;
    this.linuxCommand = linuxCommand;
    this.filesUtils = filesUtils;
    this.jsonUtils = jsonUtils;
  }

  ///This fonction return the body for to asset/bases
  dynamic getBody() async {

    logger.info(this.runtimeType.toString(), "Platform: LINUX");

    logger.info(this.runtimeType.toString(), "Retrieving OS body...");

    dynamic getOSRelease =
        (await linuxCommand.readFile("/etc/os-release", true))["value"]
            .toString()
            .split("\n");
    Map<String, String> osRelease = {};
    for (final info in getOSRelease) {
      RegExp exp = RegExp(r'(?<key>[\S]+?)="(?<value>[\S\s]+?)"');
      RegExpMatch? match = exp.firstMatch(info);
      if (match != null) {
        final entry = <String, String>{
          match.namedGroup("key").toString():
              match.namedGroup("value").toString()
        };
        osRelease.addEntries(entry.entries);
      }
    }

    dynamic getHostnamectl =
        (await linuxCommand.commandShell("hostnamectl", true))["value"]
            .toString()
            .split("\n");
    Map<String, String> hostnamectl = {};
    for (final info in getHostnamectl) {
      RegExp exp = RegExp(r'(?<key>[^\n][\S\s]+?): (?<value>[\S\s][^\n]+)');
      RegExpMatch? match = exp.firstMatch(info);
      if (match != null) {
        final entry = <String, String>{
          match.namedGroup("key").toString().trim():
              match.namedGroup("value").toString()
        };
        hostnamectl.addEntries(entry.entries);
      }
    }

    dynamic interfaces = (await linuxCommand.commandShell(
            "ip route show default", true))["value"]
        .toString()
        .split("\n");

    String? macAddress;
    for (final route in interfaces) {
      if (route.isNotEmpty) {
        dynamic interface = route.split(" ")[4];
        dynamic getMacAddress = (await linuxCommand.commandShell(
                "ip link show $interface", true))["value"]
            .toString();
        RegExp exp = RegExp(r'link\/ether (?<mac>[\S\s]+?) ');
        RegExpMatch? match = exp.firstMatch(getMacAddress);
        if (match != null) {
          macAddress = match.namedGroup("mac")?.trim();
          if (macAddress != null) {
            break;
          }
        }
      }
    }

    if (macAddress == null) {
      logger.error(this.runtimeType.toString(), "No valid MAC address found.");
      return null;
    }

    // Get name
    String name = (await linuxCommand.commandShell("hostname", true))["value"]
        .toString()
        .trim();

    dynamic body = ({
      "name": name,
      "description": osRelease["PRETTY_NAME"].toString() +
          " " +
          hostnamectl["Architecture"].toString(),
      "serial": await _getSerialNumber(name, macAddress),
      "osname": osRelease["NAME"].toString(),
      "osversion": osRelease["VERSION_ID"].toString(),
      "uuid": await _getUUID(name, macAddress),
      "srcip": (await linuxCommand.commandShell("hostname -I", true))["value"]
          .toString()
          .split(" ")[0],
      "srcmac": macAddress,
      "domain": (await linuxCommand.commandShell("hostname -d", true))["value"]
          .toString(),
    });

    logger.info(this.runtimeType.toString(), "OS body retrieved successfully.");

    return body;
  }

  /// Get UUID or generate one if not available and save it in a uuid file
  Future<String> _getUUID(String name, String macAddress) async {
    String uuid = (await linuxCommand.commandShell(
            "sudo dmidecode -s system-uuid", true))["value"]
        .toString();

    if (uuid == "") {
      String containerFileName = sprintf('%s.json', ["generated_uuid"]);
      File containerLinuxFile = File(containerFileName);
      if (!containerLinuxFile.existsSync()) {
        containerLinuxFile.createSync(recursive: true);
        containerLinuxFile.writeAsStringSync("{}");
      }
      Map<String, dynamic> containerLinux =
          jsonUtils.getContentFromFile(containerLinuxFile);

      if (containerLinux.isNotEmpty &&
          containerLinux.containsValue(name) &&
          containerLinux.containsValue(macAddress)) {
        uuid = containerLinux["uuid"];
        logger.info(this.runtimeType.toString(), "UUID file found.");
      } else {
        logger.info(
            this.runtimeType.toString(), "No system UUID, generating new one.");
        uuid = (await linuxCommand.commandShell("uuidgen", true))["value"]
            .toString();
        dynamic baseAdded = {};
        baseAdded["name"] = name;
        baseAdded["uuid"] = uuid;
        baseAdded["MAC"] = macAddress;

        JsonEncoder encoder = new JsonEncoder.withIndent('  ');
        String str = encoder.convert(baseAdded);
        FilesUtils filesUtils = new FilesUtils();
        filesUtils.rewriteFile(containerLinuxFile, str);
        logger.info(this.runtimeType.toString(), "New UUID saved to file.");
      }
    }
    return uuid;
  }

  Future<String> _getSerialNumber(String name, String macAddress) async{
    String serialResult = (await linuxCommand.commandShell(
              "sudo dmidecode -s system-serial-number", true))["value"].toString();

    String path = "/etc/ocsinventory-agent"+serialFileName;

    File fileSn = File(path);

    bool existFile = await fileSn.exists();

    if(serialResult == ""){
      logger.info(this.runtimeType.toString(),
          "No system serial number from dmidecode, checking serial number file...");
      if(!existFile){
        logger.info(this.runtimeType.toString(),
            "Serial number file not found, generating new serial number.");
        filesUtils.writeFile(fileSn, serialResult);
      }else {
        var read = await linuxCommand.readFile(path,false);
        serialResult = read["value"].toString();
        logger.info(this.runtimeType.toString(), "Serial number file found.");
      }
    }
    return serialResult;
  }

  String _randNumbers(){
    String result = "";

    for(int i = 0; i < 10; i++){
      result += Random().nextInt(10).toString();
    }
    return result;
  }

}
