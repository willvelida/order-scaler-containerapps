using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Orders.Processor
{
    public class OrderItem
    {
        [JsonProperty(PropertyName = "id")]
        public string id { get; set; }
        public string OrderId { get; set; }
        public string OrderName { get; set; }
    }
}
