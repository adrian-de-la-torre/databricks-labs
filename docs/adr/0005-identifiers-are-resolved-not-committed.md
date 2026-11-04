# 5. Identifiers are resolved, not committed

Status: accepted. Amends [ADR-0002](0002-environments-are-files.md).

## Context

ADR-0002 addresses a deployment by a pair of files and calls what they hold
values. In practice the values included identifiers: the subscription id inside
every Azure resource id, the client ids of the CI identities, the Databricks
account id, workspace ids and hosts, the name of the state storage account
(eight hex digits of a hash of the subscription id), GitHub's numeric account
and repository ids, and an administrator's email address.

This repository is public. From 13/09 those identifiers were published in its
files, in its history, and in the logs of its workflows, which print every
step's inputs before anything can mask them. A later commit unpublishes
nothing: forks, mirrors and archives keep what they copied. Only stopping the
flow helps.

Most of them were not inputs at all. The workspace URL and id, the access
connector, the catalog storage URL were outputs of the platform stack, copied by
hand into the next stack's tfvars: a second source of truth for each, kept in
step by discipline.

## Decision

The env files carry names, regions and address ranges, nothing else.
Everything a plan needs beyond them is resolved when the plan runs:

| Value | Resolved from |
|---|---|
| Workspace URL, id and resource id; access connector; catalog storage URL | `terraform_remote_state` of that deployment's platform stack |
| Application ids of the CI apply identities | `terraform_remote_state` of bootstrap |
| Application ids of a catalog's consumers | Their names, through data sources |
| State storage account | Its formula: `infra/bootstrap/state-store.sh --name`, passed as `-backend-config` and as `TF_VAR_state_storage_account_name` |
| Its resource id, in bootstrap | The same formula, from the subscription |
| Databricks account id | `DATABRICKS_ACCOUNT_ID`, or the CLI profile that holds it |
| Administrators' user names | `TF_VAR_admin_user_names` |
| GitHub's numeric ids | `TF_VAR_github_owner_id` and `TF_VAR_github_repository_id`, from `gh api` |
| Subscription, tenant and client ids in CI | GitHub secrets rather than variables, because GitHub masks secrets |

`.github/scan/identifiers.py` enforces it in three places: the pre-commit gate,
over every file and over the author and committer a commit is about to carry;
CI, over every commit of a pull request and every commit pushed to main,
messages and authors included; and every Terraform command in CI, whose output
it redacts before the log sees it. Its exceptions are in
`.github/scan/allowed.txt`, each with the reason it belongs to no one.

One exception is an identifier, and it is stated rather than hidden. Commits
are authored with the account's GitHub noreply address, which carries the
numeric account id: GitHub assigns that address, attributes commits through it,
and publishes the same id next to the login. So the files and the workflow logs
are kept free of the id, and commit authorship is not. The repository id, which
a recreation changes and the federated credentials match, appears in no address.

## Consequences

ADR-0002's promise holds: adding an environment is a two-file change whose diff
is values. The values are now ones that can be published.

A stack cannot be planned until the stack it reads has been applied for that
deployment. ADR-0001 already accepted this ordering for applies; it now applies
to plans as well, and each remote state read fails with a message naming the
missing deployment rather than an unsupported attribute.

A plan needs an Azure sign-in to read the other states, and the laptop stacks
need two or three exported variables. The README lists them.

Declaring a catalog's consumers by name changed how its grants are held. One
authoritative `databricks_grants` would revoke whatever it does not declare, and
a person's grant cannot be declared without an email address, so each principal
the governance stack declares is held by its own `databricks_grant`, which
revokes nothing else.

The history before this decision held the same identifiers. It is rewritten
with `git filter-repo`, using the scanner's own matches as the replacement
list, when the repository is recreated. What forks, mirrors and archives copied
before that is beyond reach.
