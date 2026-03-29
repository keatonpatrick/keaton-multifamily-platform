# Petra Capital Partners — Data Dictionary

**Platform:** keaton_multifamily_platform (Azure Databricks)  
**Maintained by:** Keaton Patrick  
**Last Updated:** 2026-03-28

---

## How to Read This Document

Each table entry includes:
- **Schema / Table** — fully qualified name
- **Source** — where the data originates
- **Grain** — what one row represents
- **Description** — what the table is for
- **Key Relationships** — how it connects to other tables
- **Columns** — name, type, nullable, description

Tables are organized by schema. Within each schema, tables are listed in logical dependency order (parents before children).

---

## Schema: `dim`

Kimball-style dimension tables. Shared reference data used across all medallion layers. These are the master records that bronze/silver/gold tables join against.

Design decision: dims live in their own schema rather than gold because they're shared infrastructure, not outputs. See [ADR-001](adr/001-kimball-dims-separate-schema.md).

---

### `dim.dim_market`

| | |
|---|---|
| **Source** | Internal — Petra Capital geographic hierarchy |
| **Grain** | One row per metro area |
| **Description** | Geographic hierarchy for portfolio segmentation and drill-down reporting. Not sourced from any PMS — this is company-defined master data. |
| **Key Relationships** | Referenced by `dim_property.MarketKey` and `dim_employee_roster.MarketKey` |

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| MarketKey | INT | No | Surrogate key |
| Region | STRING | No | East or West division |
| StateName | STRING | No | Full state name |
| StateCode | STRING | No | Two-letter abbreviation |
| Area | STRING | No | Metro area grouping (e.g., "San Antonio" includes Boerne, New Braunfels) |
| MSAName | STRING | Yes | Metropolitan Statistical Area official name |
| MSAFIPS | STRING | Yes | MSA FIPS code — used for joining to Census/HUD data |
| IsActive | STRING | No | Y/N — whether this market is actively managed |
| RecordCreatedDate | TIMESTAMP | No | Row creation timestamp |
| RecordModifiedDate | TIMESTAMP | Yes | Last modification timestamp |

---

### `dim.dim_organization`

| | |
|---|---|
| **Source** | RealPage BIX — DimOrganization (schema-matched) |
| **Grain** | One row per organization (SCD Type 2 — versioned) |
| **Description** | Top-level organizational entity. In our case, Petra Capital Partners is the primary organization. |
| **Key Relationships** | Referenced by `dim_property.OrganizationKey` |

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| OrganizationKey | INT | No | Surrogate key |
| OrganizationName | STRING | Yes | Organization name |
| OrganizationType | STRING | Yes | PMC, Owner, Investor, etc. |
| CompanyID | STRING | Yes | RP internal company identifier |
| RowStartDate | TIMESTAMP | No | SCD2 effective start |
| RowEndDate | TIMESTAMP | No | SCD2 effective end |
| RowIsCurrent | STRING | No | Y/N — current version flag |
| RecordCreatedDate | TIMESTAMP | Yes | Record creation timestamp |
| RecordModifiedDate | TIMESTAMP | Yes | Last modification timestamp |

---

### `dim.dim_property`

| | |
|---|---|
| **Source** | RealPage BIX — DimProperty (all 35 columns) + Petra Capital enrichment |
| **Grain** | One row per property |
| **Description** | The spine of the entire data model. Every table in the platform joins back to PropertyKey. Base columns match the RP BIX schema exactly. Enrichment fields add regional hierarchy, investment/ownership data, asset classification, physical characteristics, and management contacts. This is master data maintained by the data team — not just a copy of what RealPage provides. |
| **Key Relationships** | `OrganizationKey` → `dim_organization`, `MarketKey` → `dim_market`. Referenced by nearly every other table via `PropertyKey`. |

**RealPage BIX Columns (35):**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| PropertyKey | INT | No | Primary join key across the entire platform |
| OrganizationKey | INT | No | FK to dim_organization |
| PropertyName | STRING | Yes | Display name |
| PropertyNumber | STRING | Yes | Internal property number/code |
| PropertyAddress1 | STRING | Yes | Street address line 1 |
| PropertyAddress2 | STRING | Yes | Street address line 2 |
| PropertyAddress3 | STRING | Yes | Street address line 3 |
| PropertyCity | STRING | Yes | City |
| PropertyStateProvinceCode | STRING | Yes | State abbreviation |
| PropertyPostalCode | STRING | Yes | ZIP code |
| PropertyCountryCode | STRING | Yes | Country code |
| ClaimedUnitCount | SMALLINT | Yes | Total unit count per RP |
| PropertyStatus | STRING | Yes | Active, Inactive, etc. |
| osl_PropertyID | INT | No | OneSite Leasing property ID |
| osl_PMCID | INT | Yes | OneSite PMC ID |
| IsDeleted | STRING | No | Soft delete flag |
| RowStartDate | TIMESTAMP | Yes | SCD2 effective start |
| RowEndDate | TIMESTAMP | Yes | SCD2 effective end |
| RowIsCurrent | STRING | Yes | Current version flag |
| IsLastRow | STRING | Yes | Last row for this entity |
| CDSExtractDate | TIMESTAMP | Yes | Last CDS extract date |
| ModifyDate | TIMESTAMP | Yes | Last modified in source |
| PropertySourceCode | INT | Yes | Source system code |
| AccountingPropertyID | STRING | Yes | Property ID in accounting system |
| ExternalPropertyIdentifier | STRING | Yes | External/third-party identifier |
| Phone | STRING | Yes | Primary phone |
| Phone2 | STRING | Yes | Secondary phone |
| FaxPhone | STRING | Yes | Fax number |
| EmailAddress | STRING | Yes | Primary property email |
| WebAddress | STRING | Yes | Property website URL |
| PropertyType | STRING | Yes | Conventional, Affordable, etc. |
| PropertySubType | STRING | Yes | Property subtype |
| RecordCreatedDate | TIMESTAMP | Yes | RP record creation |
| RecordModifiedDate | TIMESTAMP | Yes | RP record modification |
| YSM_Postdate | TIMESTAMP | Yes | Yield Star Management post date |

**Enrichment — Regional Hierarchy:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| MarketKey | INT | Yes | FK to dim_market |
| Region | STRING | Yes | East or West |
| Area | STRING | Yes | Metro area grouping |

**Enrichment — Investment / Ownership:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| OwnershipType | STRING | Yes | Owned or Third-Party Managed |
| OwnerName | STRING | Yes | Petra fund entity or third-party owner name |
| OwnerContactName | STRING | Yes | Primary contact at owning entity |
| OwnerContactEmail | STRING | Yes | Owner contact email |
| AcquisitionDate | DATE | Yes | Date acquired or took over management |
| AcquisitionPrice | DECIMAL(14,2) | Yes | Purchase price (NULL for third-party managed) |
| CurrentValuation | DECIMAL(14,2) | Yes | Most recent property valuation |
| FundName | STRING | Yes | Petra Fund III, Petra Fund IV, etc. |
| OwnershipEntity | STRING | Yes | LLC that holds title |
| OwnershipPercentage | DECIMAL(5,2) | Yes | Petra ownership stake |

**Enrichment — Asset Classification:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| PropertyClass | STRING | Yes | A, B+, B, B-, C |
| AssetStrategy | STRING | Yes | Core, Core-Plus, Value-Add, Opportunistic |
| AssetType | STRING | Yes | Garden, Mid-Rise, High-Rise, BTR, Mixed |
| StabilizationStatus | STRING | Yes | Lease-Up or Stabilized |
| VintageYear | INT | Yes | Year originally built |
| YearRenovated | INT | Yes | Most recent major renovation year |
| RenovationBudget | DECIMAL(12,2) | Yes | Total renovation budget |

**Enrichment — Physical Characteristics:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| TotalSquareFootage | INT | Yes | Total property square footage |
| RentableSquareFootage | INT | Yes | Total rentable sqft across all units |
| CommonAreaSquareFootage | INT | Yes | Clubhouse, gym, hallways, etc. |
| RetailCommercialSquareFootage | INT | Yes | Retail/commercial if mixed-use |
| TotalAcreage | DECIMAL(6,2) | Yes | Total property acreage |
| ParkingSpaces | INT | Yes | Total parking spaces |
| ParkingType | STRING | Yes | Surface, Garage, Mixed, None |
| AmenityTier | STRING | Yes | Standard, Premium, Luxury |
| PetPolicy | STRING | Yes | Breed Restricted, Weight Restricted, Unrestricted, No Pets |
| Latitude | DECIMAL(10,7) | Yes | Property latitude |
| Longitude | DECIMAL(10,7) | Yes | Property longitude |

**Enrichment — Management Contacts:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| ManagementEmail | STRING | Yes | Property management office email |
| AccountingManagerName | STRING | Yes | Assigned accounting manager |
| AccountingManagerEmail | STRING | Yes | Accounting manager email |

---

### `dim.dim_building`

| | |
|---|---|
| **Source** | RealPage BIX — DimBuilding (schema-matched) |
| **Grain** | One row per building (SCD Type 2) |
| **Description** | Physical buildings within a property. One property can have multiple buildings. Contains address, construction dates, and physical characteristics per building. |
| **Key Relationships** | `PropertyKey` → `dim_property`. Referenced by `dim_unit.BuildingKey`. |

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| BuildingKey | INT | No | Surrogate key |
| PropertyKey | INT | No | FK to dim_property |
| BuildingName | STRING | Yes | Building name |
| BuildingNumber | STRING | Yes | Building number/code |
| NumberOfFloors | TINYINT | Yes | Floor count |
| Address1 | STRING | Yes | Building street address |
| Address2 | STRING | Yes | Address line 2 |
| Address3 | STRING | Yes | Address line 3 |
| City | STRING | Yes | City |
| State | STRING | Yes | State |
| Zip | STRING | Yes | ZIP code |
| County | STRING | Yes | County |
| Province | STRING | Yes | Province (for international) |
| BlockNumber | STRING | Yes | Block number |
| BuildingType | STRING | Yes | Building structure type |
| ConstructionStartDate | TIMESTAMP | Yes | Construction start |
| ConstructionEndDate | TIMESTAMP | Yes | Construction completion |
| FirstOccupiedDate | TIMESTAMP | Yes | First resident move-in |
| FloorplanCount | SMALLINT | Yes | Number of floor plans in building |
| GrossSquareFootage | INT | Yes | Total gross sqft |
| Latitude | DECIMAL(10,7) | Yes | Building latitude |
| Longitude | DECIMAL(10,7) | Yes | Building longitude |
| RentableSquareFootage | INT | Yes | Total rentable sqft |
| MSAFIPS | STRING | Yes | MSA FIPS code |
| AccessibleFlag | BOOLEAN | Yes | ADA accessible |
| DisplayFlag | TINYINT | Yes | Show in online listings |
| Description | STRING | Yes | Building description |
| osl_PropertyID | INT | No | OneSite property ID |
| osl_BuildingID | INT | No | OneSite building ID |
| RowStartDate | TIMESTAMP | No | SCD2 effective start |
| RowEndDate | TIMESTAMP | No | SCD2 effective end |
| RowIsCurrent | STRING | No | Current version flag |
| IsDeleted | STRING | No | Soft delete flag |
| IsLastRow | STRING | No | Last row flag |
| osl_CDSPMCID | INT | Yes | CDS PMC ID |
| RecordCreatedDate | TIMESTAMP | Yes | Record creation |
| RecordModifiedDate | TIMESTAMP | Yes | Last modification |

---

### `dim.dim_floor_plan`

| | |
|---|---|
| **Source** | RealPage BIX — DimFloorPlan (schema-matched) |
| **Grain** | One row per floor plan per property (SCD Type 2) |
| **Description** | Defines unit types available at each property. Each floor plan specifies bedroom/bathroom count, square footage, and rent ranges. Marketing names like "The Magnolia" or "The Live Oak" are assigned per plan. |
| **Key Relationships** | `PropertyKey` → `dim_property`. Referenced by `dim_unit.FloorPlanKey`. |

*46 columns — matches RP BIX DimFloorPlan exactly. Key columns:*

| Column | Type | Description |
|--------|------|-------------|
| FloorPlanKey | INT | Surrogate key |
| PropertyKey | INT | FK to dim_property |
| FloorPlanCode | STRING | Short code (A1, B2, C3) |
| FloorPlanName | STRING | Marketing name |
| NumberofBedrooms | DECIMAL(5,0) | Bedroom count (0 = studio) |
| NumberofBathrooms | DECIMAL(5,0) | Bathroom count |
| GrossSquareFeet | INT | Gross square footage |
| RentSquareFeet | INT | Rentable square footage |
| HighPriceRangeAmount | DECIMAL(19,4) | Top of rent range |
| LowPriceRangeAmount | DECIMAL(19,4) | Bottom of rent range |
| OriginalBaseRent | DECIMAL(19,4) | Original base rent |

*Full column listing available in the Databricks catalog or notebook `01_dim_table_schemas`.*

---

### `dim.dim_unit`

| | |
|---|---|
| **Source** | RealPage BIX — DimUnit (schema-matched) |
| **Grain** | One row per unit (SCD Type 2) |
| **Description** | Individual apartment units. Contains physical characteristics, availability status, compliance flags, and address details per unit. |
| **Key Relationships** | `PropertyKey` → `dim_property`, `FloorPlanKey` → `dim_floor_plan`, `BuildingKey` → `dim_building`. Referenced by lease and transaction tables. |

*65 columns — matches RP BIX DimUnit exactly. Key columns:*

| Column | Type | Description |
|--------|------|-------------|
| UnitKey | INT | Surrogate key |
| PropertyKey | INT | FK to dim_property |
| FloorPlanKey | INT | FK to dim_floor_plan |
| UnitNumber | STRING | Unit number (101, 202, A-305) |
| BuildingNumber | STRING | Building containing this unit |
| FloorNumber | SMALLINT | Floor level |
| GrossSquareFeet | INT | Gross sqft |
| RentableSquareFeet | INT | Rentable sqft |
| AvailableForOccupancyFlag | STRING | Available for occupancy |
| MadeReadyDate | DATE | Date unit was made ready |
| BuildingKey | INT | FK to dim_building |

*Full column listing available in the Databricks catalog or notebook `01_dim_table_schemas`.*

---

### `dim.dim_resident`

| | |
|---|---|
| **Source** | RealPage BIX — DimResident (schema-matched) |
| **Grain** | One row per household (SCD Type 2) |
| **Description** | Household-level resident record. Contains payment behavior flags, collection status, and eviction holds. PII fields are STRING in synthetic data (varbinary/encrypted in real RP). |
| **Key Relationships** | `PropertyKey` → `dim_property`. Referenced by `dim_renewal.ResidentKey`. Parent of `dim_resident_member`. |

*31 columns — matches RP BIX DimResident. PII fields adapted from varbinary to STRING for synthetic data. Key columns:*

| Column | Type | Description |
|--------|------|-------------|
| ResidentKey | INT | Surrogate key |
| ResidentUniqueIdentifier | STRING | Unique resident ID |
| ResidentFullName | STRING | Full name (varbinary in real RP) |
| PropertyKey | INT | FK to dim_property |
| Status | STRING | Current, Former, Future, Applicant |
| NoOfLatePayments | SMALLINT | Late payment count |
| IsInCollection | STRING | In collections flag |

---

### `dim.dim_resident_member`

| | |
|---|---|
| **Source** | RealPage BIX — DimResidentMember (schema-matched) |
| **Grain** | One row per individual person per lease (SCD Type 2) |
| **Description** | Individual people within a household — roommates, co-signers, guarantors. Contains demographics, lease role flags, and military status. PII fields adapted from varbinary to STRING. |
| **Key Relationships** | `PropertyKey` → `dim_property`, `ResidentHouseHoldID` links to `dim_resident`. |

*63 columns — matches RP BIX DimResidentMember. Key columns:*

| Column | Type | Description |
|--------|------|-------------|
| ResidentMemberKey | INT | Surrogate key |
| ResidentHouseHoldID | STRING | Household link |
| PropertyKey | INT | FK to dim_property |
| FirstName | STRING | First name |
| LastName | STRING | Last name |
| Gender | STRING | M/F/U |
| LeaseSignerBit | BOOLEAN | Is lease signer |
| IsCurrentResident | BOOLEAN | Currently active |

---

### `dim.dim_lease_attributes`

| | |
|---|---|
| **Source** | RealPage BIX — DimLeaseAttributes (schema-matched) |
| **Grain** | One row per lease (SCD Type 2) |
| **Description** | Core lease record. Contains lease terms, all key dates (application through move-out), status flags, renewal/transfer/eviction indicators, and move-out/cancel reasons. One of the most important tables for operational analytics. |
| **Key Relationships** | `PropertyKey` → `dim_property`, `osl_LeaseID` links to transaction and resident tables. |

*66 columns — matches RP BIX DimLeaseAttributes. Key columns:*

| Column | Type | Description |
|--------|------|-------------|
| LeaseAttributesKey | INT | Surrogate key |
| LeaseUniqueIdentifier | STRING | Unique lease ID |
| LeaseTermInMonths | SMALLINT | Lease duration |
| LeaseType | STRING | New, Renewal, Transfer |
| LeaseStatus | STRING | Current status |
| LeaseBeginDate | DATE | Lease start |
| LeaseEndDate | DATE | Lease expiration |
| ActualMoveInDate | DATE | Move-in date |
| ActualMoveOutDate | DATE | Move-out date |
| IsRenewal | STRING | Renewal flag |
| MoveOutReason | STRING | Why they left |
| PropertyKey | INT | FK to dim_property |

---

### `dim.dim_employee`

| | |
|---|---|
| **Source** | RealPage BIX — DimEmployee (schema-matched) |
| **Grain** | One row per PMS system user (SCD Type 2) |
| **Description** | PMS system-level employee data. Thin table with login info and system identifiers. For the enriched staff roster with roles and org chart, see `dim_employee_roster`. |
| **Key Relationships** | Referenced by `dim_employee_roster.EmployeeKey`. |

*19 columns — matches RP BIX DimEmployee exactly.*

---

### `dim.dim_employee_roster`

| | |
|---|---|
| **Source** | Internal — Petra Capital HR/org master data |
| **Grain** | One row per employee-to-assignment (an employee can have one role at one scope) |
| **Description** | Enriched staff roster linking employees to properties with roles. Separate from RP DimEmployee — different source, different purpose. One is PMS system users, this is company org chart. Powers the communication layer and reporting hierarchy. |
| **Key Relationships** | `EmployeeKey` → `dim_employee`, `PropertyKey` → `dim_property`, `MarketKey` → `dim_market`, `ReportsToRosterKey` → self (org hierarchy). |

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| RosterKey | INT | No | Surrogate key |
| EmployeeKey | INT | Yes | FK to dim_employee (if PMS user exists) |
| EmployeeFirstName | STRING | No | First name |
| EmployeeLastName | STRING | No | Last name |
| EmployeeFullName | STRING | No | Display name |
| EmployeeEmail | STRING | Yes | Work email |
| EmployeePhone | STRING | Yes | Work phone |
| Role | STRING | No | Regional Manager, Area Manager, Property Manager, APM, Leasing Agent, Service Manager, Accounting Manager |
| PropertyKey | INT | Yes | FK to dim_property (NULL for area/regional roles) |
| MarketKey | INT | Yes | FK to dim_market (for area-level roles) |
| Region | STRING | Yes | East/West (for regional-level roles) |
| ReportsToRosterKey | INT | Yes | FK to self — org chart hierarchy |
| HireDate | DATE | Yes | Date hired |
| IsActive | STRING | No | Y/N active employee flag |
| RecordCreatedDate | TIMESTAMP | No | Row creation timestamp |
| RecordModifiedDate | TIMESTAMP | Yes | Last modification |

---

### `dim.dim_transaction_code`

| | |
|---|---|
| **Source** | Based on RealPage BIX — DimTransactionCode |
| **Grain** | One row per transaction code per property |
| **Description** | Charge and credit type definitions for the unit ledger. Maps codes like RENT, PARK, LATE, UTIL to descriptions, categories, and GL accounts. |
| **Key Relationships** | `PropertyKey` → `dim_property`. Referenced by transaction/charge fact tables. |

*19 columns. Key columns:*

| Column | Type | Description |
|--------|------|-------------|
| TransactionCodeKey | INT | Surrogate key |
| PropertyKey | INT | FK to dim_property |
| TransactionCode | STRING | Short code (RENT, PARK, LATE) |
| TransactionCodeDescription | STRING | Full description |
| TransactionCodeType | STRING | Charge, Credit, Deposit |
| GLAccountNumber | STRING | General Ledger mapping |

---

### `dim.dim_move_out_reason`

| | |
|---|---|
| **Source** | Based on RealPage BIX — DimMoveOutReason |
| **Grain** | One row per move-out reason per property |
| **Description** | Why residents leave. Critical for retention analytics. Reasons are grouped into categories (Price, Relocation, Service, Life Event, etc.) for rollup reporting. |
| **Key Relationships** | `PropertyKey` → `dim_property`. Referenced by `dim_lease_attributes.MoveOutReason`. |

*15 columns.*

---

### `dim.dim_concession`

| | |
|---|---|
| **Source** | Based on RealPage BIX — DimConcession |
| **Grain** | One row per concession per property |
| **Description** | Lease concessions and incentives (free month, reduced rent, waived fees). Tracks amount, type, and effective dates. |
| **Key Relationships** | `PropertyKey` → `dim_property`. |

*20 columns.*

---

### `dim.dim_renewal`

| | |
|---|---|
| **Source** | Based on RealPage BIX — DimRenewal |
| **Grain** | One row per renewal offer |
| **Description** | Renewal offers extended to existing residents. Tracks offer status (Pending, Accepted, Declined, Expired) and response timing. |
| **Key Relationships** | `PropertyKey` → `dim_property`, `UnitKey` → `dim_unit`, `ResidentKey` → `dim_resident`, `LeaseAttributesKey` → `dim_lease_attributes`. |

*19 columns.*

---

## Schema: `bronze`

*Tables to be documented as they are created during ETL pipeline development.*

## Schema: `silver`

*Tables to be documented as they are created during transformation development.*

## Schema: `gold`

*Tables to be documented as they are created during aggregation development.*

## Schema: `analytics`

*Tables to be documented as they are created.*

## Schema: `ml`

*Tables to be documented as they are created.*

---

*This is a living document. Updated as tables are created, modified, or deprecated.*
