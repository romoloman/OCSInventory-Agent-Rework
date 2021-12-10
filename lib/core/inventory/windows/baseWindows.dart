import 'package:ocs_agent/core/inventory/windows/commands.dart' as command;

///This fonction return the body for the asset/bases
dynamic getBody() async {
  command.WindowsCommand windowsCommand;
  windowsCommand = new command.WindowsCommand();

  /// Command get the mac address list
  dynamic macAddr;
  macAddr = await windowsCommand.commandCmd("getmac");

  /// RegExp to match mac address
  RegExp regexMacAddr;
  regexMacAddr = RegExp(r"([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})");

  /// Get the Mac Address value
  var getMacAddr;
  getMacAddr = regexMacAddr.stringMatch(macAddr);

  /// Command get to the domain
  dynamic domain;
  domain = await windowsCommand.commandCmd("ipconfig");

  /// RegExp to match domain
  RegExp regexDomain;
  regexDomain = RegExp(
    r"([a-z]{0,15}\.[a-z]{0,4})$",
    multiLine: true,
  );

  /// Get domain value
  var getDomain;
  getDomain = regexDomain.stringMatch(domain);

  /// Command get to get the IP
  String ip;
  ip = await windowsCommand.commandCmd("ipconfig");

  /// RegExp to match IP
  RegExp regexIP;
  regexIP = RegExp(r"((?:[0-9]{1,3}\.){3}[0-9]{1,3})");

  /// Get IP value
  var getIP;
  getIP = regexIP.stringMatch(ip);

  dynamic body = ({
    "name": await windowsCommand.commandCmd("hostname"),
    "description": await windowsCommand.commandPowershell(
        "(Get-WMIObject -Class Win32_ComputerSystemProduct).Description"),
    "serial": await windowsCommand.commandPowershell(
        "(Get-WMIObject win32_operatingsystem).SerialNumber"),
    "osname": (await windowsCommand
            .commandPowershell("(Get-WMIObject win32_operatingsystem).name"))
        .split("|")[0],
    "osversion": await windowsCommand
        .commandPowershell("(Get-WMIObject win32_operatingsystem).Version"),
    "uuid": await windowsCommand.commandPowershell(
        "(Get-WMIObject -Class Win32_ComputerSystemProduct).UUID"),
    "srcip": await getIP,
    "srcmac": await getMacAddr,
    "domain": await getDomain,
  });

  return body;
}
