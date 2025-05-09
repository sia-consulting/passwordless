namespace PasswordlessWorkshop.Api.Models;

public class Event
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime Date { get; set; }
    public string Location { get; set; } = string.Empty;
    public int MaxAttendees { get; set; }
    public string? MaterialsBlobUrl { get; set; }

    // Navigation properties
    public List<Attendee> Attendees { get; set; } = new();
}