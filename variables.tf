# ----------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ----------------------------------------------------------------------------------------------------------------------

variable "name_suffix" {
  description = "An arbitrary suffix that will be added to the end of the resource name(s). For example: an environment name, a business-case name, a numeric id, etc."
  type        = string
  validation {
    condition     = length(var.name_suffix) <= 14
    error_message = "A max of 14 character(s) are allowed."
  }
}

variable "ip_ranges" {
  description = <<-EOT
  A map of CIDR IP ranges (including their /x parts) that should be reserved by the VPC for various purposes.

  "private_primary": A CIDR range (/20 advised) for IPs used by VMs / GKE nodes that are provisioned in the private subnet of the VPC. See https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips#cluster_sizing_primary_range

  "private_k8s": List of objects containing name & CIDR ranges for pods (/20 advised) (see https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips#cluster_sizing_secondary_range_pods) & for services (/24 advised) (see https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips#cluster_sizing_secondary_range_svcs) used in a k8s cluster.

  "private_redis": List of CIDR ranges (/29 advised) for Redis instances. Not required for redis instances that use the recommended "PRIVATE_SERVICE_ACCESS" mode. See https://www.terraform.io/docs/providers/google/r/redis_instance.html#reserved_ip_range. See https://cloud.google.com/memorystore/docs/redis/networking#connection_modes.

  "private_g_services": A CIDR range (/20 advised) for Google services producers (like CloudSQL, Firebase, etc) in private subnet of the VPC. See https://cloud.google.com/vpc/docs/configure-private-services-access#allocating-range. See https://cloud.google.com/sql/docs/mysql/configure-private-services-access#configure-access.

  "proxy_only": An empty string or a CIDR range (/24 advised) for Proxy-Only subnet. Use empty string "" or specify null to avoid creating Proxy-Only subnet. See https://cloud.google.com/load-balancing/docs/l7-internal/proxy-only-subnets#proxy_only_subnet_create

  "serverless_access": list of CIDR ranges (/28 required) for Serverless VPC Access. Use empty list [] to avoid reserving CIDR range for serverless_access. See https://www.terraform.io/docs/providers/google/r/vpc_access_connector.html#ip_cidr_range. See https://cloud.google.com/vpc/docs/configure-serverless-vpc-access#create-connector
  
  You can always use an IP calculator like https://www.calculator.net/ip-subnet-calculator.html or https://www.davidc.net/sites/default/subnets/subnets.html for help with calculating subnets & IP ranges.
  EOT
  type = object({
    private_primary    = string
    private_k8s        = list(object({ name = string, pods = string, svcs = string }))
    private_redis      = list(string)
    private_g_services = string
    proxy_only         = string
    serverless_access  = list(string)
  })
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ----------------------------------------------------------------------------------------------------------------------

variable "name_vpc_network" {
  description = "Portion of name to be generated for the VPC network."
  type        = string
  default     = "vpc-network"
}

variable "name_private_subnet" {
  description = "Portion of name to be generated for the private subnet."
  type        = string
  default     = "private-subnet"
}

variable "name_proxy_only_subnet" {
  description = "Portion of name to be generated for the proxy-only subnet."
  type        = string
  default     = "proxy-only-subnet"
}

variable "name_cloud_router" {
  description = "Portion of name to be generated for the Cloud Router."
  type        = string
  default     = "cloud-router"
}

variable "name_cloud_nat" {
  description = "Portion of name to be generated for the Cloud NAT."
  type        = string
  default     = "cloud-nat"
}

variable "name_g_services_address" {
  description = "Portion of name to be generated for the internal IP address that will be created to expose Google services producers (like CloudSQL, Firebase, etc)."
  type        = string
  default     = "gservices-address"
}

variable "name_static_nat_ips" {
  description = "Portion of name to be generated for the static/manual NAT IP addresses if value of \"var.num_of_static_nat_ips\" is greater than \"0\"."
  type        = string
  default     = "nat-manual-ip"
}

variable "nat_min_ports_per_vm" {
  description = "Minimum number of ports reserved by the Cloud NAT for each VM. The number of ports that a Cloud NAT reserves for each VM limits the number of concurrent connections that the VM can make to a specific destination (https://cloud.google.com/nat/docs/ports-and-addresses#ports-and-connections). Each NAT IP supports upto 64,512 ports (65,536 minus 1,024 - https://cloud.google.com/nat/docs/ports-and-addresses#ports). If var.num_of_static_nat_ips is 1 and var.nat_min_ports_per_vm is 64, then the total number of VMs that can be serviced by that Cloud NAT is (1 * 64512 / 64) = 1008 VMs. https://cloud.google.com/nat/docs/ports-and-addresses#port-reservation-examples. As the total number of serviceable VMs increases, the total number of concurrent connections spawnable by a VM decreases. 64 is the default value provided by Google."
  type        = number
  default     = 64
}

variable "nat_enable_endpoint_independent_mapping" {
  type        = bool
  description = "Specifies if endpoint independent mapping is enabled. See https://cloud.google.com/nat/docs/overview#specs-rfcs"
  default     = false
}

variable "vpc_description" {
  description = "The description of the VPC Network."
  type        = string
  default     = "Generated by Terraform"
}

variable "private_subnet_description" {
  description = "The description of the private subnet."
  type        = string
  default     = "Generated by Terraform for private use"
}

variable "proxy_only_subnet_description" {
  description = "The description of the proxy-only subnet."
  type        = string
  default     = "Generated by Terraform for proxy-only subnet. Deploy a NodePort service as a Network Endpoint Group (NEG). Deploy ingress as an internal GCE load-balancer. Validate. See https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balance-ingress#step_3_deploy_a_service_as_a_network_endpoint_group_neg"
}

variable "vpc_routing_mode" {
  description = "Routing mode of the VPC. A 'GLOBAL' routing mode can have adverse impacts on load balancers. Prefer 'REGIONAL'."
  type        = string
  default     = "REGIONAL"
}

variable "num_of_static_nat_ips" {
  description = "The number of static/manual IPs that should be created for the Cloud NAT. Useful when private instances need to communicate with the internet using specific external IPs that must be allowlisted by 3rd party services. The number of IPs created here will be attached (or detached) to the Cloud NAT based on the value of \"var.nat_attach_manual_ips\"."
  type        = number
  default     = 1
}

variable "nat_attach_manual_ips" {
  description = "This value decides whether (or not) (or how many of) the manual IPs created via \"var.num_of_static_nat_ips\" should be attached to the Cloud NAT. Acceptable values are \"ALL\" or \"NONE\" or a string decimal number (eg: \"1\", \"2\", \"11\" etc). Setting a number will attach only the first n number of IPs created via \"var.num_of_static_nat_ips\" allowing you to pre-provision manual NAT IPs before actually attaching them to Cloud NAT."
  type        = string
  default     = "ALL"
}

variable "vpc_timeout" {
  description = "how long a VPC operation is allowed to take before being considered a failure."
  type        = string
  default     = "5m"
}

variable "subnet_timeout" {
  description = "how long a subnet operation is allowed to take before being considered a failure."
  type        = string
  default     = "10m"
}

variable "router_timeout" {
  description = "how long a Cloud Router operation is allowed to take before being considered a failure."
  type        = string
  default     = "5m"
}

variable "nat_timeout" {
  description = "how long a Cloud NAT operation is allowed to take before being considered a failure."
  type        = string
  default     = "10m"
}

variable "external_ips_global" {
  description = <<-EOT
  A list of GLOBAL external IPs to be created that can be used for external load-balancers, GKE
  ingress IPs, etc. See description of each expected field.

  name (MANDATORY): The custom portion for generating a formatted name of the external IP. This
  field is also used by terraform as the output key/alias.

  backward_compatible_fullname (OPTIONAL): The fullname (if provided) that will be used for naming
  the external IP instead of any formatted name auto-generated by the "name" field. This field is
  recommended ONLY FOR backward-compatibility purposes for situations where a pre-existing external
  IP (that doesn't meet the auto-generated naming format) needs to be imported into terraform state.
  This field is NOT RECOMMENDED for generating new external IPs. Can ignore declaring this field if
  not required.
  EOT
  type        = list(map(string))
  default     = []
}

variable "external_ips_regional" {
  description = <<-EOT
  A list of REGIONAL external IPs to be created that can be used for external load-balancers, NGINX
  ingress IPs, Istio Ingress IPs etc. See description of each expected field.

  name (MANDATORY): The custom portion for generating a formatted name of the external IP. This
  field is also used by terraform as the output key/alias.

  backward_compatible_fullname (OPTIONAL): The fullname (if provided) that will be used for naming
  the external IP instead of any formatted name auto-generated by the "name" field. This field is
  recommended ONLY FOR backward-compatibility purposes for situations where a pre-existing external
  IP (that doesn't meet the auto-generated naming format) needs to be imported into terraform state.
  This field is NOT RECOMMENDED for generating new external IPs. Can ignore declaring this field if
  not required.

  region (OPTIONAL): The specific region where the regional external IP will be created. Defaults to
  the Google provider's region if this field is ignored. See
  https://cloud.google.com/compute/docs/regions-zones#available for choice of region values.
  EOT
  type        = list(map(string))
  default     = []
}
