using Azure.Identity;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace PasswordlessWorkshop.Api.Services;

public class BlobStorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly string _containerName;
    private readonly ILogger<BlobStorageService> _logger;

    public BlobStorageService(IConfiguration configuration, ILogger<BlobStorageService> logger)
    {
        _logger = logger;

        var storageAccountName = configuration["Azure:StorageAccount"];
        _containerName = configuration["Azure:StorageContainer"] ?? "events";

        // Passwordless authentication using managed identity
        var blobUri = new Uri($"https://{storageAccountName}.blob.core.windows.net");

        // DefaultAzureCredential will automatically use the managed identity when deployed to Azure
        var credential = new DefaultAzureCredential();
        _blobServiceClient = new BlobServiceClient(blobUri, credential);

        _logger.LogInformation("BlobStorageService initialized with account {AccountName} and container {ContainerName}",
            storageAccountName, _containerName);
    }

    public async Task<BlobContainerClient> GetContainerAsync()
    {
        try
        {
            var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
            await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);
            return containerClient;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting or creating blob container {ContainerName}", _containerName);
            throw;
        }
    }

    public async Task<string> UploadMaterialsAsync(string eventId, Stream content, string contentType, string fileName)
    {
        try
        {
            var container = await GetContainerAsync();
            var blobName = $"{eventId}/{fileName}";
            var blobClient = container.GetBlobClient(blobName);

            var options = new BlobUploadOptions
            {
                HttpHeaders = new BlobHttpHeaders
                {
                    ContentType = contentType
                }
            };

            await blobClient.UploadAsync(content, options);

            _logger.LogInformation("Successfully uploaded blob {BlobName} for event {EventId}", blobName, eventId);
            return blobClient.Uri.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading materials for event {EventId}", eventId);
            throw;
        }
    }

    public async Task<Stream> DownloadMaterialsAsync(string eventId, string fileName)
    {
        try
        {
            var container = await GetContainerAsync();
            var blobName = $"{eventId}/{fileName}";
            var blobClient = container.GetBlobClient(blobName);

            var response = await blobClient.DownloadAsync();
            _logger.LogInformation("Successfully downloaded blob {BlobName} for event {EventId}", blobName, eventId);

            return response.Value.Content;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading materials for event {EventId}", eventId);
            throw;
        }
    }
}