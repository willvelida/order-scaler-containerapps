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

app.MapPost("/orders", [Topic("dapr-pubsub", "orders")] async (OrderItem order, Container container) =>
{
    Console.WriteLine("Subscriber received: " + order);
    await container.CreateItemAsync(order, new PartitionKey(order.Id));
    return Results.Ok(order);
});

app.Run();

public class OrderItem
{
    public int Id { get; set; }
    public string OrderId { get; set; }
    public string OrderName { get; set; }
}