import 'dart:convert';
import 'dart:io';

/// Class for execute command on Windows.
class WindowsCommand {
  /// Execute [commandLine] to cmd.
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

  /// Execute [commandLine] to powershell.
  Future<String> commandPowershell(String commandLine) async {
    List<String> args = commandLine.split(" ");
    String command = "powershell.exe";

    var process = await Process.run(command, args, stdoutEncoding: utf8);

    return process.stdout;
  }

  /// Return [path] file content.
  Future<String> readFile(String path) async {
    var process = await Process.run("type", [path]);

    return process.stdout;
  }
}