// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

variable "product_family" {
  description = <<EOF
    (Required) Name of the product family for which the resource is created.
    Example: org_name, department_name.
  EOF
  type        = string
  default     = "dso"
}

variable "product_service" {
  description = <<EOF
    (Required) Name of the product service for which the resource is created.
    For example, backend, frontend, middleware etc.
  EOF
  type        = string
  default     = "kube"
}

variable "environment" {
  description = "Environment in which the resource should be provisioned like dev, qa, prod etc."
  type        = string
  default     = "dev"
}

variable "environment_number" {
  description = "The environment count for the respective environment. Defaults to 000. Increments in value of 1"
  type        = string
  default     = "000"
}

variable "region" {
  description = "AWS Region in which the infra needs to be provisioned"
  type        = string
  default     = "eastus"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.32"
  description = "Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region"
}

variable "agents_count" {
  type        = number
  default     = 2
  description = "The number of Agents that should exist in the Agent Pool."
}

variable "agents_pool_name" {
  type        = string
  default     = "default"
  description = "The default Azure AKS agentpool (nodepool) name."
  nullable    = false
}

variable "agents_size" {
  type        = string
  default     = "Standard_D2_v2"
  description = "The default virtual machine size for the Kubernetes agents."
}

variable "os_disk_size_gb" {
  type        = number
  default     = 30
  description = "Disk size of nodes in GBs."
}

variable "log_analytics_workspace_daily_quota_gb" {
  type        = number
  default     = null
  description = "(Optional) The workspace daily quota for ingestion in GB. Defaults to -1 (unlimited) if omitted."
}

variable "identity_type" {
  type        = string
  default     = "SystemAssigned"
  description = "(Optional) The type of identity used for the managed cluster. Possible values are `SystemAssigned` and `UserAssigned`."

  validation {
    condition     = var.identity_type == "SystemAssigned" || var.identity_type == "UserAssigned"
    error_message = "`identity_type`'s possible values are `SystemAssigned` and `UserAssigned`"
  }
}

variable "node_pools" {
  type = map(object({
    name                          = string
    node_count                    = optional(number)
    tags                          = optional(map(string), {})
    vm_size                       = string
    mode                          = optional(string)
    node_labels                   = optional(map(string), {})
    os_sku                        = optional(string)
    os_type                       = optional(string)
    max_pods                      = optional(number)
    min_count                     = optional(number)
    max_count                     = optional(number)
    enable_auto_scaling           = optional(bool)
    eviction_policy               = optional(string)
    orchestrator_version          = optional(string)
    priority                      = optional(string, "Regular")
    spot_max_price                = optional(number, -1)
    availability_zones            = optional(list(string))
    kubelet_config                = optional(object({}))
    linux_os_config               = optional(object({}))
    node_taints                   = optional(list(string))
    ultra_ssd_enabled             = optional(bool)
    capacity_reservation_group_id = optional(string)
    host_group_id                 = optional(string)
    pod_subnet_id                 = optional(string)
    snapshot_id                   = optional(string)
    vnet_subnet_id                = optional(string)
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = number
      node_soak_duration_in_minutes = number
      max_surge                     = string
    }))
    windows_profile = optional(object({
      outbound_nat_enabled = optional(bool, true)
    }))
  }))
  default     = {}
  description = "A map of node pool configurations."
}

variable "tags" {
  description = "A map of custom tags to be attached to this module resources"
  type        = map(string)
  default     = {}
}

# Monitor Action Group Properties
variable "action_group" {
  description = "An optional action group object to create. If null, the example will supply a default one."
  type = object({
    name       = string
    short_name = string
    arm_role_receivers = optional(list(object({
      name                    = string
      role_id                 = string
      use_common_alert_schema = optional(bool)
    })), [])
    email_receivers = optional(list(object({
      name                    = string
      email_address           = string
      use_common_alert_schema = optional(bool)
    })), [])
  })
  default = null
}

# Monitor Metric Alert Properties
variable "metric_alerts" {
  description = "A map of additional metric alerts to create alongside the example defaults."
  type = map(object({
    description        = string
    frequency          = optional(string, "PT1M")
    severity           = optional(number, 3)
    enabled            = optional(bool, true)
    webhook_properties = optional(map(string))
    criteria = optional(list(object({
      metric_namespace       = string
      metric_name            = string
      aggregation            = string
      operator               = string
      threshold              = number
      skip_metric_validation = optional(bool, false)
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })), [])
    })))
    dynamic_criteria = optional(object({
      metric_namespace       = string
      metric_name            = string
      aggregation            = string
      operator               = string
      alert_sensitivity      = string
      ignore_data_before     = optional(string)
      skip_metric_validation = optional(bool, false)
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })), [])
    }))
  }))
  default = {}
}
