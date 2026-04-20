using System.Diagnostics;
using System.Text.Json.Nodes;
using static System.Environment;

namespace OCSInventory_Service
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private Process? _agentProcess;

        public Worker(ILogger<Worker> logger)
        {
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try
            {
                _logger.LogInformation("Starting service..");

                while (!stoppingToken.IsCancellationRequested)
                {
                    try
                    {
                        var programData = GetFolderPath(SpecialFolder.CommonApplicationData);
                        var configPath = Path.Combine(
                            programData,
                            "OCSInventory-Agent",
                            "config.json"
                        );

                        if (!File.Exists(configPath))
                        {
                            _logger.LogError("Missing config file at {ConfigPath}", configPath);
                            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
                            continue;
                        }

                        var configJson = await File.ReadAllTextAsync(configPath, stoppingToken);
                        var config = JsonNode.Parse(configJson)?.AsObject() ?? new JsonObject();
                        var installDir = config["install_directory"]?.ToString();

                        if (string.IsNullOrWhiteSpace(installDir))
                        {
                            _logger.LogError("Config 'install_directory' is missing or empty");
                            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
                            continue;
                        }

                        var exePath = Path.Combine(installDir, "ocsinventory-agent.exe");
                        if (!File.Exists(exePath))
                        {
                            _logger.LogError("Agent exe not found at {ExePath}", exePath);
                            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
                            continue;
                        }

                        var psi = new ProcessStartInfo
                        {
                            FileName = exePath,
                            Arguments = "--service true",
                            UseShellExecute = false,
                            CreateNoWindow = true,
                            WorkingDirectory = installDir,
                            RedirectStandardOutput = true,
                            RedirectStandardError = true,
                        };

                        _agentProcess = Process.Start(psi);
                        if (_agentProcess == null)
                        {
                            _logger.LogError("Failed to start agent process");
                            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
                            continue;
                        }

                        _agentProcess.OutputDataReceived += (_, e) =>
                        {
                            if (e.Data != null)
                                _logger.LogInformation("{Line}", e.Data);
                        };
                        _agentProcess.ErrorDataReceived += (_, e) =>
                        {
                            if (e.Data != null)
                                _logger.LogError("{Line}", e.Data);
                        };
                        _agentProcess.BeginOutputReadLine();
                        _agentProcess.BeginErrorReadLine();

                        _logger.LogInformation(
                            "Agent process started with PID {Pid}",
                            _agentProcess.Id
                        );

                        await _agentProcess.WaitForExitAsync(stoppingToken);

                        var code = _agentProcess.ExitCode;
                        _logger.LogWarning(
                            "Agent exited with code {ExitCode}. It will be restarted.",
                            code
                        );

                        var delaySeconds = Math.Clamp(code, 1, 30);
                        await Task.Delay(TimeSpan.FromSeconds(delaySeconds), stoppingToken);
                    }
                    catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                    {
                        _logger.LogInformation("Cancellation requested; stopping worker loop.");
                        break;
                    }
                    // Autres erreurs r�elles
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Unhandled error in worker loop.");
                    }
                    finally
                    {
                        _agentProcess?.Dispose();
                        _agentProcess = null;
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // When the stopping token is canceled, for example, a call made from services.msc,
                // we shouldn't exit with a non-zero exit code. In other words, this is expected...
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "{Message}", ex.Message);
                Environment.Exit(1);
            }
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            try
            {
                if (_agentProcess is { HasExited: false })
                {
                    _logger.LogInformation("Stopping agent process PID {Pid}", _agentProcess.Id);
                    _agentProcess.Kill(entireProcessTree: true);
                    await _agentProcess.WaitForExitAsync(cancellationToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error while stopping agent process");
            }
            await base.StopAsync(cancellationToken);
        }
    }
}
