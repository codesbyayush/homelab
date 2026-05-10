provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "azurerm" {
  features {}
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
  content = azurerm_public_ip.server.ip_address
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "wildcard_a" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "A"
  content = azurerm_public_ip.server.ip_address
  ttl     = 1
  proxied = false
}

resource "time_sleep" "wait_for_k3s_server" {
  depends_on      = [azurerm_linux_virtual_machine.server, azurerm_public_ip.server]
  create_duration = "90s"

  lifecycle {
    enabled = var.add_workers
  }
}

resource "digitalocean_droplet" "k3s_worker_1" {
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

    curl -sfL https://get.k3s.io | \
      K3S_URL='https://${azurerm_public_ip.server.ip_address}:6443' \
      K3S_TOKEN='${random_password.k3s_token.result}' \
      sh -
  EOF

  lifecycle {
    enabled = var.add_workers
  }
}





data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "k3s-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.100.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "k3s-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.1.0/24"]
}

resource "azurerm_network_security_group" "k3s" {
  name                = "k3s-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-k8s-api"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # security_rule {
  #   name                       = "allow-flannel-vxlan"
  #   priority                   = 140
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Udp"
  #   source_port_range          = "*"
  #   destination_port_range     = "8472"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }
}

resource "azurerm_public_ip" "server" {
  name                = "k3s-server-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "server" {
  name                = "k3s-server-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.server.id
  }
}

resource "azurerm_network_interface_security_group_association" "server" {
  network_interface_id      = azurerm_network_interface.server.id
  network_security_group_id = azurerm_network_security_group.k3s.id
}

resource "azurerm_linux_virtual_machine" "server" {
  name                = "k3s-server-azure"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = var.server_vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.server.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "k3s-server-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y curl ca-certificates

    curl -sfL https://get.k3s.io | \
      K3S_TOKEN='${random_password.k3s_token.result}' \
      INSTALL_K3S_EXEC='server --write-kubeconfig-mode 644 --node-external-ip ${azurerm_public_ip.server.ip_address} --cluster-cidr 10.200.0.0/16 --service-cidr 10.201.0.0/16' \
      sh -

    systemctl enable k3s
    systemctl restart k3s
  EOF
  )
}
