provider "oci" {
  tenancy_ocid = var.oci_tenancy_ocid
  user_ocid    = var.oci_user_ocid
  private_key  = var.oci_private_key
  fingerprint  = var.oci_fingerprint
  region       = var.oci_region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

resource "oci_core_vcn" "k3s" {
  compartment_id = var.oci_compartment_ocid
  cidr_block     = "10.100.0.0/16"
  display_name   = "k3s-vcn"
  dns_label      = "k3svcn"
}

resource "oci_core_internet_gateway" "k3s" {
  compartment_id = var.oci_compartment_ocid
  vcn_id         = oci_core_vcn.k3s.id
  display_name   = "k3s-igw"
  enabled        = true
}

resource "oci_core_route_table" "k3s" {
  compartment_id = var.oci_compartment_ocid
  vcn_id         = oci_core_vcn.k3s.id
  display_name   = "k3s-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.k3s.id
  }
}

resource "oci_core_security_list" "k3s" {
  compartment_id = var.oci_compartment_ocid
  vcn_id         = oci_core_vcn.k3s.id
  display_name   = "k3s-security-list"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_network_security_group" "k3s_server" {
  compartment_id = var.oci_compartment_ocid
  vcn_id         = oci_core_vcn.k3s.id
  display_name   = "k3s-server-nsg"
}

resource "oci_core_network_security_group_security_rule" "ssh_ingress" {
  network_security_group_id = oci_core_network_security_group.k3s_server.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "SSH"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "http_ingress" {
  network_security_group_id = oci_core_network_security_group.k3s_server.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "HTTP"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "https_ingress" {
  network_security_group_id = oci_core_network_security_group.k3s_server.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = "HTTPS"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_subnet" "k3s" {
  compartment_id             = var.oci_compartment_ocid
  vcn_id                     = oci_core_vcn.k3s.id
  cidr_block                 = "10.100.1.0/24"
  display_name               = "k3s-subnet"
  dns_label                  = "k3ssubnet"
  route_table_id             = oci_core_route_table.k3s.id
  security_list_ids          = [oci_core_security_list.k3s.id]
  prohibit_public_ip_on_vnic = false
}

data "oci_core_images" "oracle_linux_e4" {
  compartment_id           = var.oci_compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "server" {
  compartment_id      = var.oci_compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "k3s-server-oracle"
  shape               = "VM.Standard.E4.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux_e4.images[0].id
    boot_volume_size_in_gbs = 100
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.k3s.id
    assign_public_ip = true
    private_ip       = "10.100.1.10"
    nsg_ids          = [oci_core_network_security_group.k3s_server.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
      #cloud-config
      package_update: true
      packages:
        - curl
        - ca-certificates
        - jq

      runcmd:
        - systemctl restart ssh || systemctl restart sshd
        - curl -sfL https://get.k3s.io | K3S_TOKEN='${random_password.k3s_token.result}' INSTALL_K3S_EXEC='server --write-kubeconfig-mode 644 --cluster-cidr 10.200.0.0/16 --service-cidr 10.201.0.0/16' sh -
        - systemctl enable k3s
        - systemctl restart k3s
    EOF
    )
  }
}
