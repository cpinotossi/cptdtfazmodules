variable "bastion_sku" {
  description = "The SKU of the Bastion Host. Possible values are 'Basic' or 'Standard'."
  type        = string
  default     = "Standard"
}

variable "resource_group_name" {
  description = "resource group name"
  type        = any
}

variable "name" {
  description = "virtual machine resource name"
  type        = string
}

variable "subnet_id" {
  type        = string
}

variable "location" {
  description = "vnet region location"
  type        = string
}



