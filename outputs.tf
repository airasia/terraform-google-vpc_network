output "network" {
  description = "A reference (self_link) to the VPC network."
  value       = google_compute_network.vpc.self_link
}

output "network_name" {
  description = "The generated name of the VPC network."
  value       = google_compute_network.vpc.name
}

output "network_id" {
  description = "The identifier of the VPC network with format projects/{{project}}/global/networks/{{name}}."
  value       = google_compute_network.vpc.id
}

output "private_subnet" {
  description = "A reference (self_link) to the Private SubNetwork."
  value       = google_compute_subnetwork.private_subnet.self_link
}

output "cloud_router" {
  description = "A reference (self_link) to the Cloud Router."
  value       = google_compute_router.cloud_router.self_link
}

output "cloud_nat_id" {
  description = "A full resource identifier of the Cloud NAT."
  value       = google_compute_router_nat.cloud_nat.id
}

output "cloud_nat_ips_created" {
  description = "External IP addresses created for (but not necessarily attached to) the VPC's Cloud NAT. This will return an empty list if \"var.nat_generate_ips\" is set to \"0\"."
  value       = local.generated_nat_ips.*.address
}

output "cloud_nat_ips_attached" {
  description = "External IP addresses created & attached to the VPC's Cloud NAT. This will return an empty list if \"var.nat_generate_ips\" is set to \"0\"."
  value       = local.selected_nat_ips.*.address
}

output "ip_range_names_private_k8s_pods" {
  description = "Name of the private subnet IP range for k8s/GKE pods."
  value = [
    for range_name in google_compute_subnetwork.private_subnet.secondary_ip_range.*.range_name :
    range_name if length(regexall("pods", range_name)) > 0 # contains "pods" in the name
  ]
}

output "ip_range_names_private_k8s_services" {
  description = "Name of the private subnet IP range for k8s/GKE services."
  value = [
    for range_name in google_compute_subnetwork.private_subnet.secondary_ip_range.*.range_name :
    range_name if length(regexall("svcs", range_name)) > 0 # contains "svcs" in the name
  ]
}

output "ip_ranges_private_redis_store" {
  description = "List of private subnet IP ranges for redis MemoryStore."
  value       = local.ip_ranges.private.redis
}

output "ip_range_private_g_services" {
  description = "Private subnet IP range for Google service producers. Eg: CloudSQL, Firebase, Redis, Memcache Etc."
  value = format(
    "%s/%s",
    google_compute_global_address.g_services_address.address,
    google_compute_global_address.g_services_address.prefix_length
  )
}

output "ip_range_proxy_only" {
  description = "IP range of proxy_only subnet that enables internal HTTP(S) load balancing. See https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balance-ingress#step_3_deploy_a_service_as_a_network_endpoint_group_neg"
  value       = local.create_proxy_only_subnet ? google_compute_subnetwork.proxy_only_subnet.0.ip_cidr_range : null
}

output "ip_ranges_serverless_access" {
  description = "IP ranges for zero or more Serverless VPC Access."
  value       = local.ip_ranges.serverless_access
}

output "peered_google_services" {
  description = "The google services producers that are peered with the VPC."
  value = [
    google_service_networking_connection.g_services_connection.peering
  ]
}

output "global_external_ips" {
  description = ""
  value = { for ip_alias, ip_obj in google_compute_global_address.global_external_ip :
    ip_alias => {
      name    = ip_obj.name
      address = ip_obj.address
    }
  }
}

output "regional_external_ips" {
  description = ""
  value = { for ip_alias, ip_obj in google_compute_address.regional_external_ip :
    ip_alias => {
      name    = ip_obj.name
      address = ip_obj.address
    }
  }
}
