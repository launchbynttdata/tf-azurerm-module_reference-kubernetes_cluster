# with_monitoring

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 1.4.0, < 2.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~>3.67 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_random"></a> [random](#provider\_random) | 3.8.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aks"></a> [aks](#module\_aks) | ../.. | n/a |

## Resources

| Name | Type |
|------|------|
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_product_family"></a> [product\_family](#input\_product\_family) | (Required) Name of the product family for which the resource is created.<br>    Example: org\_name, department\_name. | `string` | `"dso"` | no |
| <a name="input_product_service"></a> [product\_service](#input\_product\_service) | (Required) Name of the product service for which the resource is created.<br>    For example, backend, frontend, middleware etc. | `string` | `"kube"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment in which the resource should be provisioned like dev, qa, prod etc. | `string` | `"dev"` | no |
| <a name="input_environment_number"></a> [environment\_number](#input\_environment\_number) | The environment count for the respective environment. Defaults to 000. Increments in value of 1 | `string` | `"000"` | no |
| <a name="input_region"></a> [region](#input\_region) | Azure Region in which the infra needs to be provisioned | `string` | `"eastus"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Specify which Kubernetes release to use. The default used is the latest Kubernetes version available in the region | `string` | `"1.32"` | no |
| <a name="input_agents_count"></a> [agents\_count](#input\_agents\_count) | The number of Agents that should exist in the Agent Pool. | `number` | `2` | no |
| <a name="input_agents_pool_name"></a> [agents\_pool\_name](#input\_agents\_pool\_name) | The default Azure AKS agentpool (nodepool) name. | `string` | `"default"` | no |
| <a name="input_agents_size"></a> [agents\_size](#input\_agents\_size) | The default virtual machine size for the Kubernetes agents. | `string` | `"Standard_D2_v2"` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | Disk size of nodes in GBs. | `number` | `30` | no |
| <a name="input_log_analytics_workspace_daily_quota_gb"></a> [log\_analytics\_workspace\_daily\_quota\_gb](#input\_log\_analytics\_workspace\_daily\_quota\_gb) | (Optional) The workspace daily quota for ingestion in GB. Defaults to -1 (unlimited) if omitted. | `number` | `null` | no |
| <a name="input_identity_type"></a> [identity\_type](#input\_identity\_type) | (Optional) The type of identity used for the managed cluster. Possible values are `SystemAssigned` and `UserAssigned`. | `string` | `"SystemAssigned"` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | A map of node pool configurations. | <pre>map(object({<br>    name                          = string<br>    node_count                    = optional(number)<br>    tags                          = optional(map(string), {})<br>    vm_size                       = string<br>    mode                          = optional(string)<br>    node_labels                   = optional(map(string), {})<br>    os_sku                        = optional(string)<br>    os_type                       = optional(string)<br>    max_pods                      = optional(number)<br>    min_count                     = optional(number)<br>    max_count                     = optional(number)<br>    enable_auto_scaling           = optional(bool)<br>    eviction_policy               = optional(string)<br>    orchestrator_version          = optional(string)<br>    priority                      = optional(string, "Regular")<br>    spot_max_price                = optional(number, -1)<br>    availability_zones            = optional(list(string))<br>    kubelet_config                = optional(object({}))<br>    linux_os_config               = optional(object({}))<br>    node_taints                   = optional(list(string))<br>    ultra_ssd_enabled             = optional(bool)<br>    capacity_reservation_group_id = optional(string)<br>    host_group_id                 = optional(string)<br>    pod_subnet_id                 = optional(string)<br>    snapshot_id                   = optional(string)<br>    vnet_subnet_id                = optional(string)<br>    upgrade_settings = optional(object({<br>      drain_timeout_in_minutes      = number<br>      node_soak_duration_in_minutes = number<br>      max_surge                     = string<br>    }))<br>    windows_profile = optional(object({<br>      outbound_nat_enabled = optional(bool, true)<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of custom tags to be attached to this module resources | `map(string)` | `{}` | no |
| <a name="input_action_group"></a> [action\_group](#input\_action\_group) | An optional action group object to create. If null, the example will supply a default one. | <pre>object({<br>    name       = string<br>    short_name = string<br>    arm_role_receivers = optional(list(object({<br>      name                    = string<br>      role_id                 = string<br>      use_common_alert_schema = optional(bool)<br>    })), [])<br>    email_receivers = optional(list(object({<br>      name                    = string<br>      email_address           = string<br>      use_common_alert_schema = optional(bool)<br>    })), [])<br>  })</pre> | `null` | no |
| <a name="input_metric_alerts"></a> [metric\_alerts](#input\_metric\_alerts) | A map of additional metric alerts to create alongside the example defaults. | <pre>map(object({<br>    description        = string<br>    frequency          = optional(string, "PT1M")<br>    severity           = optional(number, 3)<br>    enabled            = optional(bool, true)<br>    webhook_properties = optional(map(string))<br>    criteria = optional(list(object({<br>      metric_namespace       = string<br>      metric_name            = string<br>      aggregation            = string<br>      operator               = string<br>      threshold              = number<br>      skip_metric_validation = optional(bool, false)<br>      dimensions = optional(list(object({<br>        name     = string<br>        operator = string<br>        values   = list(string)<br>      })), [])<br>    })))<br>    dynamic_criteria = optional(object({<br>      metric_namespace       = string<br>      metric_name            = string<br>      aggregation            = string<br>      operator               = string<br>      alert_sensitivity      = string<br>      ignore_data_before     = optional(string)<br>      skip_metric_validation = optional(bool, false)<br>      dimensions = optional(list(object({<br>        name     = string<br>        operator = string<br>        values   = list(string)<br>      })), [])<br>    }))<br>  }))</pre> | `{}` | no |
| <a name="input_scheduled_query_alerts"></a> [scheduled\_query\_alerts](#input\_scheduled\_query\_alerts) | A map of scheduled query alerts to create alongside the example defaults. | <pre>map(object({<br>    data_source_id          = optional(string)<br>    description             = optional(string, "")<br>    enabled                 = optional(bool, true)<br>    query                   = string<br>    severity                = optional(number, 1)<br>    frequency               = optional(number, 5)<br>    time_window             = optional(number, 30)<br>    authorized_resource_ids = optional(list(string), [])<br>    trigger_operator        = optional(string, "GreaterThan")<br>    trigger_threshold       = optional(number, 0)<br>    action_group_ids        = optional(list(string), [])<br>    email_subject           = optional(string, "Alert Notification")<br>    custom_webhook_payload  = optional(string, "{}")<br>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kube_config_raw"></a> [kube\_config\_raw](#output\_kube\_config\_raw) | n/a |
| <a name="output_kube_admin_config_raw"></a> [kube\_admin\_config\_raw](#output\_kube\_admin\_config\_raw) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | n/a |
| <a name="output_cluster_identity"></a> [cluster\_identity](#output\_cluster\_identity) | n/a |
<!-- END_TF_DOCS -->
