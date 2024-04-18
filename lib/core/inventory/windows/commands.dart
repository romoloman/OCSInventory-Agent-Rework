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

import 'dart:convert';
import 'dart:io';

import 'package:ocs_agent/core/log.dart';

/// Class for execute command on Windows.
class WindowsCommand {
  Logger logger = Logger();

  /// Execute [commandLine] to cmd.
  Future<Map<String, Object>> commandCmd(
      String commandLine, bool normalization) async {
    List<String> args = commandLine.split(" ");
    String command = args[0];
    args.removeAt(0);
    if (args.isEmpty) {
      args = [];
    }

    Map<String, Object> processData = {};
    try {
      // Attempt to run the command
      var process = await Process.run(command, args);
      if (normalization) {
        processData["value"] = await process.stdout.toString().trim();
      } else {
        processData["value"] = await process.stdout.toString();
      }

      if (process.exitCode != 0) {
        processData["value"] = "";
        processData["status"] = false;
        logger.error("Executing command $commandLine : ${process.stderr}");
      } else {
        processData["status"] = true;
        logger.verbose("Command executed: $commandLine");
        if (processData["value"] == "") {
          processData["value"] = "Command '$commandLine' has no output.";
        }
      }
    } on ProcessException catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle the specific error
      logger.error("This command '$command' could not be found : $e");
    } catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle other errors
      logger.error('An error occurred : $e');
    }

    return processData;
  }

  /// Execute [commandLine] to powershell.
  Future<Map<String, Object>> commandPowershell(
      String commandLine, bool normalization) async {
    List<String> args = commandLine.split(" ");
    String command = "powershell.exe";

    Map<String, Object> processData = {};
    try {
      // Attempt to run the command
      var process = await Process.run(command, args, stdoutEncoding: utf8);
      if (normalization) {
        processData["value"] = await process.stdout.toString().trim();
      } else {
        processData["value"] = await process.stdout.toString();
      }

      if (process.exitCode != 0) {
        processData["value"] = "";
        processData["status"] = false;
        logger.error("Executing command '$commandLine' - ${process.stderr}");
      } else {
        processData["status"] = true;
        logger.verbose("Command executed: $commandLine");
        if (processData["value"] == "") {
          processData["value"] = "Command '$commandLine' has no output.";
        }
      }
    } on ProcessException catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle the specific error
      logger.error("This command '$command' could not be found : $e");
    } catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle other errors
      logger.error('An error occurred : $e');
    }

    return processData;
  }

  /// Return [path] file content.
  Future<Map<String, Object>> readFile(String path, bool normalization) async {
    Map<String, Object> processData = {};
    try {
      // Attempt to run the command
      var process = await Process.run("type", [path]);
      if (normalization) {
        processData["value"] = await process.stdout.toString().trim();
      } else {
        processData["value"] = await process.stdout.toString();
      }

      if (process.exitCode != 0) {
        processData["value"] = "";
        processData["status"] = false;
        logger.error("Executing file '$path' - ${process.stderr}");
      } else {
        processData["status"] = true;
        logger.verbose("File executed successfully: $path");
        if (processData["value"] == "") {
          processData["value"] = "File '$path' has no output.";
        }
      }
    } on ProcessException catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle the specific error
      logger.error("This file '$path' could not be found : $e");
    } catch (e) {
      processData["value"] = "";
      processData["status"] = false;
      // Handle other errors
      logger.error('An error occurred : $e');
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
        return (await this.commandCmd(command, true))["value"].toString();
      case "PW":
        return (await this.commandPowershell(command, true))["value"]
            .toString();
    }
    return null;
  }
}
