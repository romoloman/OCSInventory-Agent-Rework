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

import 'package:ocs_agent/core/api.dart' as api;

import 'package:ocs_agent/core/inventory/linux/baseLinux.dart' as baseLinux;

import 'package:ocs_agent/core/inventory/macos/baseMacOS.dart' as baseMacOS;

import 'package:ocs_agent/core/inventory/windows/baseWindows.dart'
    as baseWindows;

/// In this main section we send the [body] to the asset/bases
void main(List<String> args) async {
  var agent = api.Api();

  Map<int, String> enumMode = {
    0: "Remote with template",
    1: "Remote without template",
    2: "Local with template",
    3: "Local without template",
  };

  int mode = agent.getMode();

  agent.logger.info(sprintf("Stating agent in %s mode...", [enumMode[mode]]));

  var body;

  if (Platform.isLinux) {
    body = await baseLinux.getBody();
  } else if (Platform.isMacOS) {
    body = await baseMacOS.getBody();
  } else if (Platform.isWindows) {
    body = await baseWindows.getBody();
  } else {
    agent.logger.error(
        "Can't define in which operating system you are using! (Check Plateform class return)");
  }

  if (mode == 0 || mode == 1) {
    if (await agent.apiCheck()) {
      await agent.checkAndApplyConfig();
      await agent.sendRemoteBaseInventory(body);
      if (mode == 0) {
        await agent.sendRemoteTemplateInventory(body);
      }
    }
  } else if (mode == 2 || mode == 3) {
    agent.sendLocalBaseInventory(body);
    if (mode == 2) {
      await agent.sendLocalTemplateInventory();
    }
  }

  agent.logger.info("Agent's process ends!");
}
