terraform {
  required_version = ">= 0.13.1" # see https://releases.hashicorp.com/terraform/
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
            cidr = k8s_ip_ranges.pods,
            name = format("%s-k8spods-%s", coalesce(k8s_ip_ranges.name, "private"), var.name_suffix)
          },
          {
            cidr = k8s_ip_ranges.svcs,
            name = format("%s-k8ssvcs-%s", coalesce(k8s_ip_ranges.name, "private"), var.name_suffix)
          }
        ]
      ])
      redis      = var.ip_ranges.private_redis # Only reserved here for visibility. Not used in this module.
      g_services = var.ip_ranges.private_g_services
    }
    proxy_only        = var.ip_ranges.proxy_only == null ? "" : var.ip_ranges.proxy_only
    serverless_access = var.ip_ranges.serverless_access # Only reserved here for visibility. Not used in this module.
  }
  # Proxy-Only Subnet ------------------------------------------------------------------------------
  create_proxy_only_subnet = local.ip_ranges.proxy_only == "" ? false : true
  # Cloud NAT --------------------------------------------------------------------------------------
  cloud_router_name      = format("%s-%s", var.name_cloud_router, var.name_suffix)
  cloud_nat_name         = format("%s-%s", var.name_cloud_nat, var.name_suffix)
  all_nat_ips            = google_compute_address.static_nat_ips.*.self_link
  nat_ip_allocate_option = (
    var.num_of_static_nat_ips == 0 ? "AUTO_ONLY" : (
      var.nat_attach_manual_ips == "NONE" ? "AUTO_ONLY" : (
        "MANUAL_ONLY"
  )))
  selected_nat_ips = (
    local.nat_ip_allocate_option == "AUTO_ONLY" ? [] : (
      var.nat_attach_manual_ips == "ALL" ? local.all_nat_ips : (
        var.nat_attach_manual_ips == "NONE" ? [] : (
          slice(local.all_nat_ips, 0, tonumber(var.nat_attach_manual_ips))
  ))))
  # Google Services Peering ------------------------------------------------------------------------
  g_services_address_name          = format("%s-%s", var.name_g_services_address, var.name_suffix)
  g_services_address_ip            = split("/", local.ip_ranges.private.g_services)[0]
  g_services_address_prefix_length = split("/", local.ip_ranges.private.g_services)[1]
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
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER" # required for proxy-only subnets - see https://www.terraform.io/docs/providers/google/r/compute_subnetwork.html
  role          = "ACTIVE"                       # used when purpose = INTERNAL_HTTPS_LOAD_BALANCER - see https://www.terraform.io/docs/providers/google/r/compute_subnetwork.html
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
  count  = var.num_of_static_nat_ips
  name   = "${var.name_static_nat_ips}-${count.index + 1}-${var.name_suffix}"
  region = google_compute_subnetwork.private_subnet.region
}

resource "google_compute_router_nat" "cloud_nat" {
  name                                = local.cloud_nat_name
  router                              = google_compute_router.cloud_router.name
  region                              = google_compute_subnetwork.private_subnet.region
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  nat_ip_allocate_option              = local.nat_ip_allocate_option
  nat_ips                             = local.selected_nat_ips
  min_ports_per_vm                    = var.nat_min_ports_per_vm
  enable_endpoint_independent_mapping = var.nat_enable_endpoint_independent_mapping
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

resource "google_compute_global_address" "g_services_address" {
  name          = local.g_services_address_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.g_services_address_ip
  prefix_length = local.g_services_address_prefix_length
  network       = google_compute_network.vpc.self_link
}

resource "google_service_networking_connection" "g_services_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.g_services_address.name]
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
