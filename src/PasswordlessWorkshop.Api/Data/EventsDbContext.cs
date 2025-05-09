using Microsoft.EntityFrameworkCore;
using PasswordlessWorkshop.Api.Models;

namespace PasswordlessWorkshop.Api.Data;

public class EventsDbContext : DbContext
{
    public EventsDbContext(DbContextOptions<EventsDbContext> options) : base(options)
    {
    }

    public DbSet<Event> Events { get; set; } = null!;
    public DbSet<Attendee> Attendees { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure Event entity
        modelBuilder.Entity<Event>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Description).IsRequired().HasMaxLength(500);
            entity.Property(e => e.Location).IsRequired().HasMaxLength(100);
        });

        // Configure Attendee entity
        modelBuilder.Entity<Attendee>(entity =>
        {
            entity.HasKey(a => a.Id);
            entity.Property(a => a.Name).IsRequired().HasMaxLength(100);
            entity.Property(a => a.Email).IsRequired().HasMaxLength(100);
            entity.Property(a => a.Company).IsRequired().HasMaxLength(100);

            // Configure relationship
            entity.HasOne(a => a.Event)
                .WithMany(e => e.Attendees)
                .HasForeignKey(a => a.EventId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Seed data for demo purposes
        modelBuilder.Entity<Event>().HasData(
            new Event
            {
                Id = 1,
                Title = "Azure Passwordless Workshop",
                Description = "Learn about Azure passwordless authentication patterns",
                Date = DateTime.Now.AddDays(30),
                Location = "Virtual",
                MaxAttendees = 50
            },
            new Event
            {
                Id = 2,
                Title = "Secure Your Azure Applications",
                Description = "Best practices for securing Azure applications",
                Date = DateTime.Now.AddDays(60),
                Location = "Munich",
                MaxAttendees = 25
            }
        );
    }
}