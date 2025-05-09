using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PasswordlessWorkshop.Api.Data;
using PasswordlessWorkshop.Api.Models;
using PasswordlessWorkshop.Api.Services;

namespace PasswordlessWorkshop.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EventsController : ControllerBase
{
    private readonly EventsDbContext _dbContext;
    private readonly BlobStorageService _blobStorageService;
    private readonly NotificationService _notificationService;
    private readonly ILogger<EventsController> _logger;

    public EventsController(
        EventsDbContext dbContext,
        BlobStorageService blobStorageService,
        NotificationService notificationService,
        ILogger<EventsController> logger)
    {
        _dbContext = dbContext;
        _blobStorageService = blobStorageService;
        _notificationService = notificationService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Event>>> GetEvents()
    {
        // Get events directly from database using passwordless SQL connection
        var events = await _dbContext.Events
            .Include(e => e.Attendees)
            .ToListAsync();

        _logger.LogInformation("Retrieved {Count} events from database", events.Count);
        return events;
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Event>> GetEvent(int id)
    {
        // Get from database
        var eventItem = await _dbContext.Events
            .Include(e => e.Attendees)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (eventItem == null)
        {
            _logger.LogWarning("Event {EventId} not found", id);
            return NotFound();
        }

        _logger.LogInformation("Retrieved event {EventId} from database", id);
        return eventItem;
    }

    [HttpPost]
    public async Task<ActionResult<Event>> CreateEvent(Event eventItem)
    {
        _dbContext.Events.Add(eventItem);
        await _dbContext.SaveChangesAsync();

        _logger.LogInformation("Created new event {EventId}", eventItem.Id);

        return CreatedAtAction(nameof(GetEvent), new { id = eventItem.Id }, eventItem);
    }

    [HttpPost("{id}/materials")]
    public async Task<ActionResult> UploadMaterials(int id, IFormFile file)
    {
        var eventItem = await _dbContext.Events.FindAsync(id);
        if (eventItem == null)
        {
            return NotFound();
        }

        using var stream = file.OpenReadStream();
        var blobUrl = await _blobStorageService.UploadMaterialsAsync(
            id.ToString(),
            stream,
            file.ContentType,
            file.FileName);

        // Update the event with the materials URL
        eventItem.MaterialsBlobUrl = blobUrl;
        await _dbContext.SaveChangesAsync();

        _logger.LogInformation("Uploaded materials for event {EventId}, blob URL: {BlobUrl}", id, blobUrl);

        return Ok(new { blobUrl });
    }

    [HttpGet("{id}/materials/{fileName}")]
    public async Task<ActionResult> DownloadMaterials(int id, string fileName)
    {
        var eventItem = await _dbContext.Events.FindAsync(id);
        if (eventItem == null || string.IsNullOrEmpty(eventItem.MaterialsBlobUrl))
        {
            return NotFound();
        }

        try
        {
            var stream = await _blobStorageService.DownloadMaterialsAsync(id.ToString(), fileName);
            _logger.LogInformation("Downloaded materials for event {EventId}, file: {FileName}", id, fileName);

            // Determine content type (simplified)
            var contentType = "application/octet-stream";
            if (fileName.EndsWith(".pdf")) contentType = "application/pdf";
            else if (fileName.EndsWith(".pptx")) contentType = "application/vnd.openxmlformats-officedocument.presentationml.presentation";
            else if (fileName.EndsWith(".docx")) contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

            return File(stream, contentType, fileName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading materials for event {EventId}, file: {FileName}", id, fileName);
            return StatusCode(500, "Unable to download the requested file");
        }
    }

    [HttpPost("{id}/notify")]
    public async Task<ActionResult> SendEventReminder(int id)
    {
        var eventItem = await _dbContext.Events
            .Include(e => e.Attendees)
            .FirstOrDefaultAsync(e => e.Id == id);

        if (eventItem == null)
        {
            return NotFound();
        }

        var attendeeList = eventItem.Attendees
            .Select(a => (a.Id, a.Email, a.Name))
            .ToList();

        await _notificationService.SendEventReminderAsync(
            eventItem.Id,
            eventItem.Title,
            eventItem.Date,
            attendeeList);

        _logger.LogInformation("Sent event reminder for event {EventId} to {AttendeeCount} attendees",
            id, attendeeList.Count);

        return Ok(new { message = $"Event reminder sent to {attendeeList.Count} attendees" });
    }
}