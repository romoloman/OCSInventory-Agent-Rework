import 'package:ocs_agent/core/inventory/linux/commands.dart' as command;

///This fonction return the body for to asset/bases
dynamic getBody() async {
  var linuxCommand = new command.LinuxCommand();

  dynamic interface =
      (await linuxCommand.commandShell("ip route show default")).split(" ")[4];

  dynamic body = ({
    "name": await linuxCommand.commandShell("uname -n"),
    "description": await linuxCommand.commandShell("uname -m"),
    "serial": await linuxCommand
        .commandShell("sudo dmidecode -s system-serial-number"),
    "osname": await linuxCommand.commandShell("uname -o"),
    "osversion": await linuxCommand.commandShell("uname -v"),
    "uuid": await linuxCommand.commandShell("sudo dmidecode -s system-uuid"),
    "srcip": (await linuxCommand.commandShell("hostname -I")).split(" ")[0],
    "srcmac": await linuxCommand.readFile("/sys/class/net/$interface/address"),
    "domain": await linuxCommand.commandShell("dnsdomainname")
  });

  return body;
}
