plugin "terraform" {
  enabled = true
  preset  = "all"
}

# terraform_standard_module_structure expects main.tf / variables.tf / outputs.tf,
# which is the layout of a REUSABLE MODULE. These are root stacks, not modules:
# splitting by concern (main.network.tf, main.workspace.tf) is what keeps a growing
# stack readable. Renaming files to satisfy a rule aimed at something else would
# make the repository worse.
rule "terraform_standard_module_structure" {
  enabled = false
}

plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Must match naming.tf string for string: the rule is an exact comparison.
rule "azurerm_resource_missing_tags" {
  enabled = true
  tags    = ["workload", "environment", "managed_by", "repository"]
}
