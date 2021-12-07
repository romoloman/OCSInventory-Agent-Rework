import 'dart:io';

/// Class for execute command on Mac.
class MacOSCommand {
  /// Execute [commandLine] to Shell.
  Future<String> commandShell(String commandLine) async {
    List<String> args = commandLine.split(" ");
    String command = args[0];
    args.removeAt(0);
    if (args == null) {
      args = [];
    }

    var process;
    await Process.run(command, args).then((value) => process = value.stdout);

    return process;
  }
}
