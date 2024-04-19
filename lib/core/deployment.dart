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
  late List<dynamic> sortedActions;

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
    sortedActions = [];
  }

  /// Check the configuration of the deployment module.
  Future<bool> checkConfig() async {
    logger.info("Enabling and Checking deployment module configuration...");

    // Check if the URL is set
    if (url == null) {
      logger.error("URL is not set in the configuration file!");
      return false;
    }

    // Check if the URL is valid
    if (!Uri.parse(url).isAbsolute) {
      logger.error("URL is not valid in the configuration file!");
      return false;
    }

    // Check if the URL is reachable
    var response = await httpUtils.get("checkConfig",
        Uri.parse(url + "/deployment/results/"), httpUtils.getHeader(config));
    if (response["status_code"] == 200) {
      logger.info("Deployment module configuration is valid!");
      return true;
    } else {
      logger.error("Deployment module configuration is not valid!");
      return false;
    }
  }

  /// Check if there is packages to download.
  Future<bool> checkDownload(int assetID) async {
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
          // Sort the actions by priority
          sortedActions = jsonDecode(response["body"]);
          sortedActions.sort((a, b) => a["priority"].compareTo(b["priority"]));
          // Add sorted actions list of each package to the general actions list
          actions.putIfAbsent(element["package"], () => sortedActions);

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

    // For each action, try to execute the command in the action object
    for (var element in actions.values) {
      for (var action in element) {
        results.forEach((resultElement) {
          if (resultElement["package"] == action["package"]) {
            id = resultElement["id"];
          }
        });
        String packagePath = config.getInventoryConfig("data_dir") +
            "/deployment/" +
            action["package"].toString() +
            "/";
        // VERBOSE: show which action is processing
        logger.verbose(action.toString());
        switch (action["action_type"]) {
          case "EXEC":
            await executeCommand(os, action["package"], action["command"]) ==
                    true
                ? status = 0
                : status = 1;
            if (status == 0) {
              logger.info("Command executed successfully!");
            } else {
              logger.error("Error while executing command!");
            }
            break;
          case "STORE":
            await storeFile(action["package"], action["file"],
                        action["command"], action["action_type"], os) ==
                    true
                ? status = 0
                : status = 1;
            if (status == 0) {
              logger.info("File downloaded and stored successfully!");
              // Delete the package directory after storing the file
              var packageDirectory = Directory(packagePath);
              if (packageDirectory.existsSync()) {
                await packageDirectory.delete(recursive: true);
                logger.verbose("Package directory deleted: '$packagePath'");
              }
            } else {
              logger.error("Error while downloading and storing file!");
            }
            break;
          case "LAUNCH":
            status = await launchFile(os, action["package"], action["command"],
                action["file"], action["action_type"]);
            if (status == 0) {
              logger.info("File launched successfully!");
            } else {
              logger.error("Error while launching file!");
            }
            // Delete the package directory after launching the file
            var packageDirectory = Directory(packagePath);
            if (packageDirectory.existsSync()) {
              await packageDirectory.delete(recursive: true);
              logger.verbose("Package directory deleted: '$packagePath'");
            }
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
            logger.error("Package $id was not completed successfully!");
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
  Future<bool> executeCommand(
      String os, int package, String actionCommand) async {
    logger.info("Executing action command...");

    // This variables will replace variable by dynamic pat
    String agentPath =
        Directory.current.toString().substring(11, null).replaceAll("'", "") +
            "/" +
            config.getInventoryConfig("data_dir") +
            "/deployment/" +
            package.toString();
    actionCommand = actionCommand.replaceAll("AGENT_PATH", agentPath);
    late Map<String, Object> result;
    int retryCounter = 0;
    do {
      result = {"value": "", "status": false};

      // Depending of the plateform, execute a command with appropriate CLI
      switch (os) {
        case "LIN":
          var command = LinuxCommand();

          result =
              await command.commandShell(actionCommand, true).then((value) {
            return value;
          }).catchError((onError) {
            logger.error("Error while executing action command: $onError");
            return {"value": "", "status": false};
          }).timeout(
                  Duration(
                      days: config.getCoreConfig(
                    "deployment",
                    "execution_timeout",
                  )), onTimeout: () {
            logger.error("Error while executing action command: TIMEOUT");
            return {"value": "", "status": false};
          });
          break;
        case "MAC":
          var command = MacOSCommand();

          result =
              await command.commandShell(actionCommand, true).then((value) {
            return value;
          }).catchError((onError) {
            logger.error("Error while executing action command: $onError");
            return {"value": "", "status": false};
          }).timeout(
                  Duration(
                      days: config.getCoreConfig(
                    "deployment",
                    "execution_timeout",
                  )), onTimeout: () {
            logger.error("Error while executing action command: TIMEOUT");
            return {"value": "", "status": false};
          });
          break;
        case "WIN":
          var command = WindowsCommand();

          result = await command
              .commandPowershell(actionCommand, true)
              .then((value) {
            return value;
          }).catchError((onError) {
            logger.error("Error while executing action command: $onError");
            return {"value": "", "status": false};
          }).timeout(
                  Duration(
                      days: config.getCoreConfig(
                    "deployment",
                    "execution_timeout",
                  )), onTimeout: () {
            logger.error("Error while executing action command: TIMEOUT");
            return {"value": "", "status": false};
          });
          break;
        default:
          logger.error(
              "OS does not match any of the supported OSs! (Check Plateform class return)");

          break;
      }
      if (config.getCoreConfig("deployment", "max_retry") >= retryCounter &&
          config.getCoreConfig("deployment", "auto_retry") == 1 &&
          result["status"] == false &&
          retryCounter > 0) {
        logger.error(
            "Failed to execute command with retry ${retryCounter}: ${result["value"].toString()}");
      }
      retryCounter++;
    } while (result["status"] == false &&
        config.getCoreConfig("deployment", "max_retry") >= retryCounter &&
        config.getCoreConfig("deployment", "auto_retry") == 1);

    if (result["status"] == true) {
      logger.verbose(result["value"].toString());
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
      status = true;
    }).catchError((onError) {
      // Handle extraction error
      status = false;
      logger.error("Error while extracting file in the path: $onError");
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
        command = LinuxCommand();
        break;
      case "MAC":
        command = MacOSCommand();
        break;
      default:
        logger.error(
            "OS does not match any of the supported OSs! (Check Plateform class return)");
        break;
    }

    // Execute the tar command to extract the archive file
    var result = await command
        .commandShell("tar -xvf $filePath -C $extractedPath", true)
        .then((value) {
      // Delete the archive file after extracting it
      if (savedFile.existsSync()) {
        // Log verbose message indicating successful extraction
        logger.verbose("File extracted in the path: '$extractedPath'");

        savedFile.deleteSync();
        return value;
      } else {
        return {"value": "", "status": false};
      }
    }).catchError((onError) {
      // Handle extraction error
      logger.error("Error while extracting file in the path: $onError");

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
    logger.info("Downloading and storing file...");

    // Get the package directory or create one if not exist
    var packageDirectory = Directory(config.getInventoryConfig("data_dir") +
        "/deployment/" +
        package.toString());
    if (!packageDirectory.existsSync()) {
      packageDirectory.createSync(recursive: true);
    }

    late bool status;
    late HttpClient client;
    int retryCounter = 0;

    Future<String> completerValue = Future.value("");
    // Store the file in the agent directory
    String localPath = config.getInventoryConfig("data_dir") +
        "/deployment/" +
        package.toString() +
        "/";
    var fileSaveLocal = new File(localPath + filePath.split("/").last);

    String specifiedPath = pathToStore;

    do {
      // Try to download and store the file in the package folder
      bool responseStreamStatus = false;
      Completer<String> completer = Completer<String>();
      try {
        List<int> _downloadData = [];
        client = HttpClient();
        status = false;

        client.getUrl(Uri.parse(filePath)).then((HttpClientRequest request) {
          return request.close();
        }).then((HttpClientResponse response) {
          if (response.statusCode == HttpStatus.ok) {
            logger.verbose("Downloaded file $filePath");
            response.pipe(fileSaveLocal.openWrite()).then((fileAdded) async {
              // Save the file directly if not zipped

              if (fileAdded.existsSync()) {
                responseStreamStatus = true;
                print(filePath);
                print(filePath.endsWith('.tar.xz'));
                if (filePath.endsWith('.tar') ||
                    filePath.endsWith('.tar.gz') ||
                    filePath.endsWith('.zip') ||
                    filePath.endsWith('.tar.xz') ||
                    filePath.endsWith('.tgz') ||
                    filePath.endsWith('.tar.bz2')) {
                  switch (os) {
                    case "LIN":
                      if ((filePath.endsWith('.tar') ||
                              filePath.endsWith('.tar.gz') ||
                              filePath.endsWith('.tar.xz') ||
                              filePath.endsWith('.tgz') ||
                              filePath.endsWith('.tar.bz2')) &&
                          responseStreamStatus == true) {
                        // Decompress the tar archive
                        await extractTarFile(
                                localPath + filePath.split("/").last,
                                specifiedPath,
                                fileSaveLocal,
                                responseStreamStatus,
                                os)
                            .then((value) => responseStreamStatus = value);
                      }
                      if (filePath.endsWith('.zip')) {
                        logger.error(
                            "Extract zip file is not supported for Linux OS: $filePath");
                        responseStreamStatus = false;
                      }
                      break;

                    case "MAC":
                      if ((filePath.endsWith('.tar') ||
                              filePath.endsWith('.tar.gz') ||
                              filePath.endsWith('.tar.xz') ||
                              filePath.endsWith('.tgz') ||
                              filePath.endsWith('.tar.bz2')) &&
                          responseStreamStatus == true) {
                        // Decompress the tar archive
                        await extractTarFile(
                                localPath + filePath.split("/").last,
                                specifiedPath,
                                fileSaveLocal,
                                responseStreamStatus,
                                os)
                            .then((value) => responseStreamStatus = value);
                      }
                      if (filePath.endsWith('.zip')) {
                        logger.error(
                            "Extract zip file is not supported for Mac OS: $filePath");
                        responseStreamStatus = false;
                      }
                      break;

                    case "WIN":
                      if ((filePath.endsWith('.zip')) &&
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
                      if (filePath.endsWith('.tar') ||
                          filePath.endsWith('.tar.gz')) {
                        logger.error(
                            "Extract tar file is not supported for Windows OS: $filePath");
                        responseStreamStatus = false;
                      }
                      break;

                    default:
                      logger
                          .error("OS does not match any of the supported OSs!");
                      responseStreamStatus = false;
                  }
                } else {
                  logger.verbose(
                      "$filePath is stored in the agent directory: '$localPath'");
                  if (actionType == "LAUNCH") {
                    // Make the file executable
                    String chmodCommand = "chmod +x ${fileAdded.path}";
                    await executeCommand(os, package, chmodCommand);
                  }

                  if (actionType == "STORE") {
                    File remoteFile = await fileAdded
                        .copySync(specifiedPath + filePath.split("/").last);
                    if (remoteFile.existsSync() &&
                        remoteFile.lengthSync() == fileAdded.lengthSync()) {
                      logger.verbose(
                          "$filePath is stored in the specified path: '$specifiedPath'");
                      responseStreamStatus = true;
                    } else {
                      logger.error(
                          "Error while storing file in the specified path: $fileAdded");
                      responseStreamStatus = false;
                    }
                  }
                }
              } else {
                logger.error(
                    "Error while storing file in the agent directory: $fileAdded");
                responseStreamStatus = false;
              }

              // Complete the completer with the final value of responseStreamStatus
              completer.complete(responseStreamStatus.toString());
            }, onError: (error) {
              responseStreamStatus = false;
              logger.error("Error while downloading file: $error");
              // Complete the completer with error
              completer.completeError(error);
            }).timeout(
                Duration(
                    seconds: config.getCoreConfig(
                        "deployment", "deployment_timeout")), onTimeout: () {
              responseStreamStatus = false;
              logger.error("Error while downloading file: TIMEOUT");
              // Complete the completer with error
              completer.completeError("TIMEOUT");
            });
          } else {
            completer.complete(responseStreamStatus.toString());
            if (config.getCoreConfig("deployment", "max_retry") >=
                    retryCounter &&
                config.getCoreConfig("deployment", "auto_retry") == 1 &&
                responseStreamStatus == false &&
                retryCounter > 0) {
              logger.error(
                  "Failed to store file with retry ${retryCounter}: ${response.reasonPhrase} ${filePath}");
              responseStreamStatus = false;
              return response.drain();
            } else {
              logger.error(
                  "Failed to download file: ${response.reasonPhrase} ${filePath}");
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
        logger.error("Failed to download and store the file!");
        status = false;
      });

      retryCounter++;
    } while (status == false &&
        config.getCoreConfig("deployment", "max_retry") >= retryCounter &&
        config.getCoreConfig("deployment", "auto_retry") == 1);
    return status;
  }

  /// Store the specified file and execute it.
  Future<int> launchFile(String os, int package, String actionCommand,
      String filePath, String actionType) async {
    logger.info("Launching file...");
    bool storeStatus =
        await storeFile(package, filePath, actionCommand, actionType, os);
    bool execStatus = await executeCommand(os, package, actionCommand);
    int status = 0;
    if (storeStatus) {
      if (execStatus) {
        status = 0;
      } else {
        status = 1;
      }
    } else {
      status = 1;
    }
    return status;
  }
}
