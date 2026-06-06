# This runs two Linux VMs from separate free-service meters:
# - Standard_B2ats_v2: AMD64 k3s server, 2 vCPU / 1 GiB RAM.
# - Standard_B1s: DNS + Tailscale exit node, 1 vCPU / 1 GiB RAM.


provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "homelab-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.100.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "homelab-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.1.0/24"]
}

resource "azurerm_network_security_group" "dns_exit" {
  name                = "dns-exit-nsg"
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
}

resource "azurerm_public_ip" "dns_exit" {
  name                = "dns-exit-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dns_exit" {
  name                = "dns-exit-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.100.1.20"
    public_ip_address_id          = azurerm_public_ip.dns_exit.id
  }
}

resource "azurerm_network_interface_security_group_association" "dns_exit" {
  network_interface_id      = azurerm_network_interface.dns_exit.id
  network_security_group_id = azurerm_network_security_group.dns_exit.id
}

resource "azurerm_linux_virtual_machine" "dns_exit" {
  name                = "dns-exit-azure"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2ats_v2"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.dns_exit.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "dns-exit-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "almalinux"
    offer     = "almalinux"
    sku       = "9-gen2"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "dns_exit_bootstrap" {
  name                 = "dns-exit-bootstrap"
  virtual_machine_id   = azurerm_linux_virtual_machine.dns_exit.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = jsonencode({
    commandToExecute = <<-EOT
      /bin/bash -lc '
      set -euxo pipefail

      dnf -y update
      dnf -y install curl ca-certificates tar

      curl -fsSL https://tailscale.com/install.sh | sh

      cat >/etc/sysctl.d/99-tailscale-exit-node.conf <<'"'"'SYSCTL'"'"'
      net.ipv4.ip_forward = 1
      net.ipv6.conf.all.forwarding = 1
      SYSCTL
      sysctl --system

      systemctl enable --now tailscaled

      tailscale up \
        --auth-key="${var.tailscale_auth_key}" \
        --hostname="azure-dns-exit" \
        --advertise-exit-node \
        --ssh

      curl -fsSL -o /tmp/AdGuardHome_linux_amd64.tar.gz https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz
      tar -C /opt -xzf /tmp/AdGuardHome_linux_amd64.tar.gz
      /opt/AdGuardHome/AdGuardHome -s install

      systemctl enable --now AdGuardHome
      '
    EOT
  })
}

resource "azurerm_consumption_budget_subscription" "monthly_guardrail" {
  name            = "homelab-monthly-guardrail"
  subscription_id = "/subscriptions/${var.azure_subscription_id}"
  amount          = var.monthly_budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-06-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 75
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }
}
