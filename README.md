Terraform module for a VPC Network in GCP

# Upgrade guide to v2.6.0

This upgrade eliminates the need to specify `var.ip_ranges.private_redis` for IP ranges.

Make sure to upgrade any use of the [redis_store](https://registry.terraform.io/modules/airasia/redis_store/google/latest) module (if any) to at least `v2.2.0` or above before proceeding with the upgrade of this module.
