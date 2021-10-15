variable "xcp_keep" {
  type    = string
  default = "never"
}

variable "xen_user" {
  type      = string
  default   = "root"
  sensitive = true
}

variable "xen_password" {
  type      = string
  default   = "Muster!"
  sensitive = true
}

variable "xen_host" {
  type    = string
  default = "localhost"
}

variable "xen_api_port" {
  type    = number
  default = 443
}

variable "xen_ssh_port" {
  type    = number
  default = 22
}
