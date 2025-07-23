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

  /// Get the sub-inventory of [resultCommand] for each [fields] based on [method].
  List<dynamic> getByMethod(
      String method, List<dynamic> fields, Map<String, dynamic> resultCommand,
      [String? commandLine]) {
    late final commandTarget;
    late dynamic resultCommandData;
    late dynamic mainResult;
    late bool mainResultValid;
    late dynamic mainOptions;
    late List<Map<String, dynamic>> overrideResultList;
    List<dynamic> subInventory = [];

    // For MacOS
    try {
      commandTarget = commandLine?.split(" ")[1];
    } catch (_) {
      commandTarget = null;
    }

    if (fields.isEmpty) {
      logger.warning(runtimeType.toString(), "No fields available");
      return subInventory;
    }

    resultCommandData = this.getDataFromResultCommand(method, resultCommand);
    mainResult = resultCommandData['main_result'];
    mainResultValid = resultCommandData['main_result_valid'];
    mainOptions = resultCommandData['main_options'];
    overrideResultList = resultCommandData['override_result_list'];

    if (!mainResultValid) {
      logger.warning(this.runtimeType.toString(),
          "No results to process: the input data is empty or malformed.");
      return subInventory;
    }

    handleFieldExtraction(method, fields, resultCommand, mainResult,
        mainOptions, commandTarget, subInventory, false);

    if (overrideResultList.isNotEmpty) {
      overrideSubInventoryFields(method, fields, resultCommand,
          overrideResultList, commandTarget, subInventory);
    }

    logger.debug(this.runtimeType.toString(), subInventory.toString());

    return subInventory;
  }

  /// Extract the result and options from [resultCommand] with [method].
  Map<String, dynamic> getDataFromResultCommand(
      String method, Map<String, dynamic> resultCommand) {
    late dynamic mainResult;
    late bool mainResultValid;
    late dynamic mainOptions;
    late List<Map<String, dynamic>>? overrideResultList;

    mainResult = resultCommand['main']?['result'];
    mainResultValid = !(mainResult == null || mainResult.isEmpty);

    mainOptions = (method == "TBLE" || method == "JSON" || method == "REGX")
        ? (resultCommand['main']?['options'])
        : null;

    overrideResultList =
        resultCommand['override'] != null ? resultCommand['override'] : [];

    return {
      'main_result': mainResult,
      'main_result_valid': mainResultValid,
      'main_options': mainOptions,
      'override_result_list': overrideResultList,
    };
  }

  /// Handle all the process of fields extraction
  void handleFieldExtraction(
      String method,
      List<dynamic> fields,
      Map<String, dynamic> resultCommand,
      dynamic resultToProcess,
      dynamic optionsToApply,
      String? commandTarget,
      List<dynamic> subInventory,
      bool override) {
    late List<dynamic> processedResults;
    late Map<String, dynamic> result;

    processedResults = getProcessedResults(
        method, resultToProcess, optionsToApply, commandTarget);

    for (var processedResult in processedResults) {
      result = {};

      this.processFieldRetrieval(
          method, fields, resultCommand, processedResult, result, override);

      if (result.isNotEmpty) subInventory.add(result);
    }
  }

  /// Process the [resultToProcess] based on [method], [optionsToApply] and [commandTarget] for MacOS.
  List<dynamic> getProcessedResults(String method, dynamic resultToProcess,
      dynamic optionsToApply, String? commandTarget) {
    List<dynamic> processedResults = [];

    switch (method) {
      case "TBLE":
        processedResults = this.formatArray(resultToProcess, optionsToApply);
        break;

      case "JSON":
        try {
          dynamic decodedMainResult = jsonDecode(resultToProcess);
          String? submap = optionsToApply?["submap"] ?? null;

          decodedMainResult = decodedMainResult is Map
              ? [decodedMainResult]
              : decodedMainResult;

          processedResults = (commandTarget != null || submap != null)
              ? getJsonSubmap(
                  decodedMainResult, optionsToApply, commandTarget, submap)
              : decodedMainResult;
        } catch (e, stackTrace) {
          logger.warning(
            this.runtimeType.toString(),
            "Skip due to invalid or malformed JSON. $e, $stackTrace",
          );
        }
        break;

      case "REGX":
        processedResults = formatRegx(resultToProcess, optionsToApply);

      case "PTXT":
      case "GREP":
        processedResults = resultToProcess.split("\n").toList();
        break;

      default:
        logger.warning(this.runtimeType.toString(), "Unknown method : $method");
    }

    return processedResults;
  }

  /// Process sub-inventory build based on [method], [fields], [resultCommand], [processedResult] and [result] parameters.
  void processFieldRetrieval(
      String method,
      dynamic fields,
      Map<String, dynamic> resultCommand,
      dynamic processedResult,
      Map<String, dynamic> result,
      bool override) {
    dynamic retrievalValue;
    late bool condition;
    late dynamic function;

    if (processedResult == null || processedResult.isEmpty) return;

    fields.forEach((field) {
      switch (method) {
        case "TBLE":
          retrievalValue = field['retrieval_value'] ?? "";
          condition = true;
          function = processedResult[retrievalValue] ?? "";
          break;

        case "JSON":
          condition = true;
          function = processedResult[field['retrieval_value']] ?? "";
          break;

        case "REGX":
          try {
            retrievalValue = RegExp(field['retrieval_value']);
          } catch (e) {
            logger.error(this.runtimeType.toString(), e.toString());
            retrievalValue = null;
          }

          dynamic match = retrievalValue?.firstMatch(processedResult);
          condition = retrievalValue != null &&
              retrievalValue.hasMatch(processedResult);

          if (match != null) {
            if ((match.groupCount >= 1) && (match.group(1) != null)) {
              function = match.group(1);
            } else {
              function = match.group(0);
            }
          } else {
            function = "";
          }
          break;

        case "PTXT":
          try {
            retrievalValue = int.parse(field['retrieval_value']);
          } catch (e) {
            logger.error(this.runtimeType.toString(), e.toString());
            retrievalValue = 0;
          }

          condition = true;
          function =
              (retrievalValue > 0 && retrievalValue <= processedResult.length)
                  ? processedResult[retrievalValue - 1]
                  : "";
          break;

        case "GREP":
          retrievalValue = field['retrieval_value'] ?? "";
          condition = processedResult.contains(retrievalValue);

          final index = processedResult.indexOf(retrievalValue);
          final start = index + retrievalValue.length + 1;

          if (index == -1) {
            logger.warning(this.runtimeType.toString(),
                "Retrieval value '$retrievalValue' not found in: $processedResult");
            return;
          }

          if (start >= processedResult.length) {
            logger.error(this.runtimeType.toString(),
                "Start index $start out of bounds for: $processedResult");
            return;
          }

          function = processedResult.substring(start);
          break;

        default:
          logger.warning(
              this.runtimeType.toString(), "Unknown method : $method");
          break;
      }

      this.getSubInventoryResult(result, field, condition, function);
    });
  }

  /// Build sub-inventory data in [result] based on [field] and with [condition] and [function] parameters.
  void getSubInventoryResult(Map<String, dynamic> result, dynamic field,
      bool condition, dynamic function) {
    if (condition) {
      result.putIfAbsent(
        field['name'],
        () => function,
      );
    }
  }

  /// Format [result] string to a list of json.
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
          logger.verbose(
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

  /// Replace the values of the fields when they are overridden
  void overrideSubInventoryFields(
      String method,
      List<dynamic> fields,
      Map<String, dynamic> resultCommand,
      List<Map<String, dynamic>> overrideResultList,
      String? commandTarget,
      List<dynamic> subInventory) {
    dynamic overrideResult;
    dynamic overrideOptions;
    List<dynamic> overrideSubInventory = [];

    for (var element in overrideResultList) {
      overrideResult = element['result'];
      overrideOptions = element['options'];

      handleFieldExtraction(method, fields, resultCommand, overrideResult,
          overrideOptions, commandTarget, overrideSubInventory, true);
    }

    for (var overrideField in overrideSubInventory) {
      overrideField.forEach((key, overrideValue) {
        overrideValue = overrideValue.toString() != "null" ? overrideValue : "";

        if (overrideValue.toString().isNotEmpty) {
          for (var subField in subInventory) {
            if (subField.containsKey(key)) {
              subField[key] = overrideValue;
              logger.verbose(this.runtimeType.toString(),
                  'Field "$key" update with "$overrideValue"');
            }
          }
        }
      });
    }
  }
}
