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

import 'dart:io' show Platform;

import 'package:sprintf/sprintf.dart';

import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/deployment.dart';
import 'package:ocs_agent/core/inventory.dart';

import 'package:ocs_agent/core/inventory/linux/baseLinux.dart' as baseLinux;
import 'package:ocs_agent/core/inventory/macos/baseMacOS.dart' as baseMacOS;
import 'package:ocs_agent/core/inventory/windows/baseWindows.dart'
    as baseWindows;

/// In this main section we send the [body] to the asset/bases endpoint
Future<void> main(List<String> args) async {
  // Initiate modules
  Deployment deployment = new Deployment();
  Inventory inventory = new Inventory();
  Config config = new Config();
  Logger logger = new Logger();

  // Get the agent execution mode
  Map<int, String> enumMode = {
    0: "Remote with template",
    1: "Remote without template",
    2: "Local with template",
    3: "Local without template",
  };
  logger.info(
      sprintf("Starting agent in %s mode...", [enumMode[inventory.getMode()]]));

  // Get the OS body
  var body, os;
  if (Platform.isLinux) {
    body = await baseLinux.getBody();
    os = "LIN";
  } else if (Platform.isMacOS) {
    body = await baseMacOS.getBody();
    os = "MAC";
  } else if (Platform.isWindows) {
    body = await baseWindows.getBody();
    os = "WIN";
  } else {
    logger.error(
        "OS does not match any of the supported OSs! (Check Plateform class return)");
  }

  if (inventory.getMode() == 0 || inventory.getMode() == 1) {
    if (await inventory.checkApi()) {
      // Inventory process
      await inventory.checkInventoryExist(body);
      await inventory.checkAndApplyConfig();
      await inventory.sendRemoteBaseInventory(body);
      if (inventory.getMode() == 0) {
        await inventory.sendRemoteTemplateInventory(body);
      }

      // Deployment process
      dynamic deploymentMode = config.getCoreConfig("deployment", "enabled");
      if (deploymentMode == 1) {
        if (await deployment.checkConfig()) {
          if (await deployment.checkDownload(inventory.assetID)) {
            if (await deployment.getActions(inventory.assetID)) {
              await deployment.executeActions(os, inventory.assetID);
            }
          }
        }
      }
    }
  } else if (inventory.getMode() == 2 || inventory.getMode() == 3) {
    inventory.sendLocalBaseInventory(body);
    if (inventory.getMode() == 2) {
      await inventory.sendLocalTemplateInventory();
    }
  }

  logger.info("Agent's process has ended!\n");
}
