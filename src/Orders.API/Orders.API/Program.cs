using Azure.Messaging.ServiceBus;
using Bogus;
using Newtonsoft.Json;
using Orders.API;

var builder = WebApplication.CreateBuilder(args);

ServiceBusSender _queueClient;

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Configuration.AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);
builder.Configuration.AddEnvironmentVariables();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton(sp =>
{
    ServiceBusClient serviceBusClient = new ServiceBusClient(builder.Configuration.GetValue<string>("servicebusconnectionstring"));
    _queueClient = serviceBusClient.CreateSender(builder.Configuration.GetValue<string>("queuename"));
    return _queueClient;
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.MapPost("/orders/{numberOfOrders}", async (int numberOfOrders, ServiceBusSender queueClient) =>
{
    var orders = new Faker<OrderItem>()
        .RuleFor(o => o.OrderId, (fake) => Guid.NewGuid().ToString())
        .RuleFor(o => o.OrderName, (fake) => fake.Commerce.ProductName())
        .Generate(numberOfOrders);

    foreach (var order in orders)
    {
        await queueClient.SendMessageAsync(new ServiceBusMessage(JsonConvert.SerializeObject(order)));
    }

    return Results.NoContent();
}).WithName("CreateOrders");

app.Run();