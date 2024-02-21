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

import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/inventory/windows/commands.dart' as command;

///This fonction return the body for the asset/bases
dynamic getBody() async {
  var windowsCommand = new command.WindowsCommand();
  var logger = new Logger();

  logger.info("Plateform: WINDOWS");

  logger.info("Getting OS body...");

  /// Command get the mac address list
  dynamic macAddr;
  macAddr = await windowsCommand.commandCmd("getmac", true);

  /// RegExp to match mac address
  RegExp regexMacAddr;
  regexMacAddr = RegExp(r"([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})");

  /// Get the Mac Address value
  var getMacAddr;
  getMacAddr = regexMacAddr.stringMatch(macAddr)!.trim();

  /// Command get to get the IP
  String ip;
  ip = await windowsCommand.commandCmd("ipconfig", true);

  /// RegExp to match IP
  RegExp regexIP;
  regexIP = RegExp(r"((?:[0-9]{1,3}\.){3}[0-9]{1,3})");

  /// Get IP value
  var getIP;
  getIP = regexIP.stringMatch(ip)!.trim();

  dynamic body = ({
    "name": await windowsCommand.commandCmd("hostname", true),
    "description": await windowsCommand.commandPowershell(
        "(Get-WMIObject -Class Win32_ComputerSystemProduct).Description", true),
    "serial": await windowsCommand.commandPowershell(
        "(Get-WMIObject win32_operatingsystem).SerialNumber", true),
    "osname": (await windowsCommand.commandPowershell(
            "(Get-WMIObject win32_operatingsystem).name", true))
        .split("|")[0],
    "osversion": await windowsCommand.commandPowershell(
        "(Get-WMIObject win32_operatingsystem).Version", true),
    "uuid": await windowsCommand.commandPowershell(
        "(Get-WMIObject -Class Win32_ComputerSystemProduct).UUID", true),
    "srcip": await getIP,
    "srcmac": await getMacAddr,
    "domain": await windowsCommand.commandPowershell(
        "(Get-WMIObject -Class Win32_ComputerSystem).Domain", true),
  });

  logger.info("OS body has been retrieved!");

  return body;
}
