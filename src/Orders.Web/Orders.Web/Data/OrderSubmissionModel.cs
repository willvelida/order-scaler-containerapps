using System.ComponentModel.DataAnnotations;

namespace Orders.Web.Data
{
    public class OrderSubmissionModel
    {
        [Required]
        [Range(1, 10000000, ErrorMessage = "Please enter a value between 1 and 10000000")]
        public int NumberOfOrders { get; set; }
    }
}
