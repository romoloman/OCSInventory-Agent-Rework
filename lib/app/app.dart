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

import 'package:ocs_agent/core/deployment.dart';
import 'package:ocs_agent/core/inventory.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/inventory/linux/baseLinux.dart' as baseLinux;
import 'package:ocs_agent/core/inventory/macos/baseMacOS.dart' as baseMacOS;
import 'package:ocs_agent/core/inventory/windows/baseWindows.dart'
    as baseWindows;

/// In this main section we send the [body] to the asset/bases endpoint
Future<void> main(List<String> args) async {
  // Initiate modules
  Deployment deployment = new Deployment();
  Inventory inventory = new Inventory();
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
  var body;
  if (Platform.isLinux) {
    body = await baseLinux.getBody();
  } else if (Platform.isMacOS) {
    body = await baseMacOS.getBody();
  } else if (Platform.isWindows) {
    body = await baseWindows.getBody();
  } else {
    logger.error(
        "OS does not match any of the supported OSs! (Check Plateform class return)");
  }

  // Inventory process
  if (inventory.getMode() == 0 || inventory.getMode() == 1) {
    if (await inventory.checkApi()) {
      await inventory.checkInventoryExist(body);
      await inventory.checkAndApplyConfig();
      await inventory.sendRemoteBaseInventory(body);
      if (inventory.getMode() == 0) {
        await inventory.sendRemoteTemplateInventory(body);
      }
    }
  } else if (inventory.getMode() == 2 || inventory.getMode() == 3) {
    inventory.sendLocalBaseInventory(body);
    if (inventory.getMode() == 2) {
      await inventory.sendLocalTemplateInventory();
    }
  }

  // deployment process
  if (inventory.getMode() == 0 || inventory.getMode() == 1) {
    logger.info("Enabling deployment module...");
    await deployment.checkDownload(inventory.assetID);
  }

  logger.info("Agent's process has ended!\n");
}
