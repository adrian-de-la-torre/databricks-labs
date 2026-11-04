output "plan_client_id" {
  description = "Client id for the plan identity. Goes into the GitHub secret AZURE_CLIENT_ID_PLAN, for Actions and Dependabot (ADR-0005)."
  value       = azurerm_user_assigned_identity.plan.client_id
}

output "apply_client_ids" {
  description = "Client id per environment. Goes into each GitHub environment as the secret AZURE_CLIENT_ID (ADR-0005)."
  value       = { for k, v in azurerm_user_assigned_identity.apply : k => v.client_id }
}

output "tenant_id" {
  description = "Entra tenant id. Goes into the GitHub secret AZURE_TENANT_ID, for Actions and Dependabot (ADR-0005)."
  value       = data.azurerm_subscription.current.tenant_id
}

output "subscription_id" {
  description = "Azure subscription id. Goes into the GitHub secret AZURE_SUBSCRIPTION_ID, for Actions and Dependabot (ADR-0005)."
  value       = data.azurerm_subscription.current.subscription_id
}
