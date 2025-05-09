####################################################
# interfaces and Public IP
####################################################

locals {
  nic_management_name = "${var.name}mgt"
  nic_inside1_name    = "${var.name}in1"
  nic_outside1_name    = "${var.name}out1"
  nic_outside2_name    = "${var.name}out2"
  pip_outside1_name    = "${var.name}pipo1"
  pip_outside2_name    = "${var.name}pipo2"
}

resource "azurerm_network_interface" "nic_management" {
  resource_group_name = var.resource_group
  name                = local.nic_management_name
  location            = var.location
  ip_configuration {
    primary                       = true
    name                          = local.nic_management_name
    subnet_id                     = var.subnet_management_id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }
  accelerated_networking_enabled = true
  ip_forwarding_enabled          = true
}

resource "azurerm_network_interface" "nic_inside1" {
  resource_group_name   = var.resource_group
  name                  = local.nic_inside1_name
  location              = var.location
  ip_forwarding_enabled = true
  ip_configuration {
    primary                       = true
    name                          = local.nic_inside1_name
    # G0/2 intern 172.16.3.4
    subnet_id                     = var.subnet_inside1_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip_inside
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = var.asa_public_ip_inside1_id
  }
  accelerated_networking_enabled = true
}

resource "azurerm_public_ip" "asa_public_ip_outside1" {
  name                    = local.pip_outside1_name
  location                = var.location
  resource_group_name     = var.resource_group
  allocation_method       = "Static"
  sku                     = "Standard"
  sku_tier                = "Regional"
  idle_timeout_in_minutes = 30
  ip_version              = "IPv4"

}

resource "azurerm_network_interface" "nic_outside1" {
  resource_group_name   = var.resource_group
  name                  = local.nic_outside1_name
  location              = var.location
  ip_forwarding_enabled = true
  ip_configuration {
    primary                       = true
    name                          = local.nic_outside1_name
    subnet_id                     = var.subnet_outside1_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip_outside1
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = azurerm_public_ip.asa_public_ip_outside1.id
  }
  accelerated_networking_enabled = false
}

resource "azurerm_public_ip" "asa_public_ip_outside2" {
  name                    = local.pip_outside2_name
  location                = var.location
  resource_group_name     = var.resource_group
  allocation_method       = "Static"
  sku                     = "Standard"
  sku_tier                = "Regional"
  idle_timeout_in_minutes = 30
  ip_version              = "IPv4"

}

resource "azurerm_network_interface" "nic_outside2" {
  resource_group_name   = var.resource_group
  name                  = local.nic_outside2_name
  location              = var.location
  ip_forwarding_enabled = true
  ip_configuration {
    primary                       = true
    name                          = local.nic_outside2_name
    subnet_id                     = var.subnet_outside2_id
    private_ip_address_allocation = "Static"
    private_ip_address_version    = "IPv4"
    private_ip_address            = var.private_ip_outside2
    # public_ip_address_id          = azurerm_public_ip.asa_public_ip_outside2.id
  }
  accelerated_networking_enabled = false
}

####################################################
# virtual machine
####################################################
resource "azurerm_virtual_machine" "vm" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group
  network_interface_ids = [
    azurerm_network_interface.nic_management.id,
    azurerm_network_interface.nic_inside1.id,
    azurerm_network_interface.nic_outside1.id,
    azurerm_network_interface.nic_outside2.id
  ]
  depends_on                       = [azurerm_network_interface.nic_management, azurerm_network_interface.nic_inside1, azurerm_network_interface.nic_outside1, azurerm_network_interface.nic_outside2]
  primary_network_interface_id     = azurerm_network_interface.nic_management.id
  vm_size                          = var.vm_size
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  plan {
    name      = "asav-azure-byol"
    publisher = "cisco"
    product   = "cisco-asav"
  }
  os_profile {
    computer_name  = var.name
    admin_username = var.username
    admin_password = var.password
    # custom_data    = base64encode(file("cloud-init-cisco-asa.yaml"))
    # custom_data = data.template_file.asa_setup.rendered
  }


  os_profile_linux_config {
    disable_password_authentication = false
  }

  storage_os_disk {
    name              = var.name
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "cisco"
    offer     = "cisco-asav"
    sku       = "asav-azure-byol"
    version   = "92211.0.0"
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = var.storage_uri
  }
}

data "template_file" "asa_setup" {
  template = <<-EOF
          !
          interface GigabitEthernet0/0
          no shutdown
          nameif ${local.nic_inside1_name}
          security-level 100
          ip address dhcp
          !
          interface GigabitEthernet0/1
          no shutdown
          nameif ${local.nic_outside1_name}
          security-level 100
          ip address dhcp
          !
          interface GigabitEthernet0/2
          no shutdown
          nameif ${local.nic_outside2_name}
          security-level 50
          ip address dhcp
          !
          access-list testacl extended permit ip any any
          access-group testacl in interface management
          !
            EOF
}

output "rendered_asa_script" {
  description = "Rendered asa script"
  value       = data.template_file.asa_setup.rendered
}