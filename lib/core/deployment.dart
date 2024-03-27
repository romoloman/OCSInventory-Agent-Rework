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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:sprintf/sprintf.dart';

import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/common/http_utils.dart';

import 'package:ocs_agent/core/inventory/linux/commands.dart';
import 'package:ocs_agent/core/inventory/macos/commands.dart';
import 'package:ocs_agent/core/inventory/windows/commands.dart';

class Deployment {
  // Modules
  late Config config;
  late Logger logger;

  // Utilities
  late HTTPUtils httpUtils;

// Other variable used by the class
  late var url;

  late List<dynamic> results;
  late Map<int, dynamic> actions;

  /// Constructor.
  Deployment() {
    // Modules init
    config = Config();
    logger = Logger();

    // Utilities init
    httpUtils = HTTPUtils();

    // Other variable init
    url = config.getInventoryConfig("url");
    actions = Map();
  }

  /// Check if there is packages to download.
  Future<bool> checkDownload(int assetID) async {
    logger.info("Enabling deployment module...");

    // API call: Check if there is assigned packages
    var response = await httpUtils.get(
        "checkDownload",
        Uri.parse(url + "/deployment/results/?asset=$assetID&status=0"),
        httpUtils.getHeader(config));
    // VERBOSE: show result of the query in verbose mode
    logger.verbose(response["message"]);

    if (response["status_code"] == 200 &&
        jsonDecode(response["body"]).isNotEmpty) {
      logger.info("Assigned packages found!");

      // Get the list of assigned packages
      results = jsonDecode(response["body"]);

      // For each package, change state of the package to Notified
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

    // For each package, get the list of the package actions
    for (var element in results) {
      try {
        // API call: get the list of actions
        var response = await httpUtils.get(
            "getActions",
            Uri.parse(url +
                "/deployment/actions/?package=" +
                element["package"].toString()),
            httpUtils.getHeader(config));
        // VERBOSE: show result of the query in verbose mode
        logger.verbose(response["message"]);

        if (response["status_code"] == 200) {
          // Add actions list of each package to the general actions list
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

    int id = 0;
    int status = 0;
    late bool success;

    // For each action, try to execute the command in the action object
    for (var element in actions.values) {
      success = false;

      // This for loop try the number of times of the parameter "max_retry" in the server config
      for (var _ in Iterable.generate(
          config.getCoreConfig("deployment", "max_retry"))) {
        // Exit the loop if the package has been installed successfully
        if (success == true) {
          break;
        }
        for (var action in jsonDecode(element)) {
          results.forEach((resultElement) {
            if (resultElement["package"] == action["package"]) {
              id = resultElement["id"];
            }
          });
          // VERBOSE: show which action is processing
          logger.verbose(action.toString());
          switch (action["action_type"]) {
            case "EXEC":
              status = await executeCommand(
                  os, action["package"], action["command"]);
              break;
            case "STORE":
              status = await storeFile(action["package"], action["file"],
                  action["command"], action["action_type"], os);
              break;
            case "LAUNCH":
              status = await launchFile(os, action["package"],
                  action["command"], action["file"], action["action_type"]);
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
          // if process method don't send any error, the package has been installed successfully
          if (status == 0) {
            success = true;
          }
        }
      }
      if (status == 0) {
        try {
          // API call: send success to server if the package is installed
          var responseSuccess = await httpUtils.patch(
              "executeActions",
              Uri.parse(url + "/deployment/results/$id/"),
              httpUtils.getHeader(config),
              "{\"status\": 1, \"comment\": \"Success\"}");
          logger.verbose(responseSuccess["message"]);
          if (responseSuccess["status_code"] == 200) {
            logger.info("Package $id was completed successfully!");
            logger.serverLogger(
                assetID, 7, "Package $id was completed successfully!");
          }
        } catch (exception) {
          logger
              .error(sprintf("HTTP query: %s", [exception.toString().trim()]));
        }
      } else {
        try {
          // API call: send error to server if the package isn't installed
          var responseFail = await httpUtils.patch(
              "executeActions",
              Uri.parse(url + "/deployment/results/$id/"),
              httpUtils.getHeader(config),
              "{\"status\": 2, \"comment\": \"Error\"}");
          logger.verbose(responseFail["message"]);
          if (responseFail["status_code"] == 200) {
            logger.info("Package $id was not completed successfully!");
            logger.serverLogger(
                assetID, 8, "Package $id was not completed successfully!");
          }
        } catch (exception) {
          logger
              .error(sprintf("HTTP query: %s", [exception.toString().trim()]));
        }
      }
    }
  }

  /// Execute the action command.
  Future<int> executeCommand(
      String os, int package, String actionCommand) async {
    logger.info("Executing action command...");

    // This variables will replace variable by dynamic path
    Map<String, dynamic> variables = {
      "\$AGENT_PATH":
          Directory.current.toString().substring(11, null).replaceAll("'", "") +
              "/" +
              config.getInventoryConfig("data_dir"),
      "\$PACKAGE": "deployment/" + package.toString()
    };
    variables.keys.forEach((key) {
      actionCommand = actionCommand.replaceAll(key, variables[key]);
    });

    int status = 0;
    String result = "";

    // Depending of the plateform, execute a command with appropriate CLI
    switch (os) {
      case "LIN":
        var command = LinuxCommand();

        result = await command.commandShell(actionCommand, true).timeout(
            Duration(
                days: config.getCoreConfig(
              "deployment",
              "execution_timeout",
            )), onTimeout: () {
          status = 1;
          return "TIMEOUT: Command execution time exceeded!";
        });
        break;
      case "MAC":
        var command = MacOSCommand();

        result = await command.commandShell(actionCommand, true).timeout(
            Duration(
                days: config.getCoreConfig(
              "deployment",
              "execution_timeout",
            )), onTimeout: () {
          status = 1;
          return "TIMEOUT: Command execution time exceeded!";
        });
        break;
      case "WIN":
        var command = WindowsCommand();

        result = await command.commandPowershell(actionCommand, true).timeout(
            Duration(
                days: config.getCoreConfig(
              "deployment",
              "execution_timeout",
            )), onTimeout: () {
          status = 1;
          return "TIMEOUT: Command execution time exceeded!";
        });
        break;
      default:
        logger.error(
            "OS does not match any of the supported OSs! (Check Plateform class return)");
        break;
    }
    if (status == 0) {
      logger.verbose(result);
      logger.info("Action command executed successfully!");
    } else {
      logger.error(result);
    }
    return status;
  }

  /// Extracts a zip file to the specified path and performs cleanup.
  ///
  /// This function decompresses the provided zip archive data and extracts its
  /// contents to the specified path. After extraction, it deletes the metadata
  /// directory if it exists.
  ///
  /// Parameters:
  ///   - _downloadData: The byte data of the zip archive.
  ///   - extractedPath: The path where the contents of the zip archive will be extracted.
  ///   - metaDataPath: The path to the metadata directory to be deleted.
  ///   - status: The status indicator. If an error occurs during extraction,
  ///             status will be set to 1.
  ///
  /// Returns:
  ///   A Future<void> representing the completion of the extraction process.
  ///
  /// Throws:
  ///   Any error that occurs during the extraction process.
  Future<void> extractZipFile(List<int> _downloadData, String extractedPath,
      File savedFile, String metaDataPath, int status) async {
    // Decompress the zip archive
    var archive = await ZipDecoder().decodeBytes(_downloadData);
    await extractArchiveToDiskAsync(archive, extractedPath).then((value) {
      // Log verbose message indicating successful extraction
      logger.verbose("File extracted in the path: '$extractedPath'");

      // Delete the __MACOSX directory if it exists
      var metaDataDirectory = Directory(metaDataPath);
      if (metaDataDirectory.existsSync()) {
        metaDataDirectory.delete(recursive: true);
      }
      // Delete the archive file after extracting it
      if (savedFile.existsSync()) {
        savedFile.deleteSync();
      }
    }).catchError((onError) {
      // Handle extraction error
      status = 1;
      logger.error("Error while extracting file in the path: $onError");
    });
  }

  /// Extracts a tar file to the specified path and deletes the archive file.
  ///
  /// This function extracts the contents of a tar archive file to the specified
  /// path using the `tar` command. After extraction, it deletes the archive file.
  ///
  /// Parameters:
  ///   - filePath: The path to the tar archive file to be extracted.
  ///   - extractedPath: The path where the contents of the tar archive will be extracted.
  ///   - savedFile: The file object representing the tar archive file.
  ///   - status: The status indicator. If an error occurs during extraction,
  ///             status will be set to 1.
  ///
  /// Returns:
  ///   A Future<void> representing the completion of the extraction process.
  ///
  /// Throws:
  ///   Any error that occurs during the extraction process.
  Future<void> extractTarFile(
      String filePath, String extractedPath, File savedFile, int status) async {
    var command = LinuxCommand();

    // Execute the tar command to extract the archive file
    await command
        .commandShell("tar -xvf $filePath -C $extractedPath", true)
        .then((value) {
      // Log verbose message indicating successful extraction
      logger.verbose("File extracted in the path: '$extractedPath'");

      // Delete the archive file after extracting it
      if (savedFile.existsSync()) {
        savedFile.deleteSync();
      }
    }).catchError((onError) {
      // Handle extraction error
      logger.error("Error while extracting file in the path: $onError");
      status = 1;
    });
  }

  /// This function downloads and stores the file in the agent directory and in the specified path.
  /// package: The package ID
  /// filePath: The file URL to download
  /// pathToStore: The path to store the file
  /// actionType: The action type (EXECUTE or STORE)
  /// return: 0 if the file is downloaded and stored successfully, 1 otherwise
  Future<int> storeFile(int package, String filePath, String pathToStore,
      String actionType, String os) async {
    logger.info("Downloading and storing file...");

    // Get the package directory or create one if not exist
    var packageDirectory = Directory(config.getInventoryConfig("data_dir") +
        "/deployment/" +
        package.toString());
    if (!packageDirectory.existsSync()) {
      packageDirectory.createSync(recursive: true);
    }

    int status = 0;
    HttpClient client = HttpClient();
    // Try to download and store the file in the package folder
    try {
      List<int> _downloadData = [];

      // Store the file in the agent directory
      String localPath = config.getInventoryConfig("data_dir") +
          "/deployment/" +
          package.toString() +
          "/";
      var fileSaveLocal = new File(localPath + filePath.split("/").last);

      String remotePath = pathToStore;
      var fileSaveRemote =
          new File(remotePath + "/" + filePath.split("/").last);

      client.getUrl(Uri.parse(filePath)).then((HttpClientRequest request) {
        return request.close();
      }).then((HttpClientResponse response) {
        if (response.statusCode == HttpStatus.ok) {
          logger.verbose("File downloaded successfully !");
          response.listen((data) {
            _downloadData.addAll(data);
          }, onDone: () async {
            if (filePath.endsWith('.zip')) {
              // Decompress the zip archive
              var archive = await ZipDecoder().decodeBytes(_downloadData);
              await extractArchiveToDiskAsync(archive, localPath).then((value) {
                logger
                    .verbose("File stored in the agent directory '$localPath'");
                // Determine the local path to th meta data directory
                String metaDataPath = Directory.current
                        .toString()
                        .substring(11, null)
                        .replaceAll("'", "") +
                    "/" +
                    config.getInventoryConfig("data_dir") +
                    "/deployment/" +
                    package.toString() +
                    "/__MACOSX";
                // Delete the __MACOSX directory if it exists
                var metaDataDirectory = Directory(metaDataPath);
                if (metaDataDirectory.existsSync()) {
                  metaDataDirectory.delete(recursive: true);
                }
              }).catchError((onError) {
                status = 1;
                logger.error(
                    "Error while storing file in the agent directory: $onError");
              });
            } else {
              // Save the file directly if not zipped
              await fileSaveLocal
                  .writeAsBytes(_downloadData)
                  .then((_) => logger.verbose(
                      "File stored in the agent directory '$localPath'"))
                  .catchError((onError) {
                status = 1;
                logger.error(
                    "Error while storing file in the agent directory: $onError");
              });
            }

            // Store the file in the specified path only if the action type is STORE
            if (actionType == "STORE") {
              var DirectoryToStore = Directory(pathToStore);
              if (DirectoryToStore.existsSync()) {
                if (filePath.endsWith('.zip')) {
                  // Decompress the zip archive
                  var archive = await ZipDecoder().decodeBytes(_downloadData);
                  await extractArchiveToDiskAsync(archive, remotePath)
                      .then((value) {
                    logger.verbose(
                        "File stored in the speccified path '$remotePath'");
                    // Determine the local path to th meta data directory
                    String metaDataPath = remotePath + "/__MACOSX";
                    // Delete the __MACOSX directory if it exists
                    var metaDataDirectory = Directory(metaDataPath);
                    if (metaDataDirectory.existsSync()) {
                      metaDataDirectory.delete(recursive: true);
                    }
                  }).catchError((onError) {
                    status = 1;
                    logger.error(
                        "Error while storing file in the specified path: $onError");
                  });
                } else {
                  // Save the file directly if not zipped
                  await fileSaveRemote
                      .writeAsBytes(_downloadData)
                      .then((value) => logger.verbose(
                          "File stored in the specified path '$remotePath'"))
                      .catchError((onError) {
                    status = 1;
                    logger.error(
                        "Error while storing file in the specified path: $onError");
                  });
                }
              } else {
                status = 1;
                logger.error("Path to store the file does not exist !");
              }
            }
          }, onError: (error) {
            status = 1;
            logger.error("Error while downloading file: $error");
          });
        } else {
          status = 1;
          logger.error("Failed to download file: ${response.statusCode}");
        }
      }).catchError((error) {
        status = 1;
        logger.error("Error during HTTP request: $error");
      }).timeout(
          Duration(
              days: config.getCoreConfig("deployment", "download_timeout")),
          onTimeout: () {
        status = 1;
        logger.error("TIMEOUT: Download time exceeded for file $filePath !");
      });
    } finally {
      client.close();
    }

    if (status == 0) {
      logger.info("File downloaded and stored!");
    } else {
      logger.error("Failed to download and store the file!");
    }
    return status;
  }

  /// Store the specified file and execute it.
  Future<int> launchFile(String os, int package, String actionCommand,
      String filePath, String actionType) async {
    int storeStatus =
        await storeFile(package, filePath, actionCommand, actionType, os);
    int execStatus = await executeCommand(os, package, actionCommand);
    int status = 0;
    if (storeStatus != 0 || execStatus != 0) {
      status = 1;
    }
    return status;
  }
}
