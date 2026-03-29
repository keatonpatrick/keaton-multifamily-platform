# Petra Capital Partners — Platform Changelog

**Platform:** keaton_multifamily_platform  
**Cloud:** Azure (South Central US)  
**Databricks:** Premium, Serverless  

---

## Format

```
## [YYYY-MM-DD] — Brief Title
**Author:** Name
**Type:** Infrastructure | Schema | Data | Pipeline | Documentation | Configuration

Description of what changed and why.
```

---

## [2026-03-28] — Initial Platform Setup

**Author:** Keaton Patrick  
**Type:** Infrastructure

### Azure Environment
- Created Azure pay-as-you-go subscription under keatonlpatrick@gmail.com
- Resource group: `databricks-portfolio`
- Set up monthly budget: $100 cap with alerts at 50% ($50) and 90% ($90)
- Alert recipient: keatonlpatrick@gmail.com

### Databricks Workspace
- Created workspace: `keaton-multifamily-platform`
- Region: South Central US
- Tier: Premium (required for Unity Catalog, SQL Warehouses)
- Workspace type: Serverless (Databricks-managed storage and compute)
- Rationale for serverless: eliminates idle cluster costs, auto-scales to zero, ~10-15% premium over classic but impossible to accidentally leave running. At our data volume (~150GB) the cost difference is negligible.

### Unity Catalog — Medallion Architecture
- Catalog: `keaton_multifamily_platform` (auto-provisioned with workspace)
- Created schemas:
  - `bronze` — raw ingested data, untransformed
  - `silver` — cleaned, standardized, deduplicated
  - `gold` — business-ready aggregations and metrics
  - `analytics` — ad-hoc analysis and sandbox
  - `ml` — machine learning assets
- Rationale for schema-per-layer: clean separation of data maturity levels, standard medallion pattern, easy to govern with Unity Catalog permissions

### SQL Warehouse
- Created serverless SQL warehouse: `portfolio-sql-warehouse`
- Size: 2X-Small (4 DBU/h) — sufficient for single-user development on <150GB
- Auto-stop: 10 minutes idle
- Scaling: Min 1, Max 1

### Validation
- Ran workspace validation notebook (`00_workspace_validation`)
- Confirmed: schema creation, Delta table write/read round-trip, catalog metadata
- Created test table `bronze.test_properties` with 3 synthetic Texas properties
- All checks passed

---

## [2026-03-28] — Dimension Table Schema Design

**Author:** Keaton Patrick  
**Type:** Schema

### New Schema
- Created `dim` schema for Kimball-style dimension tables
- Rationale: dims are shared infrastructure referenced by every medallion layer, not outputs of a single layer. Separate schema reflects their role as master reference data. See ADR-001.

### Tables Created (15 total)

**From RealPage (schema-matched):**
- `dim_organization` — org hierarchy
- `dim_building` — physical buildings within properties
- `dim_floor_plan` — unit type definitions (46 columns)
- `dim_unit` — individual apartment units (65 columns)
- `dim_resident` — household-level resident records (31 columns, PII fields as STRING)
- `dim_resident_member` — individual people in households (63 columns)
- `dim_lease_attributes` — core lease details and dates (66 columns)
- `dim_employee` — PMS system-level employee data (19 columns)
- `dim_transaction_code` — charge/credit type definitions
- `dim_move_out_reason` — resident departure reasons
- `dim_concession` — lease incentives
- `dim_renewal` — renewal offers

**Enriched (RealPage base + Petra Capital fields):**
- `dim_property` — master property record. All 35 RealPage columns plus 30 enrichment fields covering regional hierarchy (East/West, Area), investment/ownership (owned vs. third-party managed, fund, valuation), asset classification (class, strategy, type, stabilization status), physical characteristics (4 sqft fields, parking, amenities), and management contacts. ~65 columns total.

**New (not from RealPage):**
- `dim_market` — geographic hierarchy (Region > State > Area)
- `dim_employee_roster` — enriched staff roster with roles, property assignments, and org chart hierarchy. Separate from RealPage DimEmployee (different source/purpose).

### Design Decisions
- PII fields in dim_resident and dim_resident_member use STRING instead of varbinary since synthetic data has no real PII to encrypt. Documented as intentional design choice.
- dim_employee_roster is deliberately separate from dim_employee: one represents PMS system user data (from RealPage), the other represents company HR/organizational master data (internal). Different sources, different update cadences, different purposes.
- RealPage SCD Type 2 patterns (RowStartDate, RowEndDate, RowIsCurrent, IsDeleted, IsLastRow) preserved in all RP-matched tables to demonstrate understanding of slowly changing dimensions.

---

## [2026-03-28] — Documentation Framework

**Author:** Keaton Patrick  
**Type:** Documentation

- Created data dictionary (`docs/data-dictionary.md`) covering all 15 dim tables
- Created this changelog (`docs/changelog.md`)
- Created ADR template and first decision record (ADR-001: Kimball dims in separate schema)
- Established documentation standards: update data dictionary and changelog with every schema change

---

*New entries are added at the top. Each entry includes date, author, type, and rationale for non-obvious decisions.*
