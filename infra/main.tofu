# provider "digitalocean" {
#   token = var.do_token
# }

# provider "cloudflare" {
#   api_token = var.cloudflare_api_token
# }

# data "digitalocean_ssh_key" "k3s" {
#   name = "k3s_adguard"
# }

# data "digitalocean_ssh_key" "personal" {
#   name = "Personal laptop ssh key"
# }

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# resource "cloudflare_dns_record" "root_a" {
#   count   = var.enable_public_dns ? 1 : 0
#   zone_id = var.cloudflare_zone_id
#   name    = var.domain
#   type    = "A"
#   content = azurerm_public_ip.k3s.ip_address
#   ttl     = 1
#   proxied = false
# }

# resource "cloudflare_dns_record" "wildcard_a" {
#   count   = var.enable_public_dns ? 1 : 0
#   zone_id = var.cloudflare_zone_id
#   name    = "*"
#   type    = "A"
#   content = azurerm_public_ip.k3s.ip_address
#   ttl     = 1
#   proxied = false
# }

# resource "time_sleep" "wait_for_k3s_server" {
#   depends_on      = [azurerm_linux_virtual_machine.k3s]
#   create_duration = "90s"
#
#   lifecycle {
#     enabled = var.add_workers
#   }
# }

# resource "digitalocean_droplet" "k3s_worker_1" {
#   count      = var.add_workers ? 1 : 0
#   name       = "k3s-worker-1"
#   region     = var.region
#   size       = var.droplet_size
#   image      = "fedora-43-x64"
#   ssh_keys   = [data.digitalocean_ssh_key.k3s.id, data.digitalocean_ssh_key.personal.id]
#   depends_on = [time_sleep.wait_for_k3s_server]
#   user_data  = <<-EOF
#     #!/bin/bash
#     set -euxo pipefail
#
#     dnf -y update
#     dnf -y install curl
#
#     curl -sfL https://get.k3s.io | \`
#       K3S_URL='https://${azurerm_public_ip.k3s.ip_address}:6443' \
#       K3S_TOKEN='${random_password.k3s_token.result}' \
#       sh -
#   EOF
# }
