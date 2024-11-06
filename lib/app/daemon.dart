import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

void main(List<String> args) async {
  // Initiate the parser for the arguments
  ArgParser parser = ArgParser();
  ArgResults allArgs;
  String workingDirectory = await Directory.current.path;
  parser.addOption("current_directory",
      abbr: "d",
      help: "Directory where the executable agent is located",
      valueHelp: "path_to_agent_directory/agent_unix_ocs.exe",
      defaultsTo: workingDirectory);
  parser.addFlag("help",
      abbr: "h", help: "Display this help message", negatable: false);

  // Parse the arguments
  try {
    allArgs = parser.parse(args);
  } on ArgParserException catch (ex) {
    stdout.writeln("Error: Argument parsing failed.");
    stdout.writeln(ex.message);
    stdout.writeln(parser.usage);
    exit(1);
  } catch (ex) {
    stdout.writeln("Error: An issue occurred while parsing arguments.");
    stdout.writeln(ex);
    stdout.writeln(parser.usage);
    exit(1);
  }

  if (allArgs.wasParsed("help")) {
    stdout.writeln(parser.usage);
    return;
  }

  // Run the main script initially to get the interval
  var initialResult =
      await runMainScript(await allArgs.option("current_directory").toString());
  int frequency = parseInterval(initialResult.stdout) ?? 4;
  // Schedule the task to run at the specified interval
  Timer.periodic(Duration(hours: frequency), (Timer initialTimer) async {
    var result = await runMainScript(
        await allArgs.option("current_directory").toString());

    // Update the interval if it changes
    int newFrequency = parseInterval(result.stdout)!;
    if (newFrequency != frequency) {
      initialTimer.cancel(); // Cancel the current timer
      frequency = newFrequency;
      // Schedule a new timer with the updated interval
      Timer.periodic(Duration(hours: frequency), (Timer t) async {
        await runMainScript(
            await allArgs.option("current_directory").toString());
      });
    }
  });
}

Future<ProcessResult> runMainScript(String CurrentDirectory) async {
  try {
    String agentName = "";
    if (Platform.isLinux) {
      agentName = "/AGENT-LINUX";
    } else if (Platform.isMacOS) {
      agentName = "/AGENT-MACOS";
    } else if (Platform.isWindows) {
      agentName = "/AGENT-WINDOWS";
    } else {
      stdout.writeln('Unsupported platform');
      return ProcessResult(0, 1, '', 'Unsupported platform');
    }
    // Define the command to execute
    var executable = CurrentDirectory + agentName;
    // Execute the compiled binary with arguments
    var arguments = ["--service=true"];
    var result = await Process.run(executable, arguments);

    // Check if the process succeededAgent MAcOS
    if (result.exitCode == 0) {
      stdout.writeln('OCS Inventory Agent executed successfully as a service.');
      stdout.writeln(
          'The agent will run again in ${result.stdout.toString().trim()} hours');
    } else {
      stdout.writeln('Error: OCS Inventory Agent execution failed.');
      stdout.writeln('Details: ${result.stderr}');
    }

    return result;
  } catch (e) {
    stdout.writeln('Error: An issue occurred while executing the agent: $e');
    return ProcessResult(0, 1, '', e.toString());
  }
}

int? parseInterval(String output) {
  // Extract the interval from the output
  return int.tryParse(output.trim());
}
