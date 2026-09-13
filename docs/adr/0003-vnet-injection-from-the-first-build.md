# 3. VNet injection ships in the first build

Status: accepted

## Context

The obvious plan is to start with the simplest workspace and add networking when a
laboratory needs it.

`virtual_network_id`, `public_subnet_name` and `private_subnet_name` are ForceNew
arguments. Adding them to an existing workspace does not modify it — it destroys
and recreates it.

## Decision

The first workspace is VNet-injected, with two delegated subnets and a network
security group. No laboratory requires it yet.

## Consequences

This contradicts the principle of building the smallest thing that works, and does
so deliberately. The reason is that the window closes: a workspace anchors a Unity
Catalog metastore assignment, and once catalogs, external locations and grants
reference it, replacement stops being a five-minute operation.

The first apply is the only moment this decision is free. Six resources bought now
avoid a migration later that would have no good time to happen.

The network security group is intentionally empty. Databricks injects and manages
the rules it requires; hand-written rules here are a common way to break a
workspace that was working.
