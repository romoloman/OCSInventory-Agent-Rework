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
import 'dart:convert';
import 'dart:io' show Platform, exit, stdout;
import 'package:sprintf/sprintf.dart';
import 'package:args/args.dart';

// Common imports
import 'package:ocs_agent/core/common/files_utils.dart';
import 'package:ocs_agent/core/common/http_utils.dart';
import 'package:ocs_agent/core/common/json_utils.dart';

// Core imports
import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/inventory/linux/baseLinux.dart';
import 'package:ocs_agent/core/inventory/linux/commands.dart';
import 'package:ocs_agent/core/inventory/linux/format.dart';

import 'package:ocs_agent/core/inventory/macos/baseMacOS.dart';
import 'package:ocs_agent/core/inventory/macos/commands.dart';
import 'package:ocs_agent/core/inventory/macos/format.dart';

import 'package:ocs_agent/core/inventory/windows/baseWindows.dart';
import 'package:ocs_agent/core/inventory/windows/commands.dart';
import 'package:ocs_agent/core/inventory/windows/format.dart';

// Modules imports
import 'package:ocs_agent/core/inventory.dart';
import 'package:ocs_agent/core/deployment.dart';

/// In this main section we send the [body] to the asset/bases endpoint
Future<void> main(List<String> args) async {
  // Initiate the parser for the arguments
  ArgParser parser = ArgParser();
  ArgResults allArgs;
  // Initiate main core
  late Config config;

  // Add the arguments options
  parser.addOption("log_file",
      abbr: "f",
      help: "Enalbe or disable the log file",
      valueHelp: "true/false",
      defaultsTo: "false");
  parser.addOption("mode",
      abbr: "m",
      help: "Agent execution mode",
      valueHelp:
          "0: Installer mode 1: Remote with template 2: Remote without template 3: Local with template 4: Local without template",
      defaultsTo: "1");
  parser.addOption("password",
      abbr: "p", help: "Password", valueHelp: "password", defaultsTo: "admin");
  parser.addOption("token",
      abbr: "t", help: "Token", valueHelp: "token", defaultsTo: "");
  parser.addOption("username",
      abbr: "u", help: "Username", valueHelp: "username", defaultsTo: "admin");
  parser.addOption("url",
      abbr: "s",
      help: "URL to the OCS server",
      valueHelp: "http://SERVER_IP:PORT",
      defaultsTo: "http://ocsinventory-server:port");
  parser.addOption("data_directory",
      abbr: "d",
      help: "Path to the inventory data",
      valueHelp: "/path_to_store_inventory_data/folder-name",
      defaultsTo: "inventory");
  parser.addOption("log_file_path",
      abbr: "l",
      help: "Path to the log file",
      valueHelp: "/path_to_store_log_file/file-name.log",
      defaultsTo: "ocs-agent.log");
  parser.addOption("log_level",
      abbr: "v",
      help: "Log level",
      valueHelp: "0: Error 1: Warning 2: Info 3: Verbose",
      defaultsTo: "2");
  parser.addFlag("help", abbr: "h", help: "Show this help", negatable: false);

  try {
    allArgs = parser.parse(args);
  } on ArgParserException catch (ex) {
    stdout.writeln("Failed while parsing arguments");

    stdout.writeln(ex.message);
    stdout.writeln(parser.usage);
    exit(1);
  } catch (ex) {
    stdout.writeln("Something went wrong while parsing arguments!");
    stdout.writeln(ex);
    stdout.writeln(parser.usage);
    exit(1);
  }

  if (allArgs.wasParsed("help")) {
    stdout.writeln(parser.usage);
    return;
  }

  late final String configDirectory;
  if (Platform.isLinux) {
    configDirectory = "/etc/ocsinventory-agent";
  } else if (Platform.isMacOS) {
    configDirectory = "/etc/ocsinventory-agent";
  } else if (Platform.isWindows) {
    configDirectory = "C:\\ProgramData\\Agent-OCS\\config";
  } else {
    stdout.writeln("Unsupported platform");
    exit(1);
  }

  Map<String, dynamic> invenroryConfigurations = {};
  invenroryConfigurations['log_file'] =
      await allArgs.option("log_file").toString();
  invenroryConfigurations['mode'] = await allArgs.option("mode").toString();
  invenroryConfigurations['password'] =
      await allArgs.option("password").toString();
  invenroryConfigurations['token'] = "";
  invenroryConfigurations['username'] =
      await allArgs.option("username").toString();
  invenroryConfigurations['url'] = await allArgs.option("url").toString();
  invenroryConfigurations['data_directory'] =
      await allArgs.option("data_directory").toString();
  invenroryConfigurations['log_file_path'] =
      await allArgs.option("log_file_path").toString();
  invenroryConfigurations['log_level'] = await allArgs.option("log_level").toString();

  config = await Config(
      configDirectory, jsonEncode(invenroryConfigurations).toString());

  // Iterate allArgs and update inventory config with the provided values
  if (allArgs.options.isNotEmpty) {
    invenroryConfigurations.forEach((key, value) {
      if (allArgs.wasParsed(key)) {
        config.updateInventoryConfig(key, allArgs.option(key).toString());
      }
    });
  }

  // Initiate logger
  Logger logger = new Logger(config);

  // Initiate common
  FilesUtils filesUtils = new FilesUtils();
  HTTPUtils httpUtils = new HTTPUtils(logger);
  JsonUtils jsonUtils = new JsonUtils();

  // Initiate core
  LinuxCommand linuxCommand = new LinuxCommand(logger);
  LinuxFormat linuxFormat = new LinuxFormat(logger, linuxCommand);
  BaseLinux baseLinux =
      new BaseLinux(logger, linuxCommand, filesUtils, jsonUtils);
  MacOSCommand macOSCommand = new MacOSCommand(logger);
  MacOSFormat macOSFormat = new MacOSFormat(logger, macOSCommand);
  BaseMacOS baseMacOS = new BaseMacOS(logger, macOSCommand);
  WindowsCommand windowsCommand = new WindowsCommand(logger);
  WindowsFormat windowsFormat = new WindowsFormat(logger, windowsCommand);
  BaseWindows baseWindows =
      new BaseWindows(logger, windowsCommand, filesUtils, jsonUtils);

  // Initiate modules
  Inventory inventory = new Inventory(
      logger,
      config,
      filesUtils,
      httpUtils,
      jsonUtils,
      linuxCommand,
      linuxFormat,
      macOSCommand,
      macOSFormat,
      windowsCommand,
      windowsFormat);
  Deployment deployment = new Deployment(
      logger, config, httpUtils, linuxCommand, macOSCommand, windowsCommand);

  // Get the agent execution mode
  Map<int, String> enumMode = {
    0: "Installer mode",
    1: "Remote with template",
    2: "Remote without template",
    3: "Local with template",
    4: "Local without template",
  };
  logger.info("APP",
      sprintf("Starting agent in %s mode...", [enumMode[inventory.getMode()]]));

  // Get the OS body
  var body, os;
  if (Platform.isLinux) {
    body = await baseLinux.getBody();
    os = "LIN";
  } else if (Platform.isMacOS) {
    body = await baseMacOS.getBody();
    os = "MAC";
  } else if (Platform.isWindows) {
    body = await baseWindows.getBody();
    os = "WIN";
  } else {
    logger.error("APP",
        "OS does not match any of the supported OSs! (Check Plateform class return)");
  }

  if (inventory.getMode() == 0 ||
      inventory.getMode() == 1 ||
      inventory.getMode() == 2) {
    if (await inventory.checkApi()) {
      // Inventory process
      await inventory.checkInventoryExist(body);
      await inventory.checkAndApplyConfig();

      if (inventory.getMode() == 2 || inventory.getMode() == 1) {
        await inventory.sendRemoteBaseInventory(body);
        if (inventory.getMode() == 1) {
          await inventory.sendRemoteTemplateInventory(body);
        }
      }

      // Deployment process
      if (config.getCoreConfig("deployment", "enabled")) {
        if (await deployment.checkConfig()) {
          if (await deployment.checkDownload(inventory.assetID)) {
            if (await deployment.getActions(inventory.assetID)) {
              await deployment.executeActions(os, inventory.assetID);
            }
          }
        }
      }
    }
  } else if (inventory.getMode() == 3 || inventory.getMode() == 4) {
    await inventory.sendLocalBaseInventory(body);
    if (inventory.getMode() == 3) {
      await inventory.sendLocalTemplateInventory();
    }
  }
  try {
    if (config.getCoreConfig("agent", "frequency") != null) {
      stdout.writeln(
          config.getCoreConfig("agent", "frequency").toString().trim());
    }
  } catch (e) {
    stdout.writeln("4");
  }

  logger.info("APP", "Agent's process has ended!\n");
}
