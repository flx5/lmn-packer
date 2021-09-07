variable "proxmox_host" {
  type    = string
  default = "localhost:8006"
}

variable "proxmox_user" {
  type      = string
  default   = "root@pam"
  sensitive = true
}

variable "proxmox_password" {
  type      = string
  default   = "vagrant"
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "proxmox"
}

variable "proxmox_iso_pool" {
  type    = string
  default = "local"
}

variable "proxmox_disk_pool" {
  type    = string
  default = "local"
}

variable "proxmox_disk_pool_type" {
  type    = string
  default = "directory"
}

variable "proxmox_disk_format" {
  type    = string
  default = "qcow2"
}
