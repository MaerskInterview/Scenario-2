provider "azurerm" {
  features {}
}

#############################################################################
# RESOURCES
#############################################################################

resource "azurerm_resource_group" "vnet_main" {
  name     = var.resource_group_name
  location = var.location
}

module "vnet-main" {
  source              = "Azure/vnet/azurerm"
  version             = "~> 2.0"
  resource_group_name = azurerm_resource_group.vnet_main.name
  vnet_name           = var.resource_group_name
  address_space       = [var.vnet_cidr_range]
  subnet_prefixes     = var.subnet_prefixes
  subnet_names        = var.subnet_names
  nsg_ids = {
    subnet1 = azurerm_network_security_group.webports.id
    subnet2 = azurerm_network_security_group.webports.id
  }

  depends_on = [azurerm_resource_group.vnet_main]
}
resource "azurerm_network_security_group" "webports" {
  name                = "webports"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

data "azurerm_key_vault" "key_vault" {
  name                = var.keyvaultname
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "password" {
  name         = "AdminPassword"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

resource "azurerm_network_interface" "nic" {
  count               = length(var.subnet_prefixes)
  name                = "network_interface_${count.index + 1}"
  location            = azurerm_resource_group.vnet_main.location
  resource_group_name = azurerm_resource_group.vnet_main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.vnet-main.vnet_subnets[count.index]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "virtual_machine" {
    count = length(var.subnet_prefixes)
  name                = "virtual-machine-${count.index + 1}"
  resource_group_name = azurerm_resource_group.vnet_main.name
  location            = azurerm_resource_group.vnet_main.location
  size                = "Standard_F2"
  admin_username      = var.adminusername
  admin_password      = data.azurerm_key_vault_secret.password.value
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_storage_account" "azstorageaccount" {
  name                     = "macrolifestorage1"
  resource_group_name      = azurerm_resource_group.vnet_main.name
  location                 = azurerm_resource_group.vnet_main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}