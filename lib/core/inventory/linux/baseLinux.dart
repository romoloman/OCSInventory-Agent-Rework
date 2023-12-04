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

import 'package:ocs_agent/core/api.dart' as api;
import 'package:ocs_agent/core/inventory/linux/commands.dart' as command;

///This fonction return the body for to asset/bases
dynamic getBody() async {
  var linuxCommand = new command.LinuxCommand();
  var agent = new api.Api();

  agent.logger.info("Plateform: LINUX");

  agent.logger.info("Getting OS body...");

  dynamic interface =
      (await linuxCommand.commandShell("ip route show default", true))
          .split(" ")[4];

  dynamic body = ({
    "name": await linuxCommand.commandShell("uname -n", true),
    "description": await linuxCommand.commandShell("uname -m", true),
    "serial": await linuxCommand.commandShell(
        "sudo dmidecode -s system-serial-number", true),
    "osname": await linuxCommand.commandShell("uname -o", true),
    "osversion": await linuxCommand.commandShell("uname -v", true),
    "uuid":
        await linuxCommand.commandShell("sudo dmidecode -s system-uuid", true),
    "srcip":
        (await linuxCommand.commandShell("hostname -I", true)).split(" ")[0],
    "srcmac":
        await linuxCommand.readFile("/sys/class/net/$interface/address", true),
    "domain": await linuxCommand.commandShell("domainname", true)
  });

  agent.logger.info("OS body has been retrieved!");

  return body;
}
