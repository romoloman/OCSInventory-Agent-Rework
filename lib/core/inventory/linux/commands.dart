import 'dart:io';

class LinuxCommand {
  Future<String> commandShell(String commandLine) async {
    List<String> args = commandLine.split(" ");
    String command = args[0];
    args.removeAt(0);
    if (args == null) {
      args = [];
    }

    var process = await Process.run(command, args);

    return process.stdout;
  }

  Future<String> readFile(String path) async {
    var process = await Process.run("cat", [path]);

    return process.stdout;
  }
}