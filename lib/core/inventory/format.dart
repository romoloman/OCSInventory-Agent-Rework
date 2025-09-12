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
    } else {
      retrievalMethod = result['main']['type'];
      result = result['main'];
    }

    switch (retrievalMethod) {
      case "TBLE":
        value = result[field['retrieval_value']] ?? "";
        break;

      case "JSON":
        value = result[field['retrieval_value']] ?? "";
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
          value = int.parse(result[field['retrieval_value']]);
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
        value = result[field['retrieval_value']] ?? "";

        final index = result[field['retrieval_value']].indexOf(value) ?? -1;
        final start = index + value.length + 1;

        if (index == -1) {
          logger.warning(this.runtimeType.toString(),
              "Retrieval value '$value' not found in: $result");
          return;
        }

        if (start >= result[field['retrieval_value']].length) {
          logger.error(this.runtimeType.toString(),
              "Start index $start out of bounds for: $result");
          return;
        }

        value = result[field['retrieval_value']].substring(start);
        break;

      default:
        logger.warning(
            this.runtimeType.toString(), "Unknown method : $retrievalMethod");
        break;
    }

    value = value.trim();
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
          return submap != null ? getJsonSubmap(decoded, submap) : decoded;
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
    final parsedLists = this.useIndex(result, options, optionsValid);
    final useIndex = parsedLists['use_index']!;
    final headersList = parsedLists['headers']!;
    final resultRows = parsedLists['rows']!;
    late bool listsValid;
    List<Map<String, dynamic>> jsonResult = [];

    listsValid = resultRows.isNotEmpty && (headersList.isNotEmpty || !useIndex);

    if (!listsValid) {
      logger.warning(
          this.runtimeType.toString(), "Unable to get results from table.");

      return jsonResult;
    }

    final filteredResultRows = optionsValid
        ? removeLines(options, optionsValid, resultRows)
        : resultRows;
    jsonResult =
        this.convertRowsToJson(filteredResultRows, headersList, useIndex);

    return jsonResult;
  }

  /// Extracts headers from the [result] string based on use_index option.
  Map<String, dynamic> useIndex(
      String result, dynamic options, bool optionsValid) {
    List<String> resultRows;
    List<String> headersList;
    bool useIndex;

    useIndex = optionsValid && options?['use_index'] == true;

    try {
      resultRows = result.split("\n");
      headersList = resultRows.removeAt(0).split(RegExp(r'\s+'));

      return {
        'use_index': useIndex,
        'headers': headersList,
        'rows': resultRows,
      };
    } catch (e) {
      logger.error(this.runtimeType.toString(), e.toString());

      return {
        'use_index': useIndex,
        'headers': [],
        'rows': [],
      };
    }
  }

  /// Remove raws in [resultRows] based on the remove_line option.
  List<String> removeLines(Map<String, dynamic>? options, bool optionsValid,
      List<String> resultRows) {
    int? linesRemoved;
    int rowIndex = 0;

    try {
      linesRemoved = int.tryParse(options!['remove_line'].toString());
    } catch (e) {
      logger.warning(this.runtimeType.toString(),
          "Invalid value for 'remove_line': expected an integer: $e");

      return resultRows;
    }

    if (linesRemoved != null) {
      while (rowIndex != linesRemoved) {
        if (rowIndex >= 0 && rowIndex < resultRows.length) {
          resultRows.removeAt(rowIndex);
          logger.debug(
              this.runtimeType.toString(), 'Line "$rowIndex" removed.');
        }

        ++rowIndex;
      }
    }

    return resultRows;
  }

  /// Convert [resultRows] to json format.
  List<Map<String, dynamic>> convertRowsToJson(
      List<String> resultRows, List<String> headersList, bool useIndex) {
    List<String> resultFields;
    Map<String, dynamic> jsonLine;
    List<Map<String, dynamic>> jsonResult = [];

    resultRows.forEach((row) {
      resultFields = row.split(RegExp(r'\s+'));
      jsonLine = {};

      resultFields.asMap().forEach((i, field) {
        String key = useIndex ? headersList[i] : i.toString();

        jsonLine.putIfAbsent(key, () => field);
      });

      jsonResult.add(jsonLine);
    });

    return jsonResult;
  }

  /// Extract [commandTarget] or [submap] from [decodedMainResult] based on [mainOptions].
  List<Map<String, dynamic>> getJsonSubmap(List<dynamic> decodedMainResult,
      dynamic mainOptions, dynamic commandTarget, String? submap) {
    dynamic formattedResult;
    List<Map<String, dynamic>> formattedResultList = [];
    List<Map<String, dynamic>> processedResults = [];
    late List<Map<String, dynamic>> subResults;

    // If the OS is MacOS, we need to access to element[commandTarget]
    for (Map<String, dynamic> element in decodedMainResult) {
      formattedResult =
          commandTarget != null ? element[commandTarget] : element;

      if (formattedResult is List) {
        formattedResultList
            .addAll(formattedResult.cast<Map<String, dynamic>>());
      } else {
        formattedResultList.add(formattedResult);
      }
    }

    if (submap != null) {
      for (var key in submap.split('.')) {
        subResults = [];

        for (var element in formattedResultList) {
          if (element.containsKey(key)) {
            var subElement = element[key];
            if (subElement is List) {
              subResults.addAll(subElement.cast<Map<String, dynamic>>());
            } else {
              subResults.add(subElement);
            }
          } else {
            logger.warning(this.runtimeType.toString(),
                'Unable to find the "$key" submap.');
          }
        }

        processedResults = subResults;
      }
    } else {
      processedResults = formattedResultList;
    }

    return processedResults;
  }

  /// Format [mainResult] based on [mainOptions].
  List<String> formatRegx(dynamic mainResult, dynamic mainOptions) {
    RegExp? blockSeparator;
    final rawSeparator = mainOptions['separator'];
    if (mainOptions['multiple'] == "true") mainOptions['multiple'] = true;
    bool multiple = mainOptions['multiple'] ?? false;
    late List<String> blocksList;

    if (rawSeparator is String && rawSeparator.trim().isNotEmpty)
      blockSeparator = RegExp("(?=${rawSeparator})");

    blocksList = blockSeparator != null
        ? mainResult.split(blockSeparator)
        : [mainResult];

    if (multiple)
      blocksList = blocksList.expand((block) => block.split('\n')).toList();

    return blocksList;
  }
}
