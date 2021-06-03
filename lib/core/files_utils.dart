import 'dart:io';

class FilesUtils{
  File getFile(String filename){
    try{
      return File(filename);
    } catch(e){
      print(e);
      return null;
    }
  }

  void writeFile(File file, String data){
    try{
      file.writeAsStringSync(data);
    } catch(e){
      print(e);
    }
  }

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