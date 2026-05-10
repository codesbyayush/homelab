variable "do_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "region" {
  type    = string
  default = "blr1"
}

variable "droplet_size" {
  type    = string
  default = "s-2vcpu-4gb"
}

variable "add_workers" {
  type    = bool
  default = false
}

# variable "azure_subscription_id" {
#   type      = string
#   sensitive = true
# }

# variable "resource_group_name" {
#   type    = string
#   default = "homelab"
# }

# variable "admin_username" {
#   type    = string
#   default = "ayush"
# }

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

# variable "server_vm_size" {
#   type    = string
#   default = "Standard_B2ats_v2"
# }

variable "oci_tenancy_ocid" {
  type      = string
  sensitive = true
}

variable "oci_user_ocid" {
  type      = string
  sensitive = true
}

variable "oci_private_key" {
  type      = string
  sensitive = true
}

variable "oci_fingerprint" {
  type      = string
  sensitive = true
}

variable "oci_region" {
  type    = string
  default = "ap-mumbai-1"
}

variable "oci_compartment_ocid" {
  type      = string
  sensitive = true
}

variable "oci_ad_index" {
  type    = number
  default = 1
}
