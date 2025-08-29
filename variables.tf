variable "cluster_name" {
  type        = string
  default     = "awx"
  description = "Kind cluster name"
}

variable "k8s_version" {
  type        = string
  default     = "v1.29.2"
  description = "Kind node image k8s version"
}

variable "operator_version" {
  type        = string
  default     = "2.19.1"
  description = "AWX Operator release tag"
}

variable "namespace" {
  type        = string
  default     = "awx"
}