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
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:sprintf/sprintf.dart';

// Core imports
import 'package:ocs_agent/core/log.dart';
import 'package:ocs_agent/core/config.dart';

import 'package:ocs_agent/core/inventory/linux/commands.dart';
import 'package:ocs_agent/core/inventory/macos/commands.dart';
import 'package:ocs_agent/core/inventory/windows/commands.dart';

// Common imports
import 'package:ocs_agent/core/common/http_utils.dart';

class Deployment {
  late Config config;
  late Logger logger;
  late HTTPUtils httpUtils;
  late LinuxCommand linuxCommand;
  late MacOSCommand macOSCommand;
  late WindowsCommand windowsCommand;

  late var url;

  late List<dynamic> results;
  late Map<int, dynamic> actions;
  late List<dynamic> sortedActions;

  /// Constructor.
  Deployment(
      Logger logger,
      Config config,
      HTTPUtils httpUtils,
      LinuxCommand linuxCommand,
      MacOSCommand macOSCommand,
      WindowsCommand windowsCommand) {
    this.logger = logger;
    this.config = config;
    this.httpUtils = httpUtils;
    this.linuxCommand = linuxCommand;
    this.macOSCommand = macOSCommand;
    this.windowsCommand = windowsCommand;

    url = config.getInventoryConfig("url");
    actions = Map();
    sortedActions = [];
  }

  /// Check the configuration of the deployment module.
  Future<bool> checkConfig() async {
    logger.info(this.runtimeType.toString(),
        "Enabling deployment module and checking its configuration...");

    // Check if the URL is set
    if (url == null) {
      logger.error(this.runtimeType.toString(),
          "URL is missing in the configuration file.");
      return false;
    }

    // Check if the URL is valid
    if (!Uri.parse(url).isAbsolute) {
      logger.error(this.runtimeType.toString(),
          "URL in the configuration file is not valid.");
      return false;
    }

    // Check if the URL is reachable
    var response = await httpUtils.get(
        Uri.parse(url + "/deployment/results/"), httpUtils.getHeader(config));
    if (response["status_code"] == 200) {
      logger.info(
          this.runtimeType.toString(), "Deployment endpoint is reachable.");
      return true;
    } else {
      logger.error(
          this.runtimeType.toString(), "Deployment endpoint is not reachable.");
      return false;
    }
  }

  /// Check if there is packages to download.
  Future<bool> checkDownload(int assetID) async {
    // API call: Check if there is assigned packages
    var response = await httpUtils.get(
        Uri.parse(url + "/deployment/results/?asset=$assetID&status=1"),
        httpUtils.getHeader(config));
    // VERBOSE: show result of the query in verbose mode
    logger.verbose(this.runtimeType.toString(), response["message"]);

    if (response["status_code"] == 200 &&
        jsonDecode(response["body"]).isNotEmpty) {
      logger.info(this.runtimeType.toString(), "Found assigned packages.");

      // Get the list of assigned packages
      results = jsonDecode(response["body"]);

      // For each package, change state of the package to Notified
      for (var element in results) {
        var responseNotified = await httpUtils.patch(
            Uri.parse(
                url + "/deployment/results/" + element["id"].toString() + "/"),
            httpUtils.getHeader(config),
            "{\"comment\": \"Notified\"}");
        logger.verbose(
            this.runtimeType.toString(), responseNotified["message"]);
      }
      return true;
    } else {
      logger.info(this.runtimeType.toString(),
          "No assigned packages found for this asset.");
      return false;
    }
  }

  /// Get actions from assigned packages.
  Future<bool> getActions(int assetID) async {
    logger.info(this.runtimeType.toString(), "Collecting actions...");

    // For each package, get the list of the package actions
    for (var element in results) {
      try {
        // API call: get the list of actions
        var response = await httpUtils.get(
            Uri.parse(url +
                "/deployment/actions/?package=" +
                element["package"].toString()),
            httpUtils.getHeader(config));
        // VERBOSE: show result of the query in verbose mode
        logger.verbose(this.runtimeType.toString(), response["message"]);

        if (response["status_code"] == 200) {
          // Sort the actions by priority
          sortedActions = jsonDecode(response["body"]);
          sortedActions.sort((a, b) => a["priority"].compareTo(b["priority"]));
          // Add sorted actions list of each package to the general actions list
          actions.putIfAbsent(element["package"], () => sortedActions);

          logger.serverLogger(
              assetID,
              7,
              "Collected actions from the server for the package " +
                  element["package"].toString() +
                  ".");
        } else {
          logger.error(
              this.runtimeType.toString(),
              "Failed to collect actions from the server for the package " +
                  element["package"].toString() +
                  ".");
          logger.serverLogger(
              assetID,
              8,
              "Failed to collect actions from the server for the package " +
                  element["package"].toString() +
                  ".");
          return false;
        }
      } catch (exception) {
        logger.error(this.runtimeType.toString(),
            sprintf("HTTP query: %s", [exception.toString().trim()]));
        return false;
      }
    }
    logger.info(this.runtimeType.toString(), "Actions collected successfully.");
    return true;
  }

  /// Execute actions from assigned packages.
  Future<void> executeActions(String os, int assetID) async {
    logger.info(this.runtimeType.toString(), "Executing actions...");

    int id = 0;
    int status = 0;

    // For each action, try to execute the command in the action object
    for (var element in actions.values) {
      for (var action in element) {
        logger.verbose(this.runtimeType.toString(),
            "Processing action: ${action.toString()}");

        results.forEach((resultElement) {
          if (resultElement["package"] == action["package"]) {
            id = resultElement["id"];
          }
        });
        String packagePath = config.getInventoryConfig("data_directory") +
            "/deployment/" +
            action["package"].toString() +
            "/";
        // VERBOSE: show which action is processing
        logger.verbose(this.runtimeType.toString(), action.toString());
        switch (action["action_type"]) {
          case "EXEC":
            await executeCommand(os, action["package"], action["command"]) ==
                    true
                ? status = 0
                : status = 1;
            if (status == 0) {
              logger.info(this.runtimeType.toString(),
                  "Command executed successfully.");
            } else {
              logger.error(this.runtimeType.toString(),
                  "Error while executing command.");
            }
            break;
          case "STORE":
            String fileUrl = action["file"]["file"];
            await storeFile(action["package"], fileUrl, action["command"],
                        action["action_type"], os) ==
                    true
                ? status = 0
                : status = 1;
            if (status == 0) {
              logger.info(this.runtimeType.toString(),
                  "File has been successfully downloaded and saved.");
              // Delete the package directory after storing the file
              var packageDirectory = Directory(packagePath);
              if (packageDirectory.existsSync()) {
                await packageDirectory.delete(recursive: true);
                logger.verbose(this.runtimeType.toString(),
                    "Deleted package directory at: '$packagePath'");
              }
            } else {
              logger.error(this.runtimeType.toString(),
                  "Error while downloading and saving the file.");
            }
            break;
          case "LAUNCH":
            String fileUrl = action["file"]["file"];
            status = await launchFile(os, action["package"], action["command"],
                fileUrl, action["action_type"]);
            if (status == 0) {
              logger.info(
                  this.runtimeType.toString(), "File launched successfully.");
            } else {
              logger.error(
                  this.runtimeType.toString(), "Error while launching file.");
            }
            // Delete the package directory after launching the file
            var packageDirectory = Directory(packagePath);
            if (packageDirectory.existsSync()) {
              await packageDirectory.delete(recursive: true);
              logger.verbose(this.runtimeType.toString(),
                  "Deleted package directory at: '$packagePath'");
            }
            break;
          default:
            logger.error(this.runtimeType.toString(),
                "Unknown action type: " + action["action_type"].toString());
            logger.serverLogger(assetID, 8,
                "Unknown action type: " + action["action_type"].toString());
            break;
        }
      }

      if (status == 0) {
        try {
          // API call: send success to server if the package is installed
          var responseSuccess = await httpUtils.patch(
              Uri.parse(url + "/deployment/results/$id/"),
              httpUtils.getHeader(config),
              "{\"status\": 1, \"comment\": \"Success\"}");
          logger.verbose(
              this.runtimeType.toString(), responseSuccess["message"]);
          if (responseSuccess["status_code"] == 200) {
            logger.info(this.runtimeType.toString(),
                "Package $id has been successfully processed.");
            logger.serverLogger(
                assetID, 7, "Package $id has been successfully processed.");
          }
        } catch (exception) {
          logger.error(this.runtimeType.toString(),
              sprintf("HTTP query: %s", [exception.toString().trim()]));
        }
      } else {
        try {
          // API call: send error to server if the package isn't installed
          var responseFail = await httpUtils.patch(
              Uri.parse(url + "/deployment/results/$id/"),
              httpUtils.getHeader(config),
              "{\"status\": 2, \"comment\": \"Error\"}");
          logger.verbose(this.runtimeType.toString(), responseFail["message"]);
          if (responseFail["status_code"] == 200) {
            logger.error(this.runtimeType.toString(),
                "Something went wrong while processing package $id.");
            logger.serverLogger(assetID, 8,
                "Something went wrong while processing package $id.");
          }
        } catch (exception) {
          logger.error(this.runtimeType.toString(),
              sprintf("HTTP query: %s", [exception.toString().trim()]));
        }
      }
    }
  }

  /// Execute the action command.
  Future<bool> executeCommand(
      String os, int package, String actionCommand) async {
    logger.info(this.runtimeType.toString(), "Executing action command...");

    // This variables will replace variable by dynamic path
    Map<String, dynamic> variables = {
      "\$AGENT_PATH":
          Directory.current.toString().substring(11, null).replaceAll("'", "") +
              "/" +
              config.getInventoryConfig("data_directory"),
      "\$PACKAGE": "deployment/" + package.toString()
    };
    variables.keys.forEach((key) {
      actionCommand = actionCommand.replaceAll(key, variables[key]);
    });
    late Map<String, Object> result;
    int retryCounter = 0;
    do {
      result = {"value": "", "status": false};

      // Depending of the plateform, execute a command with appropriate CLI
      switch (os) {
        case "LIN":
          result = await linuxCommand
              .commandShell(actionCommand, true)
              .then((value) {
            return value;
          }).catchError((onError) {
            logger.error(this.runtimeType.toString(),
                "Error while executing action command: $onError");
            return {"value": "", "status": false};
          }).timeout(
                  Duration(
                      days: config.getCoreConfig(
                    "deployment",
                    "execution_timeout",
                  )), onTimeout: () {
            logger.error(this.runtimeType.toString(),
                "Error while executing action command: TIMEOUT");
            return {"value": "", "status": false};
          });
          break;
        case "MAC":
          result = await macOSCommand
              .commandShell(actionCommand, true)
              .then((value) {
            return value;
          }).catchError((onError) {
            logger.error(this.runtimeType.toString(),
                "Error while executing action command: $onError");
            return {"value": "", "status": false};
          }).timeout(
                  Duration(
                      days: config.getCoreConfig(
                    "deployment",
                    "execution_timeout",
                  )), onTimeout: () {
            logger.error(this.runtimeType.toString(),
                "Error while executing action command: TIMEOUT");
            return {"value": "", "status": false};
          });
          break;
        case "WIN":
          result = await windowsCommand
              .commandPowershell(actionCommand, true)
              .then((value) {
            return value;
          }).catchError((onError) {
            logger.error(this.runtimeType.toString(),
                "Error while executing action command: $onError");
            return {"value": "", "status": false};
          }).timeout(
                  Duration(
                      days: config.getCoreConfig(
                    "deployment",
                    "execution_timeout",
                  )), onTimeout: () {
            logger.error(this.runtimeType.toString(),
                "Error while executing action command: TIMEOUT");
            return {"value": "", "status": false};
          });
          break;
        default:
          logger.error(this.runtimeType.toString(), "Unsupported OS detected.");

          break;
      }
      if (config.getCoreConfig("deployment", "max_retry") >= retryCounter &&
          config.getCoreConfig("deployment", "auto_retry") &&
          result["status"] == false &&
          retryCounter > 0) {
        logger.error(this.runtimeType.toString(),
            "Command execution failed on retry #${retryCounter}: ${result["value"].toString()}");
      }
      retryCounter++;
    } while (result["status"] == false &&
        config.getCoreConfig("deployment", "max_retry") >= retryCounter &&
        config.getCoreConfig("deployment", "auto_retry"));

    if (result["status"] == true) {
      logger.verbose(this.runtimeType.toString(), result["value"].toString());
    }
    bool status = result["status"] == true ? true : false;
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
  Future<bool> extractZipFile(List<int> _downloadData, String extractedPath,
      File savedFile, String metaDataPath, bool status) async {
    // Decompress the zip archive
    var archive = await ZipDecoder().decodeBytes(_downloadData);
    await extractArchiveToDiskAsync(archive, extractedPath).then((value) {
      // Log verbose message indicating successful extraction
      logger.verbose(this.runtimeType.toString(),
          "File has been extracted at: '$extractedPath'");

      // Delete the __MACOSX directory if it exists
      var metaDataDirectory = Directory(metaDataPath);
      if (metaDataDirectory.existsSync()) {
        metaDataDirectory.delete(recursive: true);
      }
      // Delete the archive file after extracting it
      if (savedFile.existsSync()) {
        savedFile.deleteSync();
      }
      status = true;
    }).catchError((onError) {
      // Handle extraction error
      status = false;
      logger.error(this.runtimeType.toString(),
          "Error occurred while extracting file at path: $onError");
    });
    return status;
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
  Future<bool> extractTarFile(String filePath, String extractedPath,
      File savedFile, bool status, String os) async {
    late var command;
    switch (os) {
      case "LIN":
        command = linuxCommand;
        break;
      case "MAC":
        command = macOSCommand;
        break;
      default:
        logger.error(this.runtimeType.toString(),
            "Unsupported OS detected while extracting tar file.");
        break;
    }

    logger.verbose(this.runtimeType.toString(),
        "Extracting tar file: '$filePath' to path: '$extractedPath'");

    // Execute the tar command to extract the archive file
    var result = await command
        .commandShell("tar -xvf $filePath -C $extractedPath", true)
        .then((value) {
      // Delete the archive file after extracting it
      if (savedFile.existsSync()) {
        // Log verbose message indicating successful extraction
        logger.verbose(this.runtimeType.toString(),
            "File has been extracted at: '$extractedPath'");

        savedFile.deleteSync();
        return value;
      } else {
        return {"value": "", "status": false};
      }
    }).catchError((onError) {
      // Handle extraction error
      logger.error(this.runtimeType.toString(),
          "Error occurred while extracting file at path: $onError");

      return {"value": "", "status": false};
    });
    status = result["status"] == true ? true : false;
    return status;
  }

  /// Downloads a file from a given URL and stores it locally.
  ///
  /// This function downloads a file from a specified URL and stores it locally
  /// in the agent's directory. Optionally, it can also store the file in a
  /// specified directory if the action type is "STORE". It supports
  /// downloading and storing both regular files and compressed files (tar and zip).
  ///
  /// Parameters:
  ///   - package: The package identifier.
  ///   - filePath: The URL of the file to download.
  ///   - pathToStore: The path where the file will be stored locally.
  ///   - actionType: The action type, either "STORE" or another value.
  ///   - os: The operating system of the agent.
  ///
  /// Returns:
  ///   An integer status code indicating the success or failure of the operation.
  ///   - 0: Success
  ///   - 1: Failure
  Future<bool> storeFile(int package, String filePath, String pathToStore,
      String actionType, String os) async {
    logger.info(this.runtimeType.toString(), "Downloading and saving file...");
    logger.verbose(
        this.runtimeType.toString(), "File path structure: $filePath");

    // extract actual URL if filePath is a Map
    String fileUrl;
    if (filePath is Map<String, dynamic>) {
      fileUrl = (filePath as Map<String, dynamic>)["file"] as String;
      logger.verbose(
          this.runtimeType.toString(), "Extracted file URL: $fileUrl");
    } else {
      fileUrl = filePath;
    }

    // Get the package directory or create one if not exist
    var packageDirectory = Directory(
        config.getInventoryConfig("data_directory") +
            "/deployment/" +
            package.toString());
    if (!packageDirectory.existsSync()) {
      packageDirectory.createSync(recursive: true);
    }

    late bool status;
    late HttpClient client;
    int retryCounter = 0;

    Future<String> completerValue = Future.value("");
    // Store the file in the agent directory - use the last part of the URL for filename
    String localPath = config.getInventoryConfig("data_directory") +
        "/deployment/" +
        package.toString() +
        "/";
    var fileSaveLocal = new File(localPath + fileUrl.split("/").last);

    String specifiedPath =
        pathToStore.endsWith("/") ? pathToStore : pathToStore + "/";

    do {
      // Try to download and store the file in the package folder
      bool responseStreamStatus = false;
      Completer<String> completer = Completer<String>();
      try {
        List<int> _downloadData = [];
        client = HttpClient();
        status = false;

        client.getUrl(Uri.parse(fileUrl)).then((HttpClientRequest request) {
          return request.close();
        }).then((HttpClientResponse response) {
          if (response.statusCode == HttpStatus.ok) {
            logger.verbose(this.runtimeType.toString(),
                "Successfully downloaded file: $fileUrl");
            response.pipe(fileSaveLocal.openWrite()).then((fileAdded) async {
              // Save the file directly if not zipped

              if (fileAdded.existsSync()) {
                responseStreamStatus = true;
                if (fileUrl.endsWith('.tar') ||
                    fileUrl.endsWith('.tar.gz') ||
                    fileUrl.endsWith('.zip') ||
                    fileUrl.endsWith('.tar.xz') ||
                    fileUrl.endsWith('.tgz') ||
                    fileUrl.endsWith('.tar.bz2')) {
                  switch (os) {
                    case "LIN":
                      if ((fileUrl.endsWith('.tar') ||
                              fileUrl.endsWith('.tar.gz') ||
                              fileUrl.endsWith('.tar.xz') ||
                              fileUrl.endsWith('.tgz') ||
                              fileUrl.endsWith('.tar.bz2')) &&
                          responseStreamStatus == true) {
                        // Decompress the tar archive
                        await extractTarFile(
                                localPath + fileUrl.split("/").last,
                                specifiedPath,
                                fileSaveLocal,
                                responseStreamStatus,
                                os)
                            .then((value) => responseStreamStatus = value);
                      }
                      if (fileUrl.endsWith('.zip')) {
                        logger.error(this.runtimeType.toString(),
                            "Zip format is not supported for Linux: $fileUrl");
                        responseStreamStatus = false;
                      }
                      break;

                    case "MAC":
                      if ((fileUrl.endsWith('.tar') ||
                              fileUrl.endsWith('.tar.gz') ||
                              fileUrl.endsWith('.tar.xz') ||
                              fileUrl.endsWith('.tgz') ||
                              fileUrl.endsWith('.tar.bz2')) &&
                          responseStreamStatus == true) {
                        // Decompress the tar archive
                        await extractTarFile(
                                localPath + fileUrl.split("/").last,
                                specifiedPath,
                                fileSaveLocal,
                                responseStreamStatus,
                                os)
                            .then((value) => responseStreamStatus = value);
                      }
                      if (fileUrl.endsWith('.zip')) {
                        logger.error(this.runtimeType.toString(),
                            "Zip format is not supported for MacOS: $fileUrl");
                        responseStreamStatus = false;
                      }
                      break;

                    case "WIN":
                      if ((fileUrl.endsWith('.zip')) &&
                          responseStreamStatus == true) {
                        // Determine the local path to th meta data directory
                        String metaDataPath = localPath + "/__MACOSX";

                        // Decompress the zip archive
                        await extractZipFile(
                                _downloadData,
                                specifiedPath,
                                fileSaveLocal,
                                metaDataPath,
                                responseStreamStatus)
                            .then((value) => responseStreamStatus = value);
                      }
                      if (fileUrl.endsWith('.tar') ||
                          fileUrl.endsWith('.tar.gz')) {
                        logger.error(this.runtimeType.toString(),
                            "Tar format is not supported for Windows: $fileUrl");
                        responseStreamStatus = false;
                      }
                      break;

                    default:
                      logger.error(this.runtimeType.toString(),
                          "Unsupported OS detected while storing file: $fileUrl");
                      responseStreamStatus = false;
                  }
                } else {
                  logger.verbose(this.runtimeType.toString(),
                      "The file $fileUrl has been saved in the agent directory at: '$localPath'");
                  if (actionType == "LAUNCH") {
                    // Make the file executable
                    String chmodCommand = "chmod +x ${fileAdded.path}";
                    await executeCommand(os, package, chmodCommand);
                  }

                  if (actionType == "STORE") {
                    File remoteFile = await fileAdded
                        .copySync(specifiedPath + fileUrl.split("/").last);
                    if (remoteFile.existsSync() &&
                        remoteFile.lengthSync() == fileAdded.lengthSync()) {
                      logger.verbose(this.runtimeType.toString(),
                          "The file $fileUrl has been successfully saved at the specified path: '$specifiedPath'");
                      responseStreamStatus = true;
                    } else {
                      logger.error(this.runtimeType.toString(),
                          "Error encountered while saving the file to the specified path: $fileAdded");
                      responseStreamStatus = false;
                    }
                  }
                }
              } else {
                logger.error(this.runtimeType.toString(),
                    "An error occurred while attempting to save the file to the agent directory: $fileAdded");
                responseStreamStatus = false;
              }

              // Complete the completer with the final value of responseStreamStatus
              completer.complete(responseStreamStatus.toString());
            }, onError: (error) {
              responseStreamStatus = false;
              logger.error(this.runtimeType.toString(),
                  "Error while downloading file: $error");
              // Complete the completer with error
              completer.completeError(error);
            }).timeout(
                Duration(
                    seconds: config.getCoreConfig(
                        "deployment", "deployment_timeout")), onTimeout: () {
              responseStreamStatus = false;
              logger.error(this.runtimeType.toString(),
                  "Error while downloading file: TIMEOUT");
              // Complete the completer with error
              completer.completeError("TIMEOUT");
            });
          } else {
            completer.complete(responseStreamStatus.toString());
            if (config.getCoreConfig("deployment", "max_retry") >=
                    retryCounter &&
                config.getCoreConfig("deployment", "auto_retry") &&
                responseStreamStatus == false &&
                retryCounter > 0) {
              logger.error(this.runtimeType.toString(),
                  "File save failed on retry #${retryCounter}: ${response.reasonPhrase} ${fileUrl}");
              responseStreamStatus = false;
              return response.drain();
            } else {
              logger.error(this.runtimeType.toString(),
                  "Failed to download file: ${response.reasonPhrase} ${fileUrl}");
              responseStreamStatus = false;
              return response.drain();
            }
          }
        });
      } finally {
        // Get the future from the completer
        completerValue = completer.future;
        client.close();
      }

      await completerValue.then((value) async {
        if (value == "true") {
          status = true;
        } else {
          status = false;
        }
      }).catchError((error) {
        logger.error(this.runtimeType.toString(),
            "Failed to download and save file: $error");
        status = false;
      });

      retryCounter++;
    } while (status == false &&
        config.getCoreConfig("deployment", "max_retry") >= retryCounter &&
        config.getCoreConfig("deployment", "auto_retry"));
    return status;
  }

  /// Store the specified file and execute it.
  Future<int> launchFile(String os, int package, String actionCommand,
      dynamic filePath, String actionType) async {
    logger.info(this.runtimeType.toString(), "Launching file...");
    logger.verbose(this.runtimeType.toString(),
        "Launch file parameters - Command: $actionCommand, File: $filePath");

    // use package dir as extract path
    String packagePath = config.getInventoryConfig("data_directory") +
        "/deployment/" +
        package.toString() +
        "/";

    logger.verbose(this.runtimeType.toString(),
        "Using package directory for extraction: '$packagePath'");

    bool storeStatus =
        await storeFile(package, filePath, packagePath, actionType, os);

    logger.verbose(this.runtimeType.toString(),
        "File store operation result: ${storeStatus ? 'Success' : 'Failed'}");

    //  listing files to ensure extraction went well
    List<String> extractedFiles = [];
    try {
      var files = Directory(packagePath).listSync();
      extractedFiles = files.map((f) => f.path.split('/').last).toList();
      logger.verbose(this.runtimeType.toString(),
          "Files in package directory: ${extractedFiles.join(', ')}");
    } catch (e) {
      logger.error(this.runtimeType.toString(),
          "Error listing files in package directory: $e");
    }

    // keeping the current dir
    String originalDir = Directory.current.path;

    // then switching to the pkg dir for contextual exec
    Directory.current = Directory(packagePath);
    logger.verbose(this.runtimeType.toString(),
        "Changed working directory to: '${Directory.current.path}'");

    bool execStatus = await executeCommand(os, package, actionCommand);

    // back to the original dir
    Directory.current = Directory(originalDir);
    logger.verbose(this.runtimeType.toString(),
        "Restored working directory to: '${Directory.current.path}'");

    logger.verbose(this.runtimeType.toString(),
        "Command execution result: ${execStatus ? 'Success' : 'Failed'}");

    return (storeStatus && execStatus) ? 0 : 1;
  }
}
