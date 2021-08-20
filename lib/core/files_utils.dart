import 'dart:io';

/// functions utils for files management.
class FilesUtils{
  /// Return file by [filename].
  File getFile(String filename){
    try{
      return File(filename);
    } catch(e){
      print(e);
      return null;
    }
  }

  /// add [data] to [file].
  void writeFile(File file, String data){
    try{
      file.writeAsStringSync(data);
    } catch(e){
      print(e);
    }
  }

  /// Try to rewrite a [file] with [data] and apply ancient text if failed.
  void rewriteFile(File file, String data){
    String backup = file.readAsStringSync();
    try{
      file.writeAsStringSync(data);
    } catch(e){
      file.writeAsStringSync(backup);
      print(e);
    }
  }
}