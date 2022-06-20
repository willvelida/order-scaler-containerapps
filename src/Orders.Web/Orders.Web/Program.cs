using Microsoft.AspNetCore.Components;
using Microsoft.AspNetCore.Components.Web;
using Orders.Web.Data;
using Orders.Web.Data.Interfaces;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddEnvironmentVariables();

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddHttpClient("Orders", (httpClient) => httpClient.BaseAddress = new Uri(builder.Configuration.GetValue<string>("OrdersApi")));
builder.Services.AddScoped<IOrderServiceClient, OrderServiceClient>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseStaticFiles();

app.UseRouting();

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

app.Run();
