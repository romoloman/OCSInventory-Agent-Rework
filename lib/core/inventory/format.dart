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

// External package imports
import 'dart:convert';

// Core imports
import 'package:ocs_agent/core/inventory/commands.dart';
import 'package:ocs_agent/core/log.dart';

/// Format command result by type.
class Format {
  late Logger logger;
  late Commands commands;

  /// Constructor.
  Format(this.logger, this.commands);

  /// Extract the value of a field from a list of results
  extractValue(Map<String, dynamic> field, Map<String, dynamic> result) {
    bool override = field['override_target'];
    String retrievalMethod;
    dynamic value;

    // two cases here:
    // 1. field is an override = we used the retrieval output of the field + its overriden result
    // 2. field is not an override = we used the retrieval output of the section + main result
    if (override) {
      retrievalMethod = field['retrieval_output'];
      result = result['override']
          .firstWhere((element) => element['name'] == field['name']);
      // result may be a list of strings if its from an overridden field
      // since multiple entries are not supported for field overrides there will only be a single entry
      if (result['result'] is List && result['result'].isNotEmpty) {
        result['result'] = result['result'][0];
      }
    } else {
      retrievalMethod = result['main']['type'];
      result = result['main'];
    }

    try {
      switch (retrievalMethod) {
        case "TBLE":
          value = result['result'][field['retrieval_value']] ?? "";
          break;

        case "JSON":
          value = result['result'][field['retrieval_value']] ?? "";
          break;

        case "REGX":
          RegExp regex = RegExp(field['retrieval_value']);
          dynamic match = regex.firstMatch(result['result']);
          value = regex.hasMatch(result['result']);
          if (match != null) {
            if ((match.groupCount >= 1) && (match.group(1) != null)) {
              value = match.group(1);
            } else {
              value = match.group(0);
            }
          } else {
            value = "";
          }
          break;

        case "PTXT":
          try {
            value = int.parse(field['retrieval_value']);
          } catch (e) {
            logger.error(this.runtimeType.toString(), e.toString());
            value = 0;
          }
          // split by lines or get a single line
          List<String> lines = result['result'].contains('\n')
              ? result['result'].split('\n')
              : [result['result']];
          value = value >= 0 && value < lines.length ? lines[value] : "";

          break;

        case "GREP":
          // e.g. retrieval_value = "test" and result = "test 1", we get "1"
          bool contains = result['result'].contains(field['retrieval_value']);
          if (contains) {
            final index =
                result['result'].indexOf(field['retrieval_value']) ?? -1;
            final start = index + field['retrieval_value'].length + 1;
            value = result['result'].substring(start);
          } else {
            return;
          }
          break;

        default:
          logger.warning(
              this.runtimeType.toString(), "Unknown method : $retrievalMethod");
          break;
      }
    } catch (e) {
      logger.error(this.runtimeType.toString(), "[${field['name']}] $e");
      return "";
    }
    value = value.toString().trim();
    return value;
  }

  /// Format the result of a section and overrided fields
  void formatResult(Map<String, dynamic> section, Map<String, dynamic> result) {
    // format main result
    if (result['main'] != null) {
      result['main']['result'] = formatContent(
        section['retrieval_output'],
        result['main']['result'],
        result['main']['options'],
      );
    }

    // format overrides
    if (result['override'] is List) {
      final overrides = result['override'] as List;
      for (var field in section['fields'] ?? []) {
        if (field['override_target'] == true) {
          final idx = overrides.indexWhere((o) => o['name'] == field['name']);
          if (idx != -1) {
            overrides[idx]['result'] = formatContent(
              field['retrieval_output'],
              overrides[idx]['result'],
              overrides[idx]['options'],
            );
          }
        }
      }
    }
  }

  /// Format the content of a field
  dynamic formatContent(String format, dynamic content, Map? options) {
    switch (format) {
      case "TBLE":
        return formatArray(content, options as Map<String, dynamic>?);
      case "JSON":
        try {
          var decoded = jsonDecode(content);
          final submap = options?['submap'];
          decoded = decoded is Map ? [decoded] : decoded;
          return submap != null && submap.isNotEmpty
              ? getJsonSubmap(decoded, submap)
              : decoded;
        } catch (e, st) {
          logger.error("Format", "Error while processing JSON: $e, $st");
          return content;
        }
      case "REGX":
        return parseRegx(content, options);
      case "PTXT":
        return (content as String?)?.trim() ?? '';
      case "GREP":
        return (content as String?)?.split("\n").toList() ?? [];
      default:
        logger.warning("Format", "Unknown retrieval_output: $format");
        return content;
    }
  }

  /// Format [result] string into a JSON list
  List<Map<String, dynamic>> formatArray(
    String result,
    Map<String, dynamic>? options,
  ) {
    bool optionsValid = options != null && options.isNotEmpty;
    final bool useFirstRowAsHeader =
        options?['use_index'] == true || options?['use_index'] == 'true';
    List<Map<String, dynamic>> jsonResult = [];

    // first we parse the array (this will removes lines if needed)
    final parsedArray = this.parseArray(result, options, optionsValid);
    // now we get the headers
    List<String> headersList =
        this.parseHeaders(parsedArray['rows'], parsedArray['use_index']);

    jsonResult = this.convertRowsToJson(
        parsedArray['rows'], headersList, useFirstRowAsHeader);

    return jsonResult;
  }

  parseHeaders(List<String> resultRows, bool useFirstRowAsHeader) {
    // useIndex = use first row as header, keeping the name to stay consistent with the server
    List<String> headersList = [];
    if (useFirstRowAsHeader) {
      headersList = resultRows.removeAt(0).split(RegExp(r'\s+'));
    }
    return headersList;
  }

  /// Parses the table as header/rows, splitting rows by newlines and headers
  /// by spaces if any. Removes lines if needed
  Map<String, dynamic> parseArray(
      String result, dynamic options, bool optionsValid) {
    List<String> resultRows;
    bool useIndex;

    useIndex = optionsValid && options?['use_index'] == true;

    try {
      resultRows = result.split("\n");
      // trimming to avoid misinterpreting spaces at start/end
      resultRows = resultRows.map((row) => row.trim()).toList();
      if (optionsValid && options?['remove_line'] != null) {
        resultRows = removeLines(options, optionsValid, resultRows);
      }
      return {
        'use_index': useIndex,
        'rows': resultRows,
      };
    } catch (e) {
      logger.error(this.runtimeType.toString(), e.toString());

      return {
        'use_index': useIndex,
        'rows': [],
      };
    }
  }

  /// Remove as many rows from [resultRows] as options['remove_line'] specifies
  List<String> removeLines(Map<String, dynamic>? options, bool optionsValid,
      List<String> resultRows) {
    if (options == null || !optionsValid) {
      logger.warning(
          this.runtimeType.toString(), "Options are invalid or null.");
      return resultRows;
    }

    int? linesRemoved;
    try {
      linesRemoved = int.tryParse(options['remove_line'].toString());
      if (linesRemoved == null || linesRemoved < 0) {
        throw FormatException("Invalid 'remove_line' value");
      }
    } catch (e) {
      logger.warning(
          this.runtimeType.toString(), "Invalid value for 'remove_line': $e");
      return resultRows;
    }

    if (linesRemoved > resultRows.length) {
      logger.warning(this.runtimeType.toString(),
          "'remove_line' exceeds the number of available rows.");
      return resultRows;
    }

    for (int i = 0; i < linesRemoved; i++) {
      resultRows.removeAt(0);
      logger.debug(this.runtimeType.toString(), 'Line $i removed from result');
    }

    return resultRows;
  }

  /// Convert [resultRows] to json format.
  List<Map<String, dynamic>> convertRowsToJson(
      List<String> resultRows, List<String> headersList, bool useIndex) {
    List<Map<String, dynamic>> jsonResult = [];

    for (var row in resultRows) {
      List<String> resultFields = row.split(RegExp(r'\s+'));
      Map<String, dynamic> jsonLine = {};

      for (int i = 0; i < resultFields.length; i++) {
        String key;
        if (useIndex) {
          if (i < headersList.length) {
            key = headersList[i];
          } else {
            logger.warning(this.runtimeType.toString(),
                "Header index $i out of bounds for headersList.");
            continue;
          }
        } else {
          key = i.toString();
        }

        jsonLine[key] = resultFields[i];
      }

      jsonResult.add(jsonLine);
    }

    return jsonResult;
  }

  /// Extract [submap] from JSON [decodedResult]
  List<Map<String, dynamic>> getJsonSubmap(
      List<dynamic> decodedResult, String? submap) {
    List<Map<String, dynamic>> processedResults = [];

    if (submap != null) {
      // split submap into keys
      List<String> keys = submap.split('.');

      // recursive function to traverse the JSON structure
      void traverse(List<dynamic> elements, List<String> remainingKeys) {
        if (remainingKeys.isEmpty) {
          // add if no more keys
          processedResults.addAll(elements.cast<Map<String, dynamic>>());
          return;
        }

        String currentKey = remainingKeys.first;
        List<String> nextKeys = remainingKeys.sublist(1);

        for (var element in elements) {
          if (element is Map && element.containsKey(currentKey)) {
            var subElement = element[currentKey];
            if (subElement is List) {
              // continue traversing
              traverse(subElement, nextKeys);
            } else if (nextKeys.isEmpty) {
              // add if no more keys
              processedResults.add(subElement as Map<String, dynamic>);
            }
          } else if (nextKeys.isNotEmpty) {
            traverse([], nextKeys);
          } else {
            logger.debug(this.runtimeType.toString(),
                'Unable to find the submap key "$currentKey" in the element $element');
          }
        }
      }

      // start w/ initial keys
      traverse(decodedResult, keys);
    }

    return processedResults;
  }

  /// Parse the [result] using separator and multiple in [options]
  /// If a separator is defined, we use it to split the result into blocks
  /// If multiple is true, we split the blocks by newlines
  /// If none of these options are defined, we return the original result
  List<String> parseRegx(dynamic result, dynamic options) {
    RegExp? blockSeparator;
    final rawSeparator = options['separator'];
    final bool multiple =
        options['multiple'] == true || options['multiple'] == 'true';

    List<String> blocksList;
    if (rawSeparator is String && rawSeparator.trim().isNotEmpty) {
      try {
        blockSeparator = RegExp("(?=${rawSeparator})");
      } catch (e) {
        logger.error(this.runtimeType.toString(), "Invalid regex: $e");
        return [result];
      }
    }

    blocksList =
        blockSeparator != null ? result.split(blockSeparator) : [result];
    if (multiple) {
      blocksList = blocksList.expand((block) => block.split('\n')).toList();
    }
    // remove empty entries that may result from splitting
    blocksList = blocksList.where((block) => block.trim().isNotEmpty).toList();

    return blocksList;
  }
}
