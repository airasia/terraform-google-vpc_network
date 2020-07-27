output "network" {
  description = "A reference (self_link) to the VPC network."
  value       = google_compute_network.vpc.self_link
}

output "public_subnet" {
  description = "A reference (self_link) to the Public SubNetwork."
  value       = google_compute_subnetwork.public_subnet.self_link
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

output "ip_range_name_private_k8s_pods" {
  description = "Name of the private subnet IP range for k8s/GKE pods."
  value       = local.ip_ranges.private.k8s.pods.name
}

output "ip_range_name_private_k8s_services" {
  description = "Name of the private subnet IP range for k8s/GKE services."
  value       = local.ip_ranges.private.k8s.svcs.name
}

output "ip_range_private_redis_store" {
  description = "Private subnet IP range for redis MemoryStore."
  value       = local.ip_ranges.private.redis
}

output "ip_range_private_g_services" {
  description = "Private subnet IP range for Google service producers. Eg: CloudSQL, Firebase, Etc."
  value       = local.ip_ranges.private.g_services
}

output "peered_google_services" {
  description = "The google services producers that are peered with the VPC."
  value = [
    google_service_networking_connection.g_services_connection.peering
  ]
}
