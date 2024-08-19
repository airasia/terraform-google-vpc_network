Terraform module for a VPC Network in GCP

# Upgrade guide from v2.15.0 to v3.0.0
var.ip_ranges.private_g_services now expects list of CIDR strings instead of just 1 CIDR string so we can have additional CIDR ranges for private service access. 

For example, 

```
module "vpc" {
  source      = "airasia/vpc_network/google"
  version     = "2.15.0"
  name_suffix = local.name_suffix
  ip_ranges = {
    private_primary    = "10.20.0.0/16"
    private_k8s        = [{ pods_rname = "", pods_cidr = "10.21.0.0/16", svcs_rname = "", svcs_cidr = "10.22.0.0/16" }]
    private_redis      = []
    private_g_services = "10.24.0.0/16" # 1 CIDR string
    proxy_only         = "10.25.0.0/26"
    serverless_access  = ["10.26.0.0/28"]
  }
}
```

Needs to be updated the following way : 

```
module "vpc" {
  source      = "airasia/vpc_network/google"
  version     = "3.0.0"
  name_suffix = local.name_suffix
  ip_ranges = {
    private_primary    = "10.20.0.0/16"
    private_k8s        = [{ pods_rname = "", pods_cidr = "10.21.0.0/16", svcs_rname = "", svcs_cidr = "10.22.0.0/16" }]
    private_redis      = []
    private_g_services = ["10.24.0.0/16"] # List of CIDR string
    proxy_only         = "10.25.0.0/26"
    serverless_access  = ["10.26.0.0/28"]
  }
}
```

If you face errors like the following :

```
Error: Error waiting to create GlobalAddress: Error waiting for Creating GlobalAddress: Invalid IP CIDR range: 10.24.0.0/16 conflicts with IP range 10.150.0.0/16 that was allocated by resource projects/PROJECT_ID/global/addresses/gservice-adress
```

This happens because of the concurrency nature of terraform. While terraform is deleting a reserved CIDR range, it's trying to create this same range or a range that overlaps with it at the same time. Re-trying planning and applying steps will solve it.

When changing "private_g_services" values, if plan shows destruction/recreation of resources like redis, cloudsql etc you can plan and apply only the vpc module first to solve this.

# Upgrade guide from v2.14.0 to v2.15.0

Renamed input variables:

```plaintext
num_of_static_nat_ips                    ->  nat_generate_ips_count
name_static_nat_ips                      ->  nat_generate_ips_name
nat_attach_manual_ips                    ->  nat_select_generated_ips
nat_enable_endpoint_independent_mapping  ->  nat_enable_eim
```

Renamed output attributes:

```plaintext
cloud_nat_ips_created  ->  cloud_nat_ips_generated
```
