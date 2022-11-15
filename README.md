Terraform module for a VPC Network in GCP

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
