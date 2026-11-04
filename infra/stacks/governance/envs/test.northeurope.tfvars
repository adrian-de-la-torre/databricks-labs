environment             = "test"
location                = "northeurope"
storage_credential_name = "sc-dbxlab-test"
admin_group             = "labs-platform-admins"

# Agent Cost Control runs in this workspace, and its admin steps grant these.
catalog_users = {
  service_principals = ["sp-agent-ops-analyst", "sp-agentcost-meter"]
  apps               = ["costpilot-ai-accel"]
}
