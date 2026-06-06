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

variable "azure_subscription_id" {
  type      = string
  sensitive = true
}

variable "resource_group_name" {
  type    = string
  default = "homelab"
}

variable "admin_username" {
  type    = string
  default = "ayush"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "tailscale_auth_key" {
  type      = string
  sensitive = true
}

variable "monthly_budget_amount" {
  type    = number
  default = 1
}

variable "budget_alert_emails" {
  type      = list(string)
  sensitive = true
  default   = ["codesbyayush@gmail.com", "2022071030@mmmut.ac.in"]
}

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
