provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "digitalocean_ssh_key" "k3s" {
  name = "k3s_adguard"
}

data "digitalocean_ssh_key" "personal" {
  name = "Personal laptop ssh key"
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "cloudflare_dns_record" "root_a" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "A"
  content = oci_core_instance.server.public_ip
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "wildcard_a" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "A"
  content = oci_core_instance.server.public_ip
  ttl     = 1
  proxied = false
}

resource "time_sleep" "wait_for_k3s_server" {
  depends_on      = [oci_core_instance.server]
  create_duration = "90s"

  lifecycle {
    enabled = var.add_workers
  }
}

resource "digitalocean_droplet" "k3s_worker_1" {
  count      = var.add_workers ? 1 : 0
  name       = "k3s-worker-1"
  region     = var.region
  size       = var.droplet_size
  image      = "fedora-43-x64"
  ssh_keys   = [data.digitalocean_ssh_key.k3s.id, data.digitalocean_ssh_key.personal.id]
  depends_on = [time_sleep.wait_for_k3s_server]
  user_data  = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf -y update
    dnf -y install curl

    curl -sfL https://get.k3s.io | \`
      K3S_URL='https://${oci_core_instance.server.public_ip}:6443' \
      K3S_TOKEN='${random_password.k3s_token.result}' \
      sh -
  EOF
}
