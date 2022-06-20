using Orders.Web.Data.Interfaces;
using Refit;

namespace Orders.Web.Data
{
    public class OrderServiceClient : IOrderServiceClient
    {
        private IHttpClientFactory _httpClientFactory;

        public OrderServiceClient(IHttpClientFactory httpClientFactory)
        {
            _httpClientFactory=httpClientFactory;
        }

        public async Task CreateOrders(int numberOfOrders)
        {
            var client = _httpClientFactory.CreateClient("Orders");
            await RestService.For<IOrderServiceClient>(client).CreateOrders(numberOfOrders);
        }
    }
}
