# 2. Environments are files, not directories

Status: accepted

## Context

Three ways to model environments are common: Terraform CLI workspaces, one
directory per environment, and one code base parameterised by variable files.

CLI workspaces share a single backend, so they are not an isolation boundary — a
credential that can reach one workspace's state can reach them all.

Directory-per-environment guarantees drift. Copies that were meant to stay
identical diverge, and the divergence is invisible until the environment that
matters behaves differently from the one that was tested.

## Decision

A deployment is addressed by a pair of files:

```
envs/<environment>.<region>.tfvars      values
envs/<environment>.<region>.tfbackend   state location
```

One copy of each root's code exists. Adding an environment, a region or a
subscription is a two-file pull request whose entire diff is values.

## Consequences

The reviewer of an environment change sees only what differs, because the code is
shared by construction rather than by discipline.

The decisive argument is a Databricks one. A Unity Catalog metastore is one per
region and scoped to the account, so it spans dev, test and prod simultaneously.
Under directory-per-environment, whichever environment happened to contain it
would become a hidden dependency of the other two. The metastore has no home under
`envs/dev/`, and that is not a stylistic problem — it is a modelling error.
