variable "location" {
  type = string
}

variable "default_service_id" {
  type = string
}

variable "services" {
  #  type = list(object({ service_id = string, base_path = string }))
  type = map(string)
}

variable "hosts" {
  type = list(string)
}