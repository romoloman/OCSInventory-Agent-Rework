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

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ocs_agent/core/config.dart';

/// Insert log in console or file if configured in inventory.json.
class Logger {
  late bool _isFile;
  late File file;
  late DateFormat dateFormat;

  /// Constructor.
  Logger() {
    Config conf = Config();
    _isFile = (conf.getInventoryConfig("log_file").toLowerCase() == 'true');

    if (_isFile) {
      file = File(conf.getInventoryConfig("log_filename"));
    }

    dateFormat = DateFormat('yyyy-MM-dd H:m:s');
  }

  /// print info message.
  void info(String info) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date INFO: $info\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  /// print warning message.
  void warning(String warning) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date WARNING: $warning\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  /// print error message.
  void error(String error) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date ERROR: $error\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  /// print verbose message.
  void verbose(String verbose) {
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date VERBOSE: $verbose\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }
}
