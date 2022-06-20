using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using Orders.Processor;

IConfiguration configuration = new ConfigurationBuilder()
    .AddEnvironmentVariables()
    .Build();

ServiceBusClient serviceBusClient = new ServiceBusClient(configuration["servicebusconnectionstring"]);
ServiceBusProcessor processor = serviceBusClient.CreateProcessor(configuration["ordersqueuename"]);
CosmosClient cosmosClient = new CosmosClient(configuration["cosmosdbconnectionstring"]);
Container container = cosmosClient.GetContainer(configuration["databasename"], configuration["containername"]);

try
{
    processor.ProcessMessageAsync += MessageHandler;
    processor.ProcessErrorAsync += ErrorHandler;

    await processor.StartProcessingAsync();

    Console.WriteLine("Processing Messages");

    await processor.StopProcessingAsync();
    Console.WriteLine("Orders Processed");
}
finally
{
    await processor.DisposeAsync();
    await serviceBusClient.DisposeAsync();
    cosmosClient.Dispose();
}

async Task MessageHandler(ProcessMessageEventArgs args)
{
    string body = args.Message.Body.ToString();
    OrderItem order = JsonConvert.DeserializeObject<OrderItem>(body);
    await container.CreateItemAsync(order, new PartitionKey(order.OrderId));
    await args.CompleteMessageAsync(args.Message);
}

Task ErrorHandler(ProcessErrorEventArgs args)
{
    Console.WriteLine(args.Exception.ToString());
    return Task.CompletedTask;
}
