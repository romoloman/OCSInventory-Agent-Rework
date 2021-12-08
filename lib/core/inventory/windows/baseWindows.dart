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
  String getMacAddr;
  getMacAddr = regexMacAddr.stringMatch(macAddr);

  /// Command get the domain
  dynamic domain;
  domain = await windowsCommand.commandCmd("ipconfig");

  /// RegExp to match domain
  RegExp regexDomain;
  regexDomain = RegExp(
    r"([a-z]{0,15}\.[a-z]{0,4})$",
    multiLine: true,
  );

  /// Get domain value
  String getDomain;
  getDomain = regexDomain.stringMatch(domain);

  dynamic body = ({
    "name": await windowsCommand.commandCmd("hostname"),
    "srcmac": getMacAddr,
    "domain": getDomain,
  });

  return body;
}
