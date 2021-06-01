import 'dart:io';

import 'package:intl/intl.dart';

class Logger {
  bool _isFile;
  File file;
  DateFormat dateFormat;

  Logger(bool isFile, String filename) {
    _isFile = isFile;
    dateFormat = DateFormat('yyyy-MM-dd H:m:s');
    if (isFile){
      file = File(filename);
    } else {
      file = null;
    }
  }

  void info(String info){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date INFO:$info\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  void warning(String warning){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date WARNING:$warning\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  void error(String error){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date ERROR:$error\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }

  void verbose(String verbose){
    var now = DateTime.now();
    String date = dateFormat.format(now);
    String txt = "$date VERBOSE:$verbose\n";
    if (_isFile) {
      file.writeAsStringSync(txt, mode: FileMode.append);
    } else {
      print(txt);
    }
  }
}