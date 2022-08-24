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

import 'package:ocs_agent/core/api.dart' as api;

import 'package:ocs_agent/core/inventory/linux/baseLinux.dart' as baseLinux;

import 'package:ocs_agent/core/inventory/macos/baseMacOS.dart' as baseMacOS;

import 'package:ocs_agent/core/inventory/windows/baseWindows.dart' as baseWindows;

///in this main section we send the [body] to the asset/bases
void main(List<String> args) async {
  var sendBody = api.Api();

  sendBody.generateToken();

  sendBody.apiCheck();

  sendBody.getHeader();

  sendBody.getTemplate(sendBody.getIdTemplate());

  if (Platform.isMacOS) {
    sendBody.sendInventory(await baseMacOS.getBody());
  } else if (Platform.isLinux) {
    sendBody.sendInventory(await baseLinux.getBody());
  } else if (Platform.isWindows) {
    sendBody.sendInventory(await baseWindows.getBody());
  } else {
    sendBody.logger.error('Error Platform');
  }

  sendBody.getInventory();
}
