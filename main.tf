terraform {
  required_version = "0.12.24" # see https://releases.hashicorp.com/terraform/
}

provider "google" {
  version = "3.13.0" # see https://github.com/terraform-providers/terraform-provider-google/releases
}

locals {
  # VPC Net/Subnet names ---------------------------------------------------------------------------
  vpc_name            = format("vpc-network-%s", var.name_suffix)
  subnet_name_public  = format("public-subnet-%s", var.name_suffix)
  subnet_name_private = format("private-subnet-%s", var.name_suffix)
  # VPC IP ranges ----------------------------------------------------------------------------------
  ip_range_public_primary  = "10.10.0.0/16"
  ip_range_private_primary = "10.20.0.0/16"
  private_secondary_ip_ranges = {
    k8s_pods = {
      ip_cidr_range = "10.21.0.0/16"
      range_name    = format("private-k8spods-%s", var.name_suffix)
    },
    k8s_svcs = {
      ip_cidr_range = "10.22.0.0/16"
      range_name    = format("private-k8ssvcs-%s", var.name_suffix)
    },
    redis = {
      ip_cidr_range = "10.23.0.0/29" # must be /29 - see https://www.terraform.io/docs/providers/google/r/redis_instance.html#reserved_ip_range
      range_name    = format("private-redis-%s", var.name_suffix)
    },
    g_services = { # google service producers for CloudSQL, Firebase, Etc
      ip_cidr_range = "10.24.0.0/16"
      range_name    = format("private-gservices-%s", var.name_suffix)
    },
  }
  # Cloud NAT --------------------------------------------------------------------------------------
  cloud_router_name = format("cloud-router-%s", var.name_suffix)
  cloud_nat_name    = format("cloud-nat-%s", var.name_suffix)
  # Google Services Peering ------------------------------------------------------------------------
  g_services_address_name          = format("gservices-address-%s", var.name_suffix)
  g_services_address_ip            = split("/", local.private_secondary_ip_ranges.g_services.ip_cidr_range)[0]
  g_services_address_prefix_length = split("/", local.private_secondary_ip_ranges.g_services.ip_cidr_range)[1]
  # ------------------------------------------------------------------------------------------------
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
  depends_on                      = [google_project_service.networking_api]
  timeouts {
    create = var.vpc_timeout
    update = var.vpc_timeout
    delete = var.vpc_timeout
  }
}

resource "google_compute_subnetwork" "public_subnet" {
  name                     = local.subnet_name_public
  description              = var.public_subnet_description
  network                  = google_compute_network.vpc.self_link
  region                   = data.google_client_config.google_client.region
  private_ip_google_access = true
  ip_cidr_range            = local.ip_range_public_primary
  depends_on               = [google_project_service.networking_api]
  timeouts {
    create = var.subnet_timeout
    update = var.subnet_timeout
    delete = var.subnet_timeout
  }
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = local.subnet_name_private
  description              = var.private_subnet_description
  network                  = google_compute_network.vpc.self_link
  region                   = data.google_client_config.google_client.region
  depends_on               = [google_project_service.networking_api]
  private_ip_google_access = true
  ip_cidr_range            = local.ip_range_private_primary
  dynamic "secondary_ip_range" {
    for_each = {
      for key, value in local.private_secondary_ip_ranges :
      key => value
      if(
        (value.ip_cidr_range != local.private_secondary_ip_ranges.redis.ip_cidr_range)
        &&
        (value.ip_cidr_range != local.private_secondary_ip_ranges.g_services.ip_cidr_range)
      ) # for these IPs to be useable by their resources, they must not already be reserved by the VPC
    }
    content {
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
      range_name    = secondary_ip_range.value.range_name
    }
  }
  timeouts {
    create = var.subnet_timeout
    update = var.subnet_timeout
    delete = var.subnet_timeout
  }
}

resource "google_compute_router" "cloud_router" {
  name       = local.cloud_router_name
  network    = google_compute_network.vpc.self_link
  region     = data.google_client_config.google_client.region
  depends_on = [google_compute_subnetwork.private_subnet, google_project_service.networking_api]
  timeouts {
    create = var.router_timeout
    update = var.router_timeout
    delete = var.router_timeout
  }
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = local.cloud_nat_name
  router                             = google_compute_router.cloud_router.name
  region                             = data.google_client_config.google_client.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  depends_on                         = [google_project_service.networking_api]
  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  nat_ip_allocate_option = "AUTO_ONLY"
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
  depends_on    = [google_project_service.networking_api]
}

resource "google_service_networking_connection" "g_services_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.g_services_address.name]
  depends_on              = [google_project_service.networking_api]
}

data "google_client_config" "google_client" {}
