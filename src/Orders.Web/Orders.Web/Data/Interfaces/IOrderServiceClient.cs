using Refit;

namespace Orders.Web.Data.Interfaces
{
    public interface IOrderServiceClient
    {
        [Post("//orders/{numberOfOrders}")]
        Task CreateOrders(int numberOfOrders);
    }
}
