variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "repository" {
  type = string
}

variable "chart" {
  type = string
}

variable "values" {
  type = list(string)
}

variable "depends_on" {
  type = list(any)
  default = []
}
