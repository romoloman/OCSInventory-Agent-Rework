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
import 'package:ocs_agent/core/log.dart';

// Core imports
import 'package:ocs_agent/core/inventory/commands.dart';

class BaseMacOS {
  late Logger logger;
  late InventoryCommands inventoryCommands;

  /// Constructor
  BaseMacOS(this.logger, this.inventoryCommands);

  ///This fonction return the body for to asset/bases
  dynamic getBody() async {
    logger.info(this.runtimeType.toString(), "Platform: MACOS");

    logger.info(this.runtimeType.toString(), "Retrieving OS body...");

    /// This command [commandSerialUUID] display list Serial and UUID
    String commandSerialUUID;
    commandSerialUUID = (await inventoryCommands.processTarget(
            "BASH", "system_profiler SPHardwareDataType"))["value"]
        .toString();

    /// Regex to get [Serial]
    RegExp regexpSerial;
    regexpSerial = RegExp(r"(?<=Serial\sNumber\s\(system\):\s)\w+");
    String getSerial;
    getSerial = regexpSerial.stringMatch(commandSerialUUID)!.trim();

    /// Regex to get [UUID]
    RegExp regexpUUID;
    regexpUUID = RegExp(r"(?<=Hardware\sUUID:\s)(\w*-\w*-\w*-\w*-\w*)?\n");
    String getUUID;
    getUUID = regexpUUID.stringMatch(commandSerialUUID)!.trim();

    /// Get default route, regExp to Interface for [srcip] and [srcmac]
    String getDefaultRoute;
    getDefaultRoute = (await inventoryCommands.processTarget(
            "BASH", "route get default"))["value"]
        .toString();
    RegExp regexpInterface;
    regexpInterface = RegExp(r"(?<=interface:\s)\w*");
    String? getInterface;
    getInterface = regexpInterface.stringMatch(getDefaultRoute);

    /// Get domains list and apply this Regex to get domain
    String listDomains;
    listDomains =
        (await inventoryCommands.processTarget("BASH", "scutil --dns"))["value"]
            .toString();
    RegExp regexpDomain;
    regexpDomain = RegExp(r'(?<=search\sdomain\[0\]\s:\s)\w*.[a-z]{0,4}');
    String? getDomain;
    getDomain = regexpDomain.stringMatch(listDomains)!.trim();

    dynamic body = ({
      "name":
          (await inventoryCommands.processTarget("BASH", "hostname"))["value"]
              .toString(),
      "description":
          (await inventoryCommands.processTarget("BASH", "uname -m"))["value"]
              .toString(),
      "serial": getSerial,
      "osname": (await inventoryCommands.processTarget(
              "BASH", "sw_vers -productName"))["value"]
          .toString(),
      "osversion": (await inventoryCommands.processTarget(
              "BASH", "sw_vers -productVersion"))["value"]
          .toString(),
      "uuid": getUUID,
      "srcip": (await inventoryCommands.processTarget(
              "BASH", "ipconfig getifaddr $getInterface"))["value"]
          .toString(),
      "srcmac": (await inventoryCommands.processTarget(
              "BASH", "networksetup -getmacaddress $getInterface"))["value"]
          .toString()
          .split(" ")[2],
      "domain": getDomain
    });

    logger.info(this.runtimeType.toString(), "OS body retrieved successfully.");

    return body;
  }
}
