using Dapr;
using Microsoft.Azure.Cosmos;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Configuration.AddEnvironmentVariables();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton(sp =>
{
    CosmosClient cosmosClient = new CosmosClient(builder.Configuration.GetValue<string>("cosmosdbconnectionstring"));
    Container orderContainer = cosmosClient.GetContainer(
        builder.Configuration.GetValue<string>("databasename"),
        builder.Configuration.GetValue<string>("containername"));
    return orderContainer;
});
builder.Services.AddApplicationInsightsTelemetry();

var logger = LoggerFactory.Create(config =>
{
    config.AddConsole();
    config.AddApplicationInsights();
}).CreateLogger("Program");

var app = builder.Build();

app.UseCloudEvents();
app.MapSubscribeHandler();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.MapPost("/subscribe", [Topic("dapr-pubsub", "orders")] async (OrderItem order, Container container) =>
{
    try
    {
        logger.LogInformation("Subscriber received: " + order);
        order.Id = Guid.NewGuid().ToString();
        await container.CreateItemAsync(order, new PartitionKey(order.Id));
        return Results.Ok(order);
    }
    catch (Exception ex)
    {
        logger.LogError($"Exception thrown in {nameof(Program)}: {ex.Message}");
        throw;
    }
});

app.Run();

public class OrderItem
{
    public string Id { get; set; }
    public string OrderId { get; set; }
    public string OrderName { get; set; }
}