using Azure.Identity;
using Azure.Messaging.ServiceBus;
using System.Text.Json;

namespace PasswordlessWorkshop.Api.Services;

public class NotificationService
{
    private readonly ServiceBusSender _serviceBusSender;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(IConfiguration configuration, ILogger<NotificationService> logger)
    {
        _logger = logger;

        var serviceBusNamespace = configuration["Azure:ServiceBusNamespace"];
        var queueName = configuration["Azure:ServiceBusQueue"] ?? "notifications";

        // Passwordless authentication using managed identity
        var serviceBusEndpoint = $"{serviceBusNamespace}.servicebus.windows.net";

        // DefaultAzureCredential will automatically use the managed identity when deployed to Azure
        var credential = new DefaultAzureCredential();
        var client = new ServiceBusClient(serviceBusEndpoint, credential);

        _serviceBusSender = client.CreateSender(queueName);

        _logger.LogInformation("NotificationService initialized with namespace {Namespace} and queue {Queue}",
            serviceBusNamespace, queueName);
    }

    public async Task SendRegistrationConfirmationAsync(int eventId, int attendeeId, string attendeeName, string attendeeEmail)
    {
        try
        {
            var notification = new
            {
                Type = "RegistrationConfirmation",
                EventId = eventId,
                AttendeeId = attendeeId,
                AttendeeName = attendeeName,
                AttendeeEmail = attendeeEmail,
                Timestamp = DateTime.UtcNow
            };

            var messageBody = JsonSerializer.Serialize(notification);
            var message = new ServiceBusMessage(messageBody)
            {
                ContentType = "application/json",
                Subject = $"Registration-{eventId}-{attendeeId}"
            };

            await _serviceBusSender.SendMessageAsync(message);
            _logger.LogInformation("Registration confirmation sent for attendee {AttendeeId} at event {EventId}", attendeeId, eventId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending registration confirmation for attendee {AttendeeId} at event {EventId}", attendeeId, eventId);
            throw;
        }
    }

    public async Task SendEventReminderAsync(int eventId, string eventTitle, DateTime eventDate, List<(int Id, string Email, string Name)> attendees)
    {
        try
        {
            var notification = new
            {
                Type = "EventReminder",
                EventId = eventId,
                EventTitle = eventTitle,
                EventDate = eventDate,
                Attendees = attendees.Select(a => new { Id = a.Id, Email = a.Email, Name = a.Name }).ToList(),
                Timestamp = DateTime.UtcNow
            };

            var messageBody = JsonSerializer.Serialize(notification);
            var message = new ServiceBusMessage(messageBody)
            {
                ContentType = "application/json",
                Subject = $"Reminder-{eventId}"
            };

            await _serviceBusSender.SendMessageAsync(message);
            _logger.LogInformation("Event reminder sent for event {EventId} to {AttendeeCount} attendees", eventId, attendees.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending event reminder for event {EventId}", eventId);
            throw;
        }
    }
}