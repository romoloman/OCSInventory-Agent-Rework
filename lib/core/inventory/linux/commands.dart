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

// External package imports
import 'dart:io';

// Core imports
import 'package:ocs_agent/core/log.dart';

/// Class for execute command on linux.
class LinuxCommand {
  late Logger logger;

  /// Constructor
  LinuxCommand(Logger logger) {
    this.logger = logger;
  }

  /// Execute [commandLine] to Shell.
  Future<Map<String, Object>> commandShell(
      String commandLine, bool normalization) async {
    List<String> args = commandLine.split(" ");
    String command = args[0];
    args.removeAt(0);
    if (args.isEmpty) {
      args = [];
    }

    Map<String, String> ev = new Map<String, String>();
    ev.putIfAbsent("LANG", () => "C");

    Map<String, Object> processData = {};

    try {
      // Attempt to run the command
      late ProcessResult process;
      if (normalization) {
        process = await Process.run(command, args, environment: ev);
        processData["value"] = await process.stdout.toString().trim();
      } else {
        process = await Process.run(command, args);
        processData["value"] = await process.stdout.toString();
      }

      if (process.exitCode != 0) {
        processData["value"] = "";
        processData["status"] = false;
        logger.error(this.runtimeType.toString(),
            "Executing command '$commandLine' - ${process.stderr}");
      } else {
        processData["status"] = true;
        logger.verbose(
            this.runtimeType.toString(), "Executed command: '$commandLine'");
        if (processData["value"] == "") {
          processData["value"] = "No output for command '$commandLine'.";
        }
      }
    } on ProcessException catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle the specific error
      logger.error(this.runtimeType.toString(),
          "This command '$command' could not be found : $e");
    } catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle other errors
      logger.error(this.runtimeType.toString(), 'An error occurred : $e');
    }

    return processData;
  }

  /// Return [path] file content.
  Future<Map<String, Object>> readFile(String path, bool normalization) async {
    Map<String, Object> processData = {};
    try {
      // Attempt to run the command
      var process = await Process.run("cat", [path]);
      if (normalization) {
        processData["value"] = await process.stdout.toString().trim();
      } else {
        processData["value"] = await process.stdout.toString();
      }

      if (process.exitCode != 0) {
        processData["value"] = "";
        processData["status"] = false;
        logger.error(this.runtimeType.toString(),
            "Executing file '$path' - ${process.stderr}");
      } else {
        processData["status"] = true;
        logger.verbose(
            this.runtimeType.toString(), "File executed successfully: $path");
        if (processData["value"] == "") {
          processData["value"] = "No output for file '$path'.";
        }
      }
    } on ProcessException catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle the specific error
      logger.error(this.runtimeType.toString(),
          "This file '$path' could not be found : $e");
    } catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle other errors
      logger.error(this.runtimeType.toString(), 'An error occurred : $e');
    }

    return processData;
  }

  /// Execute or read [command] in terms of [type].
  // ignore: missing_return
  Future<String?> getResult(String command, String type) async {
    switch (type) {
      case "FILE":
        return (await this.readFile(command, true))["value"].toString();
      case "CMD":
        return (await this.commandShell(command, true))["value"].toString();
      case "BASH":
        return (await this.commandShell(command, false))["value"].toString();
    }
    return null;
  }
}
