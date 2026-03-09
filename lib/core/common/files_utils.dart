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

import 'dart:io';

/// functions utils for files management.
class FilesUtils{
  /// Return file by [filename].
  File? getFile(String filename){
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