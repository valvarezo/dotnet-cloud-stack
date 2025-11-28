using Microsoft.EntityFrameworkCore;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

// Agregar servicios
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "API Financiera", Version = "v1" });
});

// Configuración de base de datos
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? Environment.GetEnvironmentVariable("CONNECTION_STRING")
    ?? "Host=postgres;Database=financedb;Username=postgres;Password=postgres123";

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

// CORS para el frontend
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Habilitar Swagger (actúa como interfaz de usuario del frontend)
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "API Financiera v1");
    c.RoutePrefix = string.Empty; // Swagger en la raíz
});

app.UseCors("AllowAll");

// Endpoint de salud
app.MapGet("/health", () => Results.Ok(new 
{ 
    status = "healthy",
    timestamp = DateTime.UtcNow,
    service = "finance-api",
    version = "1.0.0"
}))
.WithName("Health")
.WithTags("Salud");

// Verificación de conectividad con base de datos
app.MapGet("/health/db", async (AppDbContext db) =>
{
    try
    {
        var canConnect = await db.Database.CanConnectAsync();
        if (canConnect)
        {
            // Intentar ejecutar una consulta simple
            await db.Database.ExecuteSqlRawAsync("SELECT 1");
            return Results.Ok(new 
            { 
                status = "healthy",
                database = "connected",
                timestamp = DateTime.UtcNow,
                message = "Conexión a base de datos exitosa"
            });
        }
        return Results.Json(new 
        { 
            status = "unhealthy",
            database = "disconnected",
            timestamp = DateTime.UtcNow
        }, statusCode: 503);
    }
    catch (Exception ex)
    {
        return Results.Json(new 
        { 
            status = "unhealthy",
            database = "error",
            timestamp = DateTime.UtcNow,
            error = ex.Message
        }, statusCode: 503);
    }
})
.WithName("DatabaseHealth")
.WithTags("Salud");

// Endpoints CRUD de ejemplo para demostración
app.MapGet("/api/transactions", async (AppDbContext db) =>
{
    var transactions = await db.Transactions.ToListAsync();
    return Results.Ok(transactions);
})
.WithName("GetTransactions")
.WithTags("Transacciones");

app.MapPost("/api/transactions", async (Transaction transaction, AppDbContext db) =>
{
    transaction.CreatedAt = DateTime.UtcNow;
    db.Transactions.Add(transaction);
    await db.SaveChangesAsync();
    return Results.Created($"/api/transactions/{transaction.Id}", transaction);
})
.WithName("CreateTransaction")
.WithTags("Transacciones");

app.MapGet("/api/transactions/{id}", async (int id, AppDbContext db) =>
{
    var transaction = await db.Transactions.FindAsync(id);
    return transaction is not null ? Results.Ok(transaction) : Results.NotFound();
})
.WithName("GetTransaction")
.WithTags("Transacciones");

// Inicializar base de datos al inicio
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        await db.Database.EnsureCreatedAsync();
        Console.WriteLine("✅ Base de datos inicializada exitosamente");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"⚠️ Inicialización de base de datos pendiente: {ex.Message}");
    }
}

app.Run();

// Contexto de Base de Datos
public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
    
    public DbSet<Transaction> Transactions => Set<Transaction>();
}

// Modelo de entidad
public class Transaction
{
    public int Id { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string Type { get; set; } = "debit"; // débito o crédito
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
