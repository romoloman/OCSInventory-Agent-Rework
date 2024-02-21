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
import 'package:sprintf/sprintf.dart';

import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/common/http_utils.dart';

class Deployment {
  late Config config;
  late Logger logger;

  late HTTPUtils httpUtils;

  late var url;

  late List<dynamic> results;
  late Map<int, dynamic> actions;

  Map<int, String> errorCodes = new Map();

  /// Constructor.
  Deployment() {
    this.config = new Config();
    this.logger = new Logger();

    this.httpUtils = new HTTPUtils();

    this.url = config.getInventoryConfig("url");

    this.actions = new Map();

    errorCodes = {
      0: "WAITING NOTIFICATION",
      1: "NOTIFIED",
      2: "SUCCESS",
      3: "ERROR_EXIT_CODE_XXX",
      4: "ERR_ALREADY_SETUP",
      5: "ERR_BAD_ID",
      6: "ERR_BAD_DIGEST",
      7: "ERR_DOWNLOAD_INFO",
      8: "ERR_DOWNLOAD_PACK",
      9: "ERR_BUILD",
      10: "ERR_UNZIP",
      11: "ERR_OUT_OF_SPACE",
      12: "ERR_BAD_PARAM",
      13: "ERR_EXECUTE_PACK",
      14: "ERR_EXECUTE",
      15: "ERR_CLEAN",
      16: "ERR_DONE_FAILED",
      17: "ERR_TIMEOUT",
      18: "ERR_ABORTED"
    };
  }

  /// Check if there is packages to download.
  Future<bool> checkDownload(int assetID) async {
    logger.info("Enabling deployment module...");
    var response = await httpUtils.get(
        "checkDownload",
        Uri.parse(url + "/deployment/results/?asset=$assetID&status=1"),
        httpUtils.getHeader(config));
    logger.verbose(response["message"]);
    if (response["status_code"] == 200 &&
        jsonDecode(response["body"]).isNotEmpty) {
      logger.info("Assigned packages found!");
      results = jsonDecode(response["body"]);
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
        } else {
          logger.error("Can't collect actions from the server.");
          return false;
        }
      } catch (exception) {
        logger.error(sprintf("HTTP query: %s", [exception.toString().trim()]));
        logger.serverLogger(assetID, 5,
            sprintf("HTTP query: %s", [exception.toString().trim()]));
        return false;
      }
    }
    logger.info("Actions collected");
    return true;
  }

  /// Execute actions from assigned packages.
  void executeActions() {
    logger.info("Executing actions...");
  }

  dynamic getFile() {
    return false;
  }

  int executeFile(dynamic file) {
    return 0;
  }

  int storeFile(dynamic file) {
    return 0;
  }

  int launchFile(dynamic file) {
    return 0;
  }
}
