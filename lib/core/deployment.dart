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

import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

import 'package:ocs_agent/core/common/http_utils.dart';

class Deployment {
  late Config config;
  late Logger logger;

  Map<int, String> errorCodes = new Map();

  Deployment() {
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

  Future<bool> checkDownload(int assetID) async {
    return false;
  }

  Map<int, dynamic> getActions(int assetID) {
    return new Map();
  }

  void executeAction(bool containFile, String actionType) {}

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
