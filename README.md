# Petra Capital Partners — Multifamily Data Platform

End-to-end data platform for a 130+ property multifamily real estate portfolio, built on Azure Databricks.

**Stack:** Azure Databricks (Premium, Serverless) · Delta Lake · Unity Catalog · PySpark · SQL · Python

---

## What This Is

A fully functional data platform for **Petra Capital Partners**, a fictional multifamily operator managing ~35,000 units across Texas, Florida, Georgia, Tennessee, and Louisiana. The platform demonstrates how a mid-market operator can consolidate data from multiple source systems into a unified analytics layer.

This is not a toy demo — it mirrors the architecture, schema complexity, and design decisions of a real production data platform.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Source Systems                               │
│  RealPage (PMS)  ·  Knock (CRM)  ·  Birdeye (Reputation)      │
│  Google Ads  ·  Apartments.com (ILS)  ·  Market Data           │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   BRONZE    │  Raw ingested data
                    │  (Landing)  │  Source schemas preserved
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   SILVER    │  Cleaned, typed, deduplicated
                    │ (Conformed) │  Cross-platform standardization
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐  ┌─▼──┐  ┌─────▼─────┐
       │    GOLD     │  │ ML │  │ ANALYTICS  │
       │  (Metrics)  │  │    │  │ (Sandbox)  │
       └─────────────┘  └────┘  └────────────┘
              │
     ┌────────┴────────┐
     │  DIM (Shared)   │  Kimball-style dimensions
     │  Master data    │  Referenced by all layers
     └────────────────┘
```

### Medallion Architecture + Dimensional Model

- **`dim`** — Kimball-style dimension tables. Shared reference data used by every layer. Property, unit, resident, employee, lease, and market dimensions. [ADR-001: Why dims get their own schema](docs/adr/001-kimball-dims-separate-schema.md)
- **`bronze`** — Raw data as received from source systems. Schemas match source (e.g., RealPage BIX) with no transformation.
- **`silver`** — Cleaned, typed, deduplicated. Cross-platform entity resolution happens here.
- **`gold`** — Business-ready KPIs, aggregated metrics, dashboard-ready tables.
- **`analytics`** — Ad-hoc analysis and exploratory work.
- **`ml`** — Feature tables, model inputs/outputs, experiment tracking.

## Data Sources

| Source | Type | What It Provides |
|--------|------|-----------------|
| RealPage (BIX) | PMS | Leases, units, residents, financials, work orders |
| Knock | CRM | Leads, tours, follow-ups, conversion tracking |
| Birdeye | Reputation | Reviews, ratings, response metrics |
| Google Ads | Marketing | Ad spend, impressions, clicks, conversions |
| Apartments.com | ILS | Listing performance, lead attribution |
| Census/ACS | Market | Demographics, economic indicators |

All source data is **synthetic**, generated to match real-world schema structures and statistical distributions. PMS data is modeled on the RealPage BIX schema (553 tables in the real system — we implement the ~40 most operationally relevant).

## Portfolio

Petra Capital Partners operates across five states with two regional divisions:

| Region | States | Markets | Properties |
|--------|--------|---------|------------|
| West | Texas, Louisiana | San Antonio (HQ), Austin, Dallas, Houston, New Orleans | ~65 |
| East | Florida, Georgia, Tennessee | Miami, Tampa, Jacksonville, Atlanta, Savannah, Augusta, Nashville, Memphis | ~65 |

Properties range from 80-unit garden communities to 400+ unit mid-rise developments, across asset classes A through C, including value-add renovations and new lease-ups.

## Dimensional Model

15 dimension tables in the `dim` schema:

| Table | Source | Description |
|-------|--------|-------------|
| `dim_market` | Internal | Geographic hierarchy (Region > State > Area) |
| `dim_organization` | RealPage BIX | Organization hierarchy |
| `dim_property` | RealPage BIX + Enriched | Master property record — 35 RP columns + 30 enrichment fields |
| `dim_building` | RealPage BIX | Physical buildings within properties |
| `dim_floor_plan` | RealPage BIX | Unit type definitions |
| `dim_unit` | RealPage BIX | Individual apartment units |
| `dim_resident` | RealPage BIX | Household-level resident records |
| `dim_resident_member` | RealPage BIX | Individual people within households |
| `dim_lease_attributes` | RealPage BIX | Lease details, dates, and statuses |
| `dim_employee` | RealPage BIX | PMS system-level employee data |
| `dim_employee_roster` | Internal | Enriched staff roster with roles and org chart |
| `dim_transaction_code` | RealPage BIX | Charge/credit type definitions |
| `dim_move_out_reason` | RealPage BIX | Resident departure reasons |
| `dim_concession` | RealPage BIX | Lease incentives |
| `dim_renewal` | RealPage BIX | Renewal offers |

## Infrastructure

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Cloud | Azure | Most common for enterprise Databricks in real estate; aligns with Azure DE cert |
| Databricks Tier | Premium | Required for Unity Catalog, SQL Warehouses |
| Compute | Serverless | Zero idle cost, auto-scales to zero, no cluster management |
| Storage | Unity Catalog Managed | Databricks handles storage layer; no manual blob config |
| Region | South Central US | Texas-based, lowest latency |

## Documentation

- [Data Dictionary](docs/data-dictionary.md) — Every table, column, and relationship
- [Changelog](docs/changelog.md) — What changed, when, and why
- Architecture Decision Records:
  - [ADR-001: Kimball dims in separate schema](docs/adr/001-kimball-dims-separate-schema.md)

## Repository Structure

```
keaton-multifamily-platform/
├── README.md
├── docs/
│   ├── data-dictionary.md
│   ├── changelog.md
│   └── adr/
│       └── 001-kimball-dims-separate-schema.md
├── notebooks/
│   ├── 00_workspace_validation.py
│   ├── 01_dim_table_schemas.sql
│   └── 02_synthetic_portfolio_generation.py
└── src/
    └── (standalone scripts)
```

## About

Built by [Keaton Patrick](https://keatonpatrick.com) as a portfolio project demonstrating full-stack data engineering for multifamily real estate. The platform architecture, schema design, and pipeline patterns reflect real-world production environments.

**Currently at:** Kairoi Residential, San Antonio, TX  
**Looking for:** Full-stack data roles at multifamily operators or PropTech companies  
**Contact:** [keatonpatrick.com](https://keatonpatrick.com) · [LinkedIn](https://linkedin.com/in/keaton-patrick) · [GitHub](https://github.com/keatonpatrick)
