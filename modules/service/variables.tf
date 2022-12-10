variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "image" {
  type = string
}

variable "port" {
  type = string
}

variable "cpu-throttling" {
  type    = bool
  default = true
}

variable "min-instances" {
  type    = number
  default = 0
}

variable "max-instances" {
  type    = number
  default = 2
}

variable "max-concurrency" {
  type = number
  default = 100
}

variable "labels" {
  type    = map(string)
  default = {}
}