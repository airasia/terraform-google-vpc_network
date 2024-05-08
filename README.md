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
  version     = "2.15.0"
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
Error: Error waiting to create GlobalAddress: Error waiting for Creating GlobalAddress: Invalid IP CIDR range: 10.24.0.0/16 conflicts with IP range 10.24.0.0/16 that was allocated by resource projects/PROJECT_ID/global/addresses/gservices-address-tfstg-edsh.
```

This is because of a bug in GCP side where deleting a reserved range before detaching it from the connection will not allow you to recreate the range : 
https://cloud.google.com/vpc/docs/configure-private-services-access#deleting-allocation 


In terraform, the reserved range gets deleted first and then gets detached from the connection because of resource dependencies. So whenever we want to destroy and recreate a reserved range, we will run into this issue. 

To overcome this you have to do the following ,

1) Create a "temp" reserved range and attach only this to the connection, so all the other reserved ranges are detached from the connection :

```
export PROJECT_ID=YOUR_PROJECT_ID
export VPC_NETWORK=NAME_OF_THE_VPC 

gcloud compute addresses create temp \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --description="temporary range" \
    --network=$VPC_NETWORK \
    --project=$PROJECT_ID

gcloud services vpc-peerings update \
   --force \
    --service=servicenetworking.googleapis.com \
    --ranges=temp \
    --network=$VPC_NETWORK  \
    --project=$PROJECT_ID
```

2) Terraform plan and apply. 
3) Delete the "temp" reserved range:

```
gcloud services vpc-peerings update \
   --force \
    --service=servicenetworking.googleapis.com \
    --ranges=temp \
    --network=$VPC_NETWORK  \
    --project=$PROJECT_ID
```

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
