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

provider "random" {
}

resource "random_password" "password" {
  length = 10
}

module "aks" {
  source = "../.."

  product_family     = var.product_family
  product_service    = var.product_service
  environment        = var.environment
  environment_number = var.environment_number
  region             = var.region

  identity_type = var.identity_type

  node_pools = var.node_pools

  kubernetes_version = var.kubernetes_version
  agents_count       = var.agents_count
  agents_size        = var.agents_size
  agents_pool_name   = var.agents_pool_name
  os_disk_size_gb    = var.os_disk_size_gb

  create_application_insights = true

  key_vault_secrets_provider_enabled = true
  secret_rotation_enabled            = true

  log_analytics_workspace_daily_quota_gb = var.log_analytics_workspace_daily_quota_gb

  secrets = {
    username = "test102"
    password = random_password.password.result
  }

  action_group = coalesce(var.action_group, {
    name       = "aks-alert-action-group"
    short_name = "aksag"
    arm_role_receivers = [
      {
        name                    = "aks-monitoring-contributor"
        role_id                 = "b24988ac-6180-42a0-ab88-20f7382dd24c"
        use_common_alert_schema = true
      }
    ]
    email_receivers = [
      {
        name                    = "aks-alert-email"
        email_address           = "aks-alerts@example.com"
        use_common_alert_schema = true
      }
    ]
  })

  metric_alerts = merge(var.metric_alerts, {
    aks_node_cpu_usage_high = {
      description = "Alert when AKS node CPU usage is too high"
      frequency   = "PT5M"
      severity    = 2
      enabled     = true
      criteria = [{
        metric_namespace = "Microsoft.ContainerService/managedClusters"
        metric_name      = "node_cpu_usage_percentage"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = 80
      }]
    },
    aks_node_memory_usage_high = {
      description = "Alert when AKS node memory usage is too high"
      frequency   = "PT5M"
      severity    = 2
      enabled     = true
      criteria = [{
        metric_namespace = "Microsoft.ContainerService/managedClusters"
        metric_name      = "node_memory_rss_percentage"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = 80
      }]
    },
    aks_pod_count_dynamic = {
      description = "Alert on abnormal pod count changes"
      frequency   = "PT5M"
      severity    = 3
      enabled     = true
      criteria    = []
      dynamic_criteria = {
        metric_namespace  = "Microsoft.ContainerService/managedClusters"
        metric_name       = "kube_pod_status_ready"
        aggregation       = "Average"
        operator          = "LessThan"
        alert_sensitivity = "Medium"
      }
    }
  })

  scheduled_query_alerts = merge(var.scheduled_query_alerts, {
    appinsights_request_count_simple = {
      description       = "Simple alert on request volume"
      query             = <<-QUERY
        requests
        | where timestamp > ago(5m)
        | summarize total_requests = count()
      QUERY
      severity          = 2
      frequency         = 5
      time_window       = 5
      trigger_operator  = "GreaterThan"
      trigger_threshold = 50
      email_subject     = "AKS App Insights - Request count threshold breached"
    }
    appinsights_failed_requests_simple = {
      description       = "Simple alert on failed request count"
      query             = <<-QUERY
        requests
        | where timestamp > ago(5m)
        | where success == false
        | summarize failed_requests = count()
      QUERY
      severity          = 2
      frequency         = 5
      time_window       = 5
      trigger_operator  = "GreaterThan"
      trigger_threshold = 1
      email_subject     = "AKS App Insights - Failed request threshold breached"
    }
  })

  tags = var.tags
}
