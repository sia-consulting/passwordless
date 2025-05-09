using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

namespace PasswordlessWorkshop.Api.Services;

public class KeyVaultService
{
    private readonly SecretClient _secretClient;
    private readonly ILogger<KeyVaultService> _logger;

    public KeyVaultService(IConfiguration configuration, ILogger<KeyVaultService> logger)
    {
        _logger = logger;

        var keyVaultUri = configuration["Azure:KeyVaultUri"];

        if (string.IsNullOrEmpty(keyVaultUri))
        {
            throw new ArgumentException("Key Vault URI is not configured", nameof(keyVaultUri));
        }

        // Passwordless authentication using managed identity
        var credential = new DefaultAzureCredential();
        _secretClient = new SecretClient(new Uri(keyVaultUri), credential);

        _logger.LogInformation("KeyVaultService initialized with URI {KeyVaultUri}", keyVaultUri);
    }

    public async Task<string> GetSecretAsync(string secretName)
    {
        try
        {
            var response = await _secretClient.GetSecretAsync(secretName);
            _logger.LogInformation("Successfully retrieved secret {SecretName}", secretName);
            return response.Value.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving secret {SecretName}", secretName);
            throw;
        }
    }

    public async Task<Dictionary<string, string>> GetAllConnectionStringsAsync()
    {
        var connectionStrings = new Dictionary<string, string>();

        try
        {
            // Get SQL connection string
            var sqlConnectionString = await GetSecretAsync("SqlConnectionString");
            connectionStrings.Add("SqlConnectionString", sqlConnectionString);

            // Get Service Bus connection string (though we primarily use managed identity)
            var serviceBusConnectionString = await GetSecretAsync("ServiceBusConnectionString");
            connectionStrings.Add("ServiceBusConnectionString", serviceBusConnectionString);

            // Get Redis connection string
            var redisConnectionString = await GetSecretAsync("RedisConnectionString");
            connectionStrings.Add("RedisConnectionString", redisConnectionString);

            // Get Storage connection string (though we primarily use managed identity)
            var storageConnectionString = await GetSecretAsync("StorageConnectionString");
            connectionStrings.Add("StorageConnectionString", storageConnectionString);

            _logger.LogInformation("Retrieved all connection strings from Key Vault");
            return connectionStrings;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving connection strings from Key Vault");
            throw;
        }
    }
}