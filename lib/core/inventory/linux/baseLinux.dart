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

import 'package:ocs_agent/core/inventory/linux/commands.dart' as command;

///This fonction return the body for to asset/bases
dynamic getBody() async {
  var linuxCommand = new command.LinuxCommand();

  dynamic getOSRelease =
      (await linuxCommand.readFile("/etc/os-release", true)).split("\n");
  Map<String, String> osRelease = {};
  for (final info in getOSRelease) {
    RegExp exp = RegExp(r'(?<key>[\S]+?)="(?<value>[\S\s]+?)"');
    RegExpMatch? match = exp.firstMatch(info);
    if (match != null) {
      final entry = <String, String>{
        match.namedGroup("key").toString(): match.namedGroup("value").toString()
      };
      osRelease.addEntries(entry.entries);
    }
  }

  dynamic getHostnamectl =
      (await linuxCommand.commandShell("hostnamectl", true)).split("\n");
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

  dynamic interface =
      (await linuxCommand.commandShell("ip route show default", true))
          .split(" ")[4];

  dynamic getMACAddress = await linuxCommand.commandShell(
      "ip link show " + interface.toString(), true);
  RegExp exp = RegExp(r'link\/ether (?<mac>[\S\s]+?) ');
  RegExpMatch? match = exp.firstMatch(getMACAddress);
  String macAddress =
      match![0].toString().substring(11, match[0].toString().length);

  dynamic body = ({
    "name": await linuxCommand.commandShell("hostname", true),
    "description": osRelease["PRETTY_NAME"].toString() +
        " " +
        hostnamectl["Architecture"].toString(),
    "serial": await linuxCommand.commandShell(
        "sudo dmidecode -s system-serial-number", true),
    "osname": osRelease["NAME"].toString(),
    "osversion": osRelease["VERSION_ID"].toString(),
    "uuid":
        await linuxCommand.commandShell("sudo dmidecode -s system-uuid", true),
    "srcip":
        (await linuxCommand.commandShell("hostname -I", true)).split(" ")[0],
    "srcmac": macAddress,
    "domain": await linuxCommand.commandShell("hostname -d", true)
  });

  return body;
}
