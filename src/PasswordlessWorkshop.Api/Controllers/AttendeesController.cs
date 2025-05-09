using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PasswordlessWorkshop.Api.Data;
using PasswordlessWorkshop.Api.Models;
using PasswordlessWorkshop.Api.Services;

namespace PasswordlessWorkshop.Api.Controllers;

[ApiController]
[Route("api/events/{eventId}/[controller]")]
public class AttendeesController : ControllerBase
{
    private readonly EventsDbContext _dbContext;
    private readonly NotificationService _notificationService;
    private readonly ILogger<AttendeesController> _logger;

    public AttendeesController(
        EventsDbContext dbContext,
        NotificationService notificationService,
        ILogger<AttendeesController> logger)
    {
        _dbContext = dbContext;
        _notificationService = notificationService;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<Attendee>>> GetAttendees(int eventId)
    {
        // Get from database using passwordless SQL connection
        var attendees = await _dbContext.Attendees
            .Where(a => a.EventId == eventId)
            .ToListAsync();

        _logger.LogInformation("Retrieved {Count} attendees for event {EventId} from database", attendees.Count, eventId);
        return attendees;
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<Attendee>> GetAttendee(int eventId, int id)
    {
        // Get from database
        var attendee = await _dbContext.Attendees
            .FirstOrDefaultAsync(a => a.EventId == eventId && a.Id == id);

        if (attendee == null)
        {
            _logger.LogWarning("Attendee {AttendeeId} not found for event {EventId}", id, eventId);
            return NotFound();
        }

        _logger.LogInformation("Retrieved attendee {AttendeeId} for event {EventId} from database", id, eventId);
        return attendee;
    }

    [HttpPost]
    public async Task<ActionResult<Attendee>> RegisterAttendee(int eventId, Attendee attendee)
    {
        // Check if event exists and has capacity
        var eventItem = await _dbContext.Events
            .Include(e => e.Attendees)
            .FirstOrDefaultAsync(e => e.Id == eventId);

        if (eventItem == null)
        {
            _logger.LogWarning("Attempted to register attendee for non-existent event {EventId}", eventId);
            return NotFound($"Event with ID {eventId} not found");
        }

        if (eventItem.Attendees.Count >= eventItem.MaxAttendees)
        {
            _logger.LogWarning("Attempted to register attendee for full event {EventId}", eventId);
            return BadRequest("Event has reached maximum capacity");
        }

        // Set the event ID
        attendee.EventId = eventId;

        // Add to database
        _dbContext.Attendees.Add(attendee);
        await _dbContext.SaveChangesAsync();

        // Send confirmation notification using Azure Service Bus
        await _notificationService.SendRegistrationConfirmationAsync(
            eventId,
            attendee.Id,
            attendee.Name,
            attendee.Email);

        _logger.LogInformation("Registered attendee {AttendeeId} for event {EventId}", attendee.Id, eventId);

        return CreatedAtAction(
            nameof(GetAttendee),
            new { eventId, id = attendee.Id },
            attendee);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> CancelRegistration(int eventId, int id)
    {
        var attendee = await _dbContext.Attendees
            .FirstOrDefaultAsync(a => a.EventId == eventId && a.Id == id);

        if (attendee == null)
        {
            _logger.LogWarning("Attempted to cancel non-existent registration for attendee {AttendeeId} at event {EventId}", id, eventId);
            return NotFound();
        }

        _dbContext.Attendees.Remove(attendee);
        await _dbContext.SaveChangesAsync();

        _logger.LogInformation("Cancelled registration for attendee {AttendeeId} at event {EventId}", id, eventId);

        return NoContent();
    }
}