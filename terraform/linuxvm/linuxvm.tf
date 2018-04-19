provider "azurerm" {}

# Configure Resource Provider for Azure CLI
# Optional if using Azure Cloud Shell
#provider "azurerm" {
#  subscription_id = "..."
#  client_id       = "..."
#  client_secret   = "..."
#  tenant_id       = "..."
#}

variable "rgname" {
  type    = "string"
  default = "myrg"
}
variable "vmname" {
  type    = "string"
  default = "myvm"
}
variable "location" {
  type    = "string"
  default = "westeurope"
}
variable "environmentText" {
  type    = "string"
  default = "Terraform Demo"
}

# Create a resource group
resource "azurerm_resource_group" "myrg" {
  name     = "${var.rgname}"
  location = "${var.location}"
}

# Create a virtual network in the web_servers resource group
resource "azurerm_virtual_network" "myvnet" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.myrg.location}"
  resource_group_name = "${azurerm_resource_group.myrg.name}"
  tags {
    environment = "${var.environmentText}"
  }
}
resource "azurerm_subnet" "mysubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.myrg.name}"
    virtual_network_name = "${azurerm_virtual_network.myvnet.name}"
    address_prefix       = "10.0.1.0/24"
}

resource "azurerm_public_ip" "mypip" {
  name                         = "${format("%s%s", var.vmname, "-pip")}"
  location                     = "${azurerm_resource_group.myrg.location}"
  resource_group_name          = "${azurerm_resource_group.myrg.name}"
  public_ip_address_allocation = "dynamic"
  tags {
    environment = "${var.environmentText}"
  }
}

resource "azurerm_network_security_group" "mynsg" {
  name                = "${format("%s%s", var.vmname, "-nsg")}"
  location            = "${azurerm_resource_group.myrg.location}"
  resource_group_name = "${azurerm_resource_group.myrg.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags {
    environment = "${var.environmentText}"
  }
}

resource "azurerm_network_interface" "mynic" {
  name                = "${format("%s%s", var.vmname, "-nic")}"
  location            = "${azurerm_resource_group.myrg.location}"
  resource_group_name = "${azurerm_resource_group.myrg.name}"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = "${azurerm_subnet.mysubnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.mypip.id}"
  }

  tags {
    environment = "${var.environmentText}"
  }
}

resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.myrg.name}"
  }

  byte_length = 8
}

resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.myrg.name}"
  location                 = "${azurerm_resource_group.myrg.location}"
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags {
    environment = "${var.environmentText}"
  }
}

resource "azurerm_virtual_machine" "myvm" {
  name                  = "${var.vmname}"
  location              = "${azurerm_resource_group.myrg.location}"
  resource_group_name   = "${azurerm_resource_group.myrg.name}"
  network_interface_ids = ["${azurerm_network_interface.mynic.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  storage_data_disk {
    name              = "myDataDisk0"
    managed_disk_type = "Premium_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "127"
  }
  storage_data_disk {
    name              = "myDataDisk1"
    managed_disk_type = "Premium_LRS"
    create_option     = "Empty"
    lun               = 1
    disk_size_gb      = "127"
  }
  storage_data_disk {
    name              = "myDataDisk2"
    managed_disk_type = "Premium_LRS"
    create_option     = "Empty"
    lun               = 2
    disk_size_gb      = "127"
  }
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }
  os_profile {
    computer_name  = "${var.vmname}"
    admin_username = "azureuser"
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBEQvvWt/r1b8J7PPbkdP2zUoj89o5kTOkYTTFMLn+/tvwgGL24EfnKB3+iD+BgCZCzmChTkO2fXxD4ZL6JF1pyRJEPGdM9sWfRBw52EHfqn3LGZ2Ga/fhdfr5GFzqgiLtXskSF2E3PJSXJGDAS93b4+6v4TuiJnMpeuL04TotexpHEBLp29loktvTcXcng3tMb2734PTZwUyKVGiR6zXBUGJxnhZ4xmqzUlAEZboN/1kO7QOAOywqwBdxg1ZQOojrLbI6yu7eQT3kN+DDa40zdlGZVI66nWiHzRAUYDAzVY/pdmho+R22oGMisrlnefpND8Q1EOmJ7g+OU6zwSTaH"
    }
  }
  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
  }
  tags {
    environment = "${var.environmentText}"
  }
}
resource "azurerm_virtual_machine_extension" "mycse" {
    name                  = "${format("%s%s", var.vmname, "-cse")}"
    location              = "${azurerm_resource_group.myrg.location}"
    resource_group_name   = "${azurerm_resource_group.myrg.name}"
    virtual_machine_name  = "${azurerm_virtual_machine.myvm.name}"
    publisher             = "Microsoft.Azure.Extensions"
    type                  = "CustomScript"
    type_handler_version  = "2.0"
    settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/erjosito/AzureBlackMagic/master/ubuntuConfig.sh"],
        "commandToExecute": "sh ./ubuntuConfig.sh"
    }
SETTINGS
}

