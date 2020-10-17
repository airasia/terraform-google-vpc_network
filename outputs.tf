output "network" {
  description = "A reference (self_link) to the VPC network."
  value       = google_compute_network.vpc.self_link
}

output "name" {
  description = "The generated name of the VPC network."
  value       = local.vpc_name
}

output "public_subnets" {
  description = "References (self_link) to the Public SubNetworks."
  value = [
    for public_subnet in google_compute_subnetwork.public_subnets : public_subnet.self_link
  ]
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

output "cloud_nat_ips" {
  description = "External IP addresses created (and assigned to private subnet resources) by Cloud NAT if value of \"var.num_of_static_nat_ips\" is greater than \"0\".."
  value       = google_compute_address.static_nat_ips.*.address
}

output "ip_range_names_private_k8s_pods" {
  description = "Name of the private subnet IP range for k8s/GKE pods."
  value = [
    for range_name in google_compute_subnetwork.private_subnet.secondary_ip_range.*.range_name :
    range_name if length(regexall("k8spods", range_name)) > 0 # contains "k8spods" in the name
  ]
}

output "ip_range_names_private_k8s_services" {
  description = "Name of the private subnet IP range for k8s/GKE services."
  value = [
    for range_name in google_compute_subnetwork.private_subnet.secondary_ip_range.*.range_name :
    range_name if length(regexall("k8ssvcs", range_name)) > 0 # contains "k8ssvcs" in the name
  ]
}

output "ip_ranges_private_redis_store" {
  description = "List of private subnet IP ranges for redis MemoryStore."
  value       = local.ip_ranges.private.redis
}

output "ip_range_private_g_services" {
  description = "Private subnet IP range for Google service producers. Eg: CloudSQL, Firebase, Etc."
  value       = local.ip_ranges.private.g_services
}

output "ip_range_proxy_only" {
  description = "IP range of proxy_only subnet that enables internal HTTP(S) load balancing. See https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balance-ingress#step_3_deploy_a_service_as_a_network_endpoint_group_neg"
  value       = local.ip_ranges.proxy_only
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
