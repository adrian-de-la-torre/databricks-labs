# 4. Terraform owns lifecycle, bundles own laboratories

Status: accepted

## Context

Databricks bundles (renamed Declarative Automation Bundles in March 2026, still
abbreviated DAB) can deploy jobs, pipelines, notebooks and dashboards. Terraform
can deploy the same objects through the Databricks provider. Without a stated
boundary, both end up managing overlapping resources.

A commonly repeated objection — that bundles run Terraform underneath, so provider
versions and state files will conflict — no longer holds. As of CLI 1.16.1 the
default deployment engine is `direct`, built on the Databricks Go SDK, keeping its
own state in `.databricks/bundle/<target>/resources.json`. It does not use
Terraform at all.

## Decision

Terraform owns what outlives a laboratory. A bundle owns one laboratory.

Every `databricks.yml` sets `engine: direct` explicitly, pinning behaviour that
would otherwise change under a CLI upgrade.

## Consequences

The boundary is enforced by the tool, not by policy. A bundle structurally cannot
manage storage credentials, grants, metastores, metastore assignments, network
connectivity configurations, workspace assignments, groups, users, service
principals, IP access lists, workspace bindings or budgets. No rule is needed for
any of them: a bundle cannot reach them.

One asymmetry is worth knowing. A bundle may declare an external location but not
the storage credential it depends on, so a laboratory can consume storage access
but never stand it up.

A laboratory change therefore never triggers a platform apply and never waits on a
platform approval, which is the property that makes experimenting cheap.
