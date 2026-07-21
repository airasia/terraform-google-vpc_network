terraform {
  required_version = ">= 0.13.1" # see https://releases.hashicorp.com/terraform/
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.42.0" # see https://github.com/terraform-providers/terraform-provider-google/releases
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.42.0" # see https://github.com/terraform-providers/terraform-provider-google-beta/releases
    }
  }
}

locals {
  # VPC Net/Subnet names ---------------------------------------------------------------------------
  vpc_name               = format("%s-%s", var.name_vpc_network, var.name_suffix)
  subnet_name_private    = format("%s-%s", var.name_private_subnet, var.name_suffix)
  subnet_name_proxy_only = format("%s-%s", var.name_proxy_only_subnet, var.name_suffix)
  # VPC IP ranges ----------------------------------------------------------------------------------
  ip_ranges = {
    private = {
      primary = var.ip_ranges.private_primary
      k8s = flatten([
        for k8s_ip_ranges in var.ip_ranges.private_k8s : [
          {
            cidr = k8s_ip_ranges.pods_cidr,
            name = format("%s-%s", coalesce(k8s_ip_ranges.pods_rname, "private-k8spods"), var.name_suffix)
          },
          {
            cidr = k8s_ip_ranges.svcs_cidr,
            name = format("%s-%s", coalesce(k8s_ip_ranges.svcs_rname, "private-k8ssvcs"), var.name_suffix)
          }
        ]
      ])
      redis = var.ip_ranges.private_redis # Only reserved here for visibility. Not used in this module.
    }
    proxy_only        = var.ip_ranges.proxy_only == null ? "" : var.ip_ranges.proxy_only
    serverless_access = var.ip_ranges.serverless_access # Only reserved here for visibility. Not used in this module.
  }
  # Proxy-Only Subnet ------------------------------------------------------------------------------
  create_proxy_only_subnet = local.ip_ranges.proxy_only == "" ? false : true
  # Cloud NAT --------------------------------------------------------------------------------------
  cloud_router_name = format("%s-%s", var.name_cloud_router, var.name_suffix)
  cloud_nat_name    = format("%s-%s", var.name_cloud_nat, var.name_suffix)
  generated_nat_ips = google_compute_address.static_nat_ips
  selected_generated_ips = (
    var.nat_select_generated_ips == "ALL" ? local.generated_nat_ips : (
      var.nat_select_generated_ips == "NONE" ? [] : (
        slice(local.generated_nat_ips, 0, tonumber(var.nat_select_generated_ips))
  )))
  selected_existing_ips  = data.google_compute_addresses.existing_ips.addresses
  selected_ips_for_nat   = concat(local.selected_generated_ips, local.selected_existing_ips)
  nat_ip_allocate_option = length(local.selected_ips_for_nat) == 0 ? "AUTO_ONLY" : "MANUAL_ONLY"
  # Google Services Peering ------------------------------------------------------------------------
  g_services_address_name = format("%s-%s", var.name_g_services_address, var.name_suffix)
  # ------------------------------------------------------------------------------------------------
}

resource "google_project_service" "compute_api" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "networking_api" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                            = local.vpc_name
  description                     = var.vpc_description
  routing_mode                    = var.vpc_routing_mode
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  depends_on                      = [google_project_service.compute_api, google_project_service.networking_api]
  timeouts {
    create = var.vpc_timeout
    update = var.vpc_timeout
    delete = var.vpc_timeout
  }
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = local.subnet_name_private
  description              = var.private_subnet_description
  network                  = google_compute_network.vpc.self_link
  region                   = data.google_client_config.google_client.region
  private_ip_google_access = true
  ip_cidr_range            = local.ip_ranges.private.primary
  dynamic "secondary_ip_range" {
    for_each = local.ip_ranges.private.k8s
    iterator = k8s_object
    content {
      ip_cidr_range = k8s_object.value.cidr
      range_name    = k8s_object.value.name
    }
  }
  timeouts {
    create = var.subnet_timeout
    update = var.subnet_timeout
    delete = var.subnet_timeout
  }
}

resource "google_compute_subnetwork" "proxy_only_subnet" {
  count         = local.create_proxy_only_subnet ? 1 : 0
  provider      = google-beta
  name          = local.subnet_name_proxy_only
  description   = var.proxy_only_subnet_description
  network       = google_compute_network.vpc.self_link
  region        = data.google_client_config.google_client.region
  ip_cidr_range = local.ip_ranges.proxy_only
  purpose       = "REGIONAL_MANAGED_PROXY" # canonical GCP API value; replaces deprecated INTERNAL_HTTPS_LOAD_BALANCER
  role          = "ACTIVE"                 # used when purpose = REGIONAL_MANAGED_PROXY
  timeouts {
    create = var.subnet_timeout
    update = var.subnet_timeout
    delete = var.subnet_timeout
  }
}

resource "google_compute_router" "cloud_router" {
  name    = local.cloud_router_name
  network = google_compute_network.vpc.self_link
  region  = google_compute_subnetwork.private_subnet.region
  timeouts {
    create = var.router_timeout
    update = var.router_timeout
    delete = var.router_timeout
  }
}

resource "google_compute_address" "static_nat_ips" {
  count  = var.nat_generate_ips_count
  name   = "${var.nat_generate_ips_name}-${count.index + 1}-${var.name_suffix}"
  region = google_compute_subnetwork.private_subnet.region
}

data "google_compute_addresses" "existing_ips" {
  filter = join(" OR ", formatlist("(name:%s)", toset(var.nat_attach_pre_existing_ips)))
}

resource "google_compute_router_nat" "cloud_nat" {
  name                                = local.cloud_nat_name
  router                              = google_compute_router.cloud_router.name
  region                              = google_compute_subnetwork.private_subnet.region
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  nat_ip_allocate_option              = local.nat_ip_allocate_option
  nat_ips                             = toset(local.selected_ips_for_nat.*.self_link)
  min_ports_per_vm                    = var.nat_min_ports_per_vm
  enable_endpoint_independent_mapping = var.nat_enable_eim
  enable_dynamic_port_allocation      = var.enable_dynamic_port_allocation
  log_config {
    # If the NAT gateway runs out of NAT IP addresses, Cloud NAT drops packets.
    # Dropped packets are logged when error logging is turned on for Cloud NAT logging.
    # See https://cloud.google.com/nat/docs/ports-and-addresses#addresses
    enable = true
    filter = "ERRORS_ONLY"
  }
  timeouts {
    create = var.nat_timeout
    update = var.nat_timeout
    delete = var.nat_timeout
  }
}

locals {
  # Keyed by numeric string index ("0", "1", ...) so the moved block below can use a static literal key.
  # The first element (index 0) preserves the original singleton name for backward compatibility —
  # upgrading from v2.x does not rename the GCP resource or force-replace the address.
  # Additional ranges get a numeric suffix ("-1", "-2", ...).
  g_service_addresses = {
    for idx, ip_cidr in var.ip_ranges.private_g_services :
    tostring(idx) => {
      ip     = split("/", ip_cidr)[0]
      prefix = split("/", ip_cidr)[1]
      name   = idx == 0 ? local.g_services_address_name : "${local.g_services_address_name}-${idx}"
    }
  }
}

resource "google_compute_global_address" "additional_g_services_address" {
  for_each      = local.g_service_addresses
  name          = each.value.name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = each.value.ip
  prefix_length = each.value.prefix
  network       = google_compute_network.vpc.self_link
}

locals {
  gservice_adress_names = [for key, gservice in local.g_service_addresses :
    google_compute_global_address.additional_g_services_address[key].name
  ]
}

# Migration block: v2.x had a singleton google_compute_global_address.g_services_address.
# v3.x restructured it to a for_each map. This moved block tells Terraform the singleton
# is now tracked at key "0" — no GCP resource is destroyed or recreated on upgrade.
# The literal key "0" is intentional: it matches the tostring(idx) key above and allows
# this block to ship inside the module (moved blocks require static addresses).
moved {
  from = google_compute_global_address.g_services_address
  to   = google_compute_global_address.additional_g_services_address["0"]
}

resource "google_service_networking_connection" "g_services_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = local.gservice_adress_names
}

resource "google_compute_global_address" "global_external_ip" {
  for_each   = { for obj in var.external_ips_global : obj.name => obj }
  name       = lookup(each.value, "backward_compatible_fullname", format("%s-%s", each.value.name, var.name_suffix))
  depends_on = [google_project_service.compute_api, google_project_service.networking_api]
}

resource "google_compute_address" "regional_external_ip" {
  for_each   = { for obj in var.external_ips_regional : obj.name => obj }
  name       = lookup(each.value, "backward_compatible_fullname", format("%s-%s", each.value.name, var.name_suffix))
  region     = lookup(each.value, "region", data.google_client_config.google_client.region)
  depends_on = [google_project_service.compute_api, google_project_service.networking_api]
}

data "google_client_config" "google_client" {}
