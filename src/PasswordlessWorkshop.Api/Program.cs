using Azure.Identity;
using Microsoft.EntityFrameworkCore;
using PasswordlessWorkshop.Api.Data;
using PasswordlessWorkshop.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

// Configure logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// Configure Azure services
ConfigureAzureServices(builder);

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

// Initialize database if in development (only for demo purposes)
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<EventsDbContext>();
    dbContext.Database.EnsureCreated();
}

app.Run();

// Helper method to configure Azure services with passwordless authentication
void ConfigureAzureServices(WebApplicationBuilder builder)
{
    // Add KeyVault service
    builder.Services.AddSingleton<KeyVaultService>();

    // Retrieve configuration values from environment variables (Container Apps)
    var sqlServerName = builder.Configuration["AZURE_SQL_SERVER"];
    var sqlDatabaseName = builder.Configuration["AZURE_SQL_DATABASE"];
    var keyVaultUri = builder.Configuration["KEY_VAULT_URI"];

    // Configure Key Vault if URI is provided (non-development)
    if (!string.IsNullOrEmpty(keyVaultUri))
    {
        builder.Configuration.AddAzureKeyVault(
            new Uri(keyVaultUri),
            new DefaultAzureCredential());
    }

    // Configure SQL Database with managed identity (passwordless)
    string connectionString;
    if (builder.Environment.IsDevelopment())
    {
        // In development, use local connection string or emulator
        connectionString = builder.Configuration.GetConnectionString("DefaultConnection") ??
                          "Server=(localdb)\\mssqllocaldb;Database=PasswordlessWorkshop;Trusted_Connection=True;";
    }
    else
    {
        // In production, use managed identity connection
        connectionString = $"Server={sqlServerName};Database={sqlDatabaseName};Authentication=Active Directory Default;TrustServerCertificate=True";
    }

    builder.Services.AddDbContext<EventsDbContext>(options =>
        options.UseSqlServer(connectionString));

    // Register Azure services with passwordless authentication
    builder.Services.AddSingleton<BlobStorageService>();
    builder.Services.AddSingleton<NotificationService>();

    // Add Azure identity services
    builder.Services.AddSingleton<DefaultAzureCredential>(provider =>
        new DefaultAzureCredential(new DefaultAzureCredentialOptions
        {
            ExcludeVisualStudioCredential = !builder.Environment.IsDevelopment(),
            ExcludeAzureCliCredential = !builder.Environment.IsDevelopment(),
            ExcludeManagedIdentityCredential = builder.Environment.IsDevelopment()
        }));
}
