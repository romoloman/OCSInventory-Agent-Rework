import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ocs_agent/core/config.dart';

class Logger {
  bool _isFile;
  File file;
  DateFormat dateFormat;

  Logger() {
    Config conf = Config();
    _isFile = (conf.getInventoryConfig("log_file").toLowerCase() == 'true');

    if (_isFile) {
      file = File(conf.getInventoryConfig("log_filename"));
    }

    dateFormat = DateFormat('yyyy-MM-dd H:m:s');
  }

  void info(String info){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date INFO: $info\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  void warning(String warning){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date WARNING: $warning\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  void error(String error){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date ERROR: $error\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  void verbose(String verbose){
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