namespace PasswordlessWorkshop.Api.Models;

public class Attendee
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Company { get; set; } = string.Empty;

    // Foreign key
    public int EventId { get; set; }
    public Event? Event { get; set; }
}