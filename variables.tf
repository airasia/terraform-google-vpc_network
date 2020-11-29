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
  description = "A map of IP CIDR ranges (including their /x parts) that should be used by the public/private subnets for the various components of the infrastructure. See comments in source code for elaboration on accepted keys and suggested IP CIDR ranges. Can use an IP calculator (like https://www.calculator.net/ip-subnet-calculator.html) for help with calculating subnets & IP ranges."
  type = object({
    public             = list(string)                                   # list of CIDR ranges - each with their /x parts (/20 advised) for public subnets of the VPC.
    private_primary    = string                                         # a CIDR range including /x part (/20 advised) for primary IPs in private subnet of the VPC.
    private_k8s        = list(object({ pods = string, svcs = string })) # list of objects of CIDR ranges - each with their /x parts (/20 advised) - for pods & services in a k8s cluster.
    private_redis      = list(string)                                   # list of CIDR ranges - each with their /x parts (/29 advised) - for Redis. See https://www.terraform.io/docs/providers/google/r/redis_instance.html#reserved_ip_range
    private_g_services = string                                         # a CIDR range including /x part (/20 advised) for Google services producers (like CloudSQL, Firebase, etc) in private subnet of the VPC.
    proxy_only         = string                                         # an empty string or a CIDR range including /x part (/24 advised) for Proxy-Only subnet. Use empty string "" to avoid creating Proxy-Only subnet. See https://cloud.google.com/load-balancing/docs/l7-internal/proxy-only-subnets#proxy_only_subnet_create
    serverless_access  = list(string)                                   # list of CIDR ranges - each with their /x parts (/28 advised) for Serverless VPC Access. See https://www.terraform.io/docs/providers/google/r/vpc_access_connector.html#ip_cidr_range
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

variable "name_public_subnets" {
  description = "Common portion of names to be generated for the public subnets."
  type        = string
  default     = "public-subnet"
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
  description = "Portion of name to be generated for the static GServices IP address."
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

variable "vpc_description" {
  description = "The description of the VPC Network."
  type        = string
  default     = "Generated by Terraform"
}

variable "public_subnet_description" {
  description = "The description of the public subnet."
  type        = string
  default     = "Generated by Terraform for public use"
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
  description = "The number of static/manual external IPs that should be reserved by Cloud NAT. Useful when private instances need to communicate with the internet using specific external IPs that maybe whitelisted by 3rd party services."
  type        = number
  default     = 1
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
