environment             = "dev"
location                = "northeurope"
storage_credential_name = "sc-dbxlab-dev"
admin_group             = "labs-platform-admins"

# Agent Cost Control runs in this workspace, and its admin steps grant these.
catalog_users = {
  service_principals = ["sp-agent-ops-analyst", "sp-agentcost-meter", "sp-agentcost-model-fit"]
  apps               = ["costpilot-ai-dev", "support-copilot-dev"]
}
