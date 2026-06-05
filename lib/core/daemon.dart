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
import 'package:ocsinventory_agent/core/config.dart';
import 'package:ocsinventory_agent/core/log.dart';

class Daemon {
  late Config config;
  late Logger logger;
  late String executable;
  bool stopSignal = false;
  Process? currentProcess;
  StreamSubscription<ProcessSignal>? signalSubscription;
  final Completer<void> shutdownCompleter = Completer<void>();
  Timer? nextRunTimer;

  Daemon(this.config, this.logger) {
    if (Platform.isLinux) {
      signalSubscription = ProcessSignal.sigterm.watch().listen((signal) {
        stop();
      });
    }

    if (Platform.isLinux || Platform.isMacOS) {
      executable = Directory.current.path + "/ocsinventory-cli";
    } else if (Platform.isWindows) {
      executable = Directory.current.path + "/ocsinventory-agent.exe";
    }

    start();
  }

  void stop() {
    if (stopSignal) {
      return;
    }

    logger.info("Service", "Received SIGTERM signal. Stopping daemon...");
    stopSignal = true;

    nextRunTimer?.cancel();
    nextRunTimer = null;

    if (!shutdownCompleter.isCompleted) {
      shutdownCompleter.complete();
    }

    currentProcess?.kill(ProcessSignal.sigterm);
  }

  void start() async {
    try {
      while (!stopSignal) {
        dynamic frequency = config.getCoreConfig("agent", "frequency");
        if (frequency == false) {
          logger.warning(
              "Service", "Frequency not set, falling back to default value (1 hour).");
          frequency = 1;
        }

        logger.info("Service", "Running agent executable...");
        try {
          currentProcess = await Process.start(executable, []);
          unawaited(currentProcess!.stdout.drain<void>());
          unawaited(currentProcess!.stderr.drain<void>());
          await waitProcessExit(currentProcess!);
        } catch (e) {
          logger.error("Service", "Failed to run agent executable: $e");
        } finally {
          currentProcess = null;
        }

        if (stopSignal) {
          break;
        }

        logger.info("Service", "Agent execution completed.");
        await waitForNextRun(Duration(hours: frequency));
      }
    } finally {
      nextRunTimer?.cancel();
      await signalSubscription?.cancel();
      signalSubscription = null;
    }
  }

  Future<void> waitForNextRun(Duration duration) async {
    if (stopSignal) {
      return;
    }

    final Completer<void> timerCompleter = Completer<void>();
    nextRunTimer = Timer(duration, () {
      if (!timerCompleter.isCompleted) {
        timerCompleter.complete();
      }
    });

    try {
      await Future.any([timerCompleter.future, shutdownCompleter.future]);
    } finally {
      nextRunTimer?.cancel();
      nextRunTimer = null;
    }
  }

  Future<void> waitProcessExit(Process process) async {
    final Future<int> exitCodeFuture = process.exitCode;

    final bool processExited = await Future.any([
      exitCodeFuture.then((_) => true),
      shutdownCompleter.future.then((_) => false),
    ]);

    if (processExited) {
      return;
    }

    process.kill(ProcessSignal.sigterm);
    try {
      await exitCodeFuture.timeout(
        Duration(seconds: 10),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (_) {}
  }
}
