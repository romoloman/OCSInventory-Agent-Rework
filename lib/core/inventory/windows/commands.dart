import 'dart:io';

class WindowsCommand {
  Future<String> commandCmd(String commandLine) async {
    List<String> args = commandLine.split(" ");
    String command = args[0];
    args.removeAt(0);
    if (args == null) {
      args = [];
    }

    var process = await Process.run(command, args);

    return process.stdout;
  }
  
  Future<String> commandPowershell(String commandLine) async {
    List<String> args = commandLine.split(" ");
    String command = "powershell.exe";

    var process = await Process.run(command, args);

    return process.stdout;
  }

  Future<String> readFile(String path) async {
    var process = await Process.run("type", [path]);

    return process.stdout;
  }
}