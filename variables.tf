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
  description = "A map of IP CIDR ranges (including their /x parts) that should be used by the public/private subnets for the various conpoments of the infrastructure. See comments in source code for elaboration on accepted keys."
  type = object({
    public_primary       = string # a CIDR range including /x part (/16 advised) for primary IPs in public subnet of the VPC.
    private_primary      = string # a CIDR range including /x part (/16 advised) for primary IPs in private subnet of the VPC.
    private_k8s_pods     = string # a CIDR range including /x part (/16 advised) for k8s pods in private subnet of the VPC.
    private_k8s_services = string # a CIDR range including /x part (/16 advised) for k8s services in private subnet of the VPC.
    private_redis        = string # a CIDR range including /x part (/29 required) for redis memorystore in private subnet of the VPC. See https://www.terraform.io/docs/providers/google/r/redis_instance.html#reserved_ip_range
    private_g_services   = string # a CIDR range including /x part (/16 advised) for Google services producers (like CloudSQL, Firebase, etc) in private subnet of the VPC.
  })
}

# ----------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ----------------------------------------------------------------------------------------------------------------------

variable "name_vpc_network" {
  description = "Portion of name to be constructed for VPC network."
  type = string
  default = "vpc-network"
}

variable "name_public_subnet" {
  description = "Portion of name to be constructed for public subnet."
  type = string
  default = "public-subnet"
}

variable "name_private_subnet" {
  description = "Portion of name to be constructed for private subnet."
  type = string
  default = "private-subnet"
}

variable "name_cloud_router" {
  description = "Portion of name to be constructed for Cloud Router."
  type = string
  default = "cloud-router"
}

variable "name_cloud_nat" {
  description = "Portion of name to be constructed for Cloud NAT."
  type = string
  default = "cloud-nat"
}

variable "name_g_services_address" {
  description = "Portion of name to be constructed for static GServices IP address."
  type = string
  default = "gservices-address"
}

variable "name_static_nat_ips" {
  description = "Portion of name to be constructed for static/manual NAT IP addresses if value of \"var.num_of_static_nat_ips\" is greater than \"0\"."
  type = string
  default = "nat-manual-ip"
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

variable "vpc_routing_mode" {
  description = "Routing mode of the VPC. A 'GLOBAL' routing mode can have adverse impacts on load balancers. Prefer 'REGIONAL'."
  type        = string
  default     = "REGIONAL"
}

variable "num_of_static_nat_ips" {
  description = "The number of static/manual external IPs that should be reserved by Cloud NAT. Useful when private instances need to communicate with the internet using specific external IPs that maybe whitelisted by 3rd party services."
  type        = number
  default     = 0
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
