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
import 'package:sprintf/sprintf.dart';

import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/common/http_utils.dart';

import 'package:ocs_agent/core/inventory/linux/commands.dart';
import 'package:ocs_agent/core/inventory/macos/commands.dart';
import 'package:ocs_agent/core/inventory/windows/commands.dart';

class Deployment {
  late Config config;
  late Logger logger;

  late HTTPUtils httpUtils;

  late var url;

  late List<dynamic> results;
  late Map<int, dynamic> actions;

  /// Constructor.
  Deployment() {
    this.config = new Config();
    this.logger = new Logger();

    this.httpUtils = new HTTPUtils();

    this.url = config.getInventoryConfig("url");

    this.actions = new Map();
  }

  /// Check if there is packages to download.
  Future<bool> checkDownload(int assetID) async {
    logger.info("Enabling deployment module...");
    var response = await httpUtils.get(
        "checkDownload",
        Uri.parse(url + "/deployment/results/?asset=$assetID&status=0"),
        httpUtils.getHeader(config));
    logger.verbose(response["message"]);
    if (response["status_code"] == 200 &&
        jsonDecode(response["body"]).isNotEmpty) {
      logger.info("Assigned packages found!");
      results = jsonDecode(response["body"]);
      for (var element in results) {
        var responseNotified = await httpUtils.patch(
            "executeActions",
            Uri.parse(
                url + "/deployment/results/" + element["id"].toString() + "/"),
            httpUtils.getHeader(config),
            "{\"comment\": \"Notified\"}");
        logger.verbose(responseNotified["message"]);
      }
      return true;
    } else {
      logger.info("Any package has been found on the server.");
      return false;
    }
  }

  /// Get actions from assigned packages.
  Future<bool> getActions(int assetID) async {
    logger.info("Collecting actions...");
    for (var element in results) {
      try {
        var response = await httpUtils.get(
            "getActions",
            Uri.parse(url +
                "/deployment/actions/?package=" +
                element["package"].toString()),
            httpUtils.getHeader(config));
        logger.verbose(response["message"]);
        if (response["status_code"] == 200) {
          actions.putIfAbsent(element["package"], () => response["body"]);
          logger.serverLogger(
              assetID,
              7,
              "Actions collected on package " +
                  element["package"].toString() +
                  ".");
        } else {
          logger.error("Can't collect actions from the server.");
          logger.serverLogger(
              assetID,
              8,
              "Can't collect actions from the server for the package " +
                  element["package"].toString() +
                  ".");
          return false;
        }
      } catch (exception) {
        logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
        return false;
      }
    }
    logger.info("Actions collected");
    return true;
  }

  /// Execute actions from assigned packages.
  Future<void> executeActions(String os, int assetID) async {
    logger.info("Executing actions...");
    for (var element in actions.values) {
      int id = 0;
      for (var action in jsonDecode(element)) {
        id = action["package"];
        logger.verbose(action.toString());
        if (checkFileExist(action)) {
          switch (action["action_type"]) {
            case "STORE":
              await storeFile(action["package"], action["file"]);
              break;
            case "LAUNCH":
              await launchFile(
                  os, action["package"], action["command"], action["file"]);
              break;
            default:
              logger.error("Canno't read correctly the action type!");
              logger.serverLogger(
                  assetID,
                  8,
                  "Can't get type from the action " +
                      action["name"].toString() +
                      ".");
              break;
          }
        } else {
          await executeCommand(os, action["package"], action["command"]);
        }
      }
      try {
        var responseSuccess = await httpUtils.patch(
            "executeActions",
            Uri.parse(url + "/deployment/results/$id/"),
            httpUtils.getHeader(config),
            "{\"status\": 1, \"comment\": \"Success\"}");
        logger.verbose(responseSuccess["message"]);
        if (responseSuccess["status_code"] == 200) {
          logger.info("Package $id was completed successfully!");
        }
      } catch (exception) {
        logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
      }
    }
  }

  /// Check if there is a specified file for the action
  bool checkFileExist(Map<String, dynamic> action) {
    if (action["file"] != null) {
      logger.info("File found in the action " + action["name"] + ".");
      return true;
    } else {
      logger.info("Any file found in the action " +
          action["name"] +
          ". Starting directly the command...");
      return false;
    }
  }

  /// Execute the action command.
  Future<void> executeCommand(
      String os, int package, String actionCommand) async {
    Map<String, dynamic> variables = {
      "\$AGENT_PATH":
          Directory.current.toString().substring(11, null).replaceAll("'", "") +
              "/" +
              config.getInventoryConfig("data_dir"),
      "\$PACKAGE": package.toString()
    };
    variables.keys.forEach((key) {
      actionCommand = actionCommand.replaceAll(key, variables[key]);
    });
    logger.verbose(actionCommand);
    switch (os) {
      case "LIN":
        var command = new LinuxCommand();
        String result = await command.commandShell(actionCommand, true);
        logger.verbose(result);
        break;
      case "MAC":
        var command = new MacOSCommand();
        String result = await command.commandShell(actionCommand, true);
        logger.verbose(result);
        break;
      case "WIN":
        var command = new WindowsCommand();
        String result = await command.commandPowershell(actionCommand, true);
        logger.verbose(result);
        break;
      default:
        logger.error(
            "OS does not match any of the supported OSs! (Check Plateform class return)");
        break;
    }
  }

  /// Only store the file without execution
  Future<void> storeFile(int package, String filePath) async {
    logger.info("Downloading and storing file...");
    var request = await HttpClient().getUrl(Uri.parse(filePath));
    var response = await request.close();
    var packageDirectory = Directory(
        config.getInventoryConfig("data_dir") + "/" + package.toString());
    if (!packageDirectory.existsSync()) {
      packageDirectory.createSync(recursive: true);
    }
    response.pipe(File(config.getInventoryConfig("data_dir") +
            "/" +
            package.toString() +
            "/" +
            filePath.split("/").last)
        .openWrite());
    request.close();
    logger.info("File downloaded and stored!");
  }

  /// Store the specified file and execute it.
  Future<void> launchFile(
      String os, int package, String actionCommand, String filePath) async {
    await storeFile(package, filePath);
    await executeCommand(os, package, actionCommand);
  }
}
