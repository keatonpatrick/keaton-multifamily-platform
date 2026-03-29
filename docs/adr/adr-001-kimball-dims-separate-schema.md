# ADR-001: Kimball-Style Dimensions in Separate Schema

**Status:** Accepted  
**Date:** 2026-03-28  
**Author:** Keaton Patrick

## Context

The platform uses a medallion architecture with bronze, silver, and gold schemas. Dimension tables (property, unit, resident, employee, etc.) need to be accessible to all layers. The question is where they should live.

## Options Considered

**Option A: Dimensions in the gold schema.**  
Pros: Fewer schemas, simpler catalog. Gold is already the "business-ready" layer.  
Cons: Mixes curated reference data with aggregated fact tables. Dims aren't outputs of a pipeline — they're shared infrastructure. Gets messy as the platform grows.

**Option B: Dimensions in their own `dim` schema.**  
Pros: Clean separation of concerns. Dims are referenced by every layer — bronze ingestion keys map to them, silver transformations join against them, gold aggregations group by them. A separate schema reflects their architectural role as master reference data, not as derived outputs. Aligns with Kimball dimensional modeling principles.  
Cons: One more schema to manage.

## Decision

Option B — separate `dim` schema.

## Rationale

Dimension tables are the spine of the data model, not a product of any single pipeline stage. Placing them in gold would imply they're derived from the medallion flow when they're actually the stable reference layer that the medallion flow builds against. A dedicated schema makes this relationship explicit and mirrors how enterprise data teams organize production environments.

## Consequences

- All foreign key references across bronze/silver/gold point to `dim.*` tables
- Dimension table maintenance (new columns, new reference data) is independent of pipeline deployments
- New team members can immediately understand the architecture by looking at the schema list
