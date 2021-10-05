variable "headless" {
  type    = string
  default = "false"
}

variable "sockets" {
  type    = number
  default = 1
}

variable "cores" {
  type    = number
  default = 4
}

variable "red_network" {
  type    = string
  default = "192.168.122.0/24"
}

locals {
   root_password = "Muster!"
}
