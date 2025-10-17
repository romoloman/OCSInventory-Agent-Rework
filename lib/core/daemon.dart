// OCSInventory Agent
// Copyright (C) OCSInventory
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
import 'dart:io';
import 'package:ocs_agent/core/config.dart';
import 'package:ocs_agent/core/log.dart';

class Daemon {
  late Config config;
  late Logger logger;
  late String executable;
  bool stopSignal = false;

  Daemon(this.config, this.logger) {
    if (Platform.isLinux) {
      ProcessSignal.sigterm.watch().listen((signal) {
        logger.info("Service", "Received SIGTERM signal. Stopping daemon...");
        stopSignal = true;
      });
    }

    if (Platform.isLinux || Platform.isMacOS) {
      executable = Directory.current.path + "/ocsinventory-cli";
    } else if (Platform.isWindows) {
      executable = Directory.current.path + "/ocsinventory-agent.exe";
    }

    start();
  }

  void start() async {
    while (!stopSignal) {
      dynamic frequency = config.getCoreConfig("agent", "frequency");
      if (frequency == false) {
        logger.warning(
            "Service", "Frequency not set, no inventory will be sent.");
        await Future.delayed(Duration(hours: 1));
        continue;
      }

      logger.info("Service", "Running agent executable...");
      try {
        await Process.run(executable, []);
      } catch (e) {
        logger.error("Service", "Failed to run agent executable: $e");
      }
      logger.info("Service", "Agent execution completed.");

      await Future.delayed(Duration(hours: frequency));
    }
  }
}
