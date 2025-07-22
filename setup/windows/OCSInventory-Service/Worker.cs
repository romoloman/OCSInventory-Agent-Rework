using System.Diagnostics;
using System.Text.Json.Nodes;
using static System.Environment;

namespace OCSInventory_Service
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;

        private String _configPath =
            GetFolderPath(SpecialFolder.CommonApplicationData) + "/OCSInventory-Agent/config.json";
        private JsonObject _config;

        public Worker(ILogger<Worker> logger)
        {
            _logger = logger;
            _config = JsonNode.Parse(File.ReadAllText(_configPath))?.AsObject() ?? new JsonObject();
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
                        _logger.LogInformation("Service started.");
                        Process
                            .Start(
                                _config["install_directory"]?.ToString()
                                    + "/ocsinventory-agent.exe",
                                "--service true"
                            )
                            .WaitForExit();
                        _logger.LogWarning(
                            "The service will restart. Check agent logs for any errors."
                        );
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "An error occurred while executing the worker.");
                    }
                    finally
                    {
                        await Task.Delay(1000, stoppingToken);
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
    }
}
