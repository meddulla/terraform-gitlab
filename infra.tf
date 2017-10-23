# Variables
variable "region" {
    default = "westeurope"
}

variable "resource_group" {}

variable "virtual_network_name" {
    default = "GitlabVNET"
}

variable "username" {
    default = "sofia"
}

variable "ssh_key_location" {
    default = "/Users/sofiacardita/.ssh/id_rsa.pub"
}

variable "gitlab_vm_size" {
    default = "Standard_A1_v2"
}

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

# Create a resource group
resource "azurerm_resource_group" "gitlabrg" {
    name = "${var.resource_group}"
    location = "${var.region}"
}

# Create a virtual network in the gitlabrg resource group
resource "azurerm_virtual_network" "network" {
    name = "${var.virtual_network_name}"
    address_space = ["10.0.0.0/8"]
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
}

resource "azurerm_route_table" "gitlabtable" {
  name = "gitlab-route-table"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
}

resource "azurerm_network_security_group" "gitlabsg" {
  name = "gitlab-security-group"
  location = "${var.region}"
  resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
}

resource "azurerm_subnet" "gitlab" {
    name = "gitlab"
    address_prefix = "10.0.1.0/24"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    virtual_network_name = "${azurerm_virtual_network.network.name}"
    route_table_id = "${azurerm_route_table.gitlabtable.id}"
}

resource "azurerm_storage_account" "util_disks_account" {
  name = "${lower(var.resource_group)}utildisk"
  resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
  location = "${var.region}"
  account_type = "Standard_LRS"
}

resource "azurerm_storage_container" "util_disks_container" {
    name = "vhds"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    storage_account_name = "${azurerm_storage_account.util_disks_account.name}"
    container_access_type = "private"
}

resource "azurerm_public_ip" "gitlab1PUBIP" {
    name = "gitlab1PublicIp"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    public_ip_address_allocation = "dynamic"
    domain_name_label = "${var.resource_group}-gitlab1"
}

resource "azurerm_public_ip" "gitlab2PUBIP" {
    name = "gitlab2PublicIp"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    public_ip_address_allocation = "dynamic"
    domain_name_label = "${var.resource_group}-gitlab2"
}

resource "azurerm_network_security_group" "gitlab-sg" {
    name = "allowMasterSecurityGroup"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"

    security_rule {
        name = "allow_http"
        priority = 1010
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "allow_ssh"
        priority = 1000
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "gitlab1NIC" {
    name = "gitlab1nic"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    network_security_group_id = "${azurerm_network_security_group.gitlab-sg.id}"

    ip_configuration {
        name = "gitlab1ipconfiguration"
        subnet_id = "${azurerm_subnet.gitlab.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = "${azurerm_public_ip.gitlab1PUBIP.id}"
    }
}

resource "azurerm_network_interface" "gitlab2NIC" {
    name = "gitlab2nic"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    network_security_group_id = "${azurerm_network_security_group.gitlab-sg.id}"

    ip_configuration {
        name = "gitlab2ipconfiguration"
        subnet_id = "${azurerm_subnet.gitlab.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = "${azurerm_public_ip.gitlab2PUBIP.id}"
    }
}

resource "azurerm_virtual_machine" "gitlab1" {
    name = "gitlab1"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    network_interface_ids = ["${azurerm_network_interface.gitlab1NIC.id}"]
    vm_size = "Standard_A2"
    delete_data_disks_on_termination = "true"
    delete_os_disk_on_termination = "true"

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "16.04.0-LTS"
        version = "latest"
    }

    storage_os_disk {
        name = "gitlab1disk"
        vhd_uri = "${azurerm_storage_account.util_disks_account.primary_blob_endpoint}${azurerm_storage_container.util_disks_container.name}/${azurerm_resource_group.gitlabrg.name}-gitlab11.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    } 

    boot_diagnostics {
        enabled = true
        storage_uri = "${azurerm_storage_account.util_disks_account.primary_blob_endpoint}"
    }

    os_profile {
        computer_name = "gitlab1"
        admin_username = "${var.username}"
        admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file("${var.ssh_key_location}")}"
        }
    }
}

resource "azurerm_virtual_machine" "gitlab2" {
    name = "gitlab2"
    location = "${var.region}"
    resource_group_name = "${azurerm_resource_group.gitlabrg.name}"
    network_interface_ids = ["${azurerm_network_interface.gitlab2NIC.id}"]
    vm_size = "Standard_A0"
    delete_data_disks_on_termination = "true"
    delete_os_disk_on_termination = "true"


    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "16.04.0-LTS"
        version = "latest"
    }

    storage_os_disk {
        name = "gitlab2disk"
        vhd_uri = "${azurerm_storage_account.util_disks_account.primary_blob_endpoint}${azurerm_storage_container.util_disks_container.name}/${azurerm_resource_group.gitlabrg.name}-gitlab12.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    } 

    boot_diagnostics {
        enabled = true
        storage_uri = "${azurerm_storage_account.util_disks_account.primary_blob_endpoint}"
    }

    os_profile {
        computer_name = "gitlab2"
        admin_username = "${var.username}"
        admin_password = "Password1234!"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path = "/home/${var.username}/.ssh/authorized_keys"
            key_data = "${file("${var.ssh_key_location}")}"
        }
    }
}