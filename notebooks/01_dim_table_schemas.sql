-- Databricks notebook source

-- COMMAND ----------

%sql
-- =============================================
-- PETRA CAPITAL PARTNERS - DIMENSION TABLE SCHEMAS
-- Notebook: 01_dim_table_schemas
-- 
-- Kimball-style dimensional model. Dims live in their own schema
-- rather than gold because they're shared infrastructure that
-- every layer of the medallion architecture references.
--
-- Tables matching the RealPage BIX schema are noted.
-- DimProperty is enriched beyond RP with internal company data
-- (investment, regional hierarchy, asset classification, etc.)
--
-- 2026-03-28 | Keaton Patrick
-- =============================================


-- COMMAND ----------

%sql
CREATE SCHEMA IF NOT EXISTS keaton_multifamily_platform.dim
COMMENT 'Kimball-style dimension tables - master reference data shared across all medallion layers';


-- COMMAND ----------

%sql
-- dim_market
-- NOT from RealPage — Petra Capital geographic hierarchy
-- Region (East/West) > State > Area (metro) > City (property-level)

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_market (
    MarketKey                       INT             NOT NULL,
    Region                          STRING          NOT NULL    COMMENT 'East or West',
    StateName                       STRING          NOT NULL,
    StateCode                       STRING          NOT NULL,
    Area                            STRING          NOT NULL    COMMENT 'Metro grouping — e.g. San Antonio Area includes Boerne, New Braunfels',
    MSAName                         STRING,
    MSAFIPS                         STRING,
    IsActive                        STRING          NOT NULL    DEFAULT 'Y',
    RecordCreatedDate               TIMESTAMP       NOT NULL    DEFAULT current_timestamp(),
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Geographic hierarchy for Petra Capital portfolio';


-- COMMAND ----------

%sql
-- dim_organization
-- Matches RealPage BIX DimOrganization
-- Top-level org = Petra Capital Partners

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_organization (
    OrganizationKey                 INT             NOT NULL,
    OrganizationName                STRING,
    OrganizationType                STRING          COMMENT 'PMC, Owner, Investor, etc.',
    CompanyID                       STRING,
    RowStartDate                    TIMESTAMP       NOT NULL,
    RowEndDate                      TIMESTAMP       NOT NULL,
    RowIsCurrent                    STRING          NOT NULL,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Organization hierarchy — matches RealPage BIX DimOrganization';


-- COMMAND ----------

%sql
-- dim_property (ENRICHED)
-- Base: all 35 columns from RealPage BIX DimProperty
-- Enriched with: regional hierarchy, investment/ownership,
-- asset classification, physical characteristics, contacts
--
-- This is the SPINE. Everything joins back to PropertyKey.

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_property (
    
    -- ---- RealPage BIX DimProperty fields (all 35) ----
    
    PropertyKey                     INT             NOT NULL    COMMENT 'Primary join key across the entire platform',
    OrganizationKey                 INT             NOT NULL    COMMENT 'FK to dim_organization',
    PropertyName                    STRING,
    PropertyNumber                  STRING,
    PropertyAddress1                STRING,
    PropertyAddress2                STRING,
    PropertyAddress3                STRING,
    PropertyCity                    STRING,
    PropertyStateProvinceCode       STRING,
    PropertyPostalCode              STRING,
    PropertyCountryCode             STRING,
    ClaimedUnitCount                SMALLINT,
    PropertyStatus                  STRING          COMMENT 'Active, Inactive, etc.',
    osl_PropertyID                  INT             NOT NULL,
    osl_PMCID                       INT,
    IsDeleted                       STRING          NOT NULL,
    RowStartDate                    TIMESTAMP,
    RowEndDate                      TIMESTAMP,
    RowIsCurrent                    STRING,
    IsLastRow                       STRING,
    CDSExtractDate                  TIMESTAMP,
    ModifyDate                      TIMESTAMP,
    PropertySourceCode              INT,
    AccountingPropertyID            STRING,
    ExternalPropertyIdentifier      STRING,
    Phone                           STRING,
    Phone2                          STRING,
    FaxPhone                        STRING          COMMENT 'Yes, multifamily still faxes things',
    EmailAddress                    STRING,
    WebAddress                      STRING,
    PropertyType                    STRING          COMMENT 'Conventional, Affordable, etc.',
    PropertySubType                 STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP,
    YSM_Postdate                    TIMESTAMP       COMMENT 'Yield Star Management post date',
    
    -- ---- ENRICHMENT: Regional Hierarchy ----
    
    MarketKey                       INT             COMMENT 'FK to dim_market',
    Region                          STRING          COMMENT 'East or West',
    Area                            STRING          COMMENT 'Metro area — San Antonio, Miami, Atlanta, etc.',
    
    -- ---- ENRICHMENT: Investment / Ownership ----
    -- Some properties owned by Petra, some third-party managed
    
    OwnershipType                   STRING          COMMENT 'Owned or Third-Party Managed',
    OwnerName                       STRING          COMMENT 'Petra fund entity or third-party owner name',
    OwnerContactName                STRING,
    OwnerContactEmail               STRING,
    AcquisitionDate                 DATE            COMMENT 'Date acquired or took over management',
    AcquisitionPrice                DECIMAL(14,2)   COMMENT 'Purchase price — NULL for third-party managed',
    CurrentValuation                DECIMAL(14,2),
    FundName                        STRING          COMMENT 'Petra Fund III, Petra Fund IV, etc.',
    OwnershipEntity                 STRING          COMMENT 'The LLC that holds title',
    OwnershipPercentage             DECIMAL(5,2)    COMMENT '100 if wholly owned',
    
    -- ---- ENRICHMENT: Asset Classification ----
    
    PropertyClass                   STRING          COMMENT 'A, B+, B, B-, C',
    AssetStrategy                   STRING          COMMENT 'Core, Core-Plus, Value-Add, Opportunistic',
    AssetType                       STRING          COMMENT 'Garden, Mid-Rise, High-Rise, BTR, Mixed',
    StabilizationStatus             STRING          COMMENT 'Lease-Up or Stabilized',
    VintageYear                     INT             COMMENT 'Year originally built',
    YearRenovated                   INT,
    RenovationBudget                DECIMAL(12,2),
    
    -- ---- ENRICHMENT: Physical Characteristics ----
    
    TotalSquareFootage              INT,
    RentableSquareFootage           INT,
    CommonAreaSquareFootage         INT             COMMENT 'Clubhouse, gym, hallways, etc.',
    RetailCommercialSquareFootage   INT             COMMENT 'Retail/commercial if mixed-use',
    TotalAcreage                    DECIMAL(6,2),
    ParkingSpaces                   INT,
    ParkingType                     STRING          COMMENT 'Surface, Garage, Mixed, None',
    AmenityTier                     STRING          COMMENT 'Standard, Premium, Luxury',
    PetPolicy                       STRING          COMMENT 'Breed Restricted, Weight Restricted, Unrestricted, No Pets',
    Latitude                        DECIMAL(10,7),
    Longitude                       DECIMAL(10,7),
    
    -- ---- ENRICHMENT: Management Contacts ----
    -- Detailed staff in dim_employee_roster
    
    ManagementEmail                 STRING          COMMENT 'Property management office email',
    AccountingManagerName           STRING,
    AccountingManagerEmail          STRING
)
COMMENT 'Master property dimension — RP BIX base + Petra enrichment. The spine of the data model.';


-- COMMAND ----------

%sql
-- dim_building
-- Matches RealPage BIX DimBuilding exactly
-- One property → many buildings

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_building (
    BuildingKey                     INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    BuildingName                    STRING,
    BuildingNumber                  STRING,
    NumberOfFloors                  TINYINT,
    Address1                        STRING,
    Address2                        STRING,
    Address3                        STRING,
    City                            STRING,
    State                           STRING,
    Zip                             STRING,
    County                          STRING,
    Province                        STRING,
    BlockNumber                     STRING,
    BuildingType                    STRING,
    ConstructionStartDate           TIMESTAMP,
    ConstructionEndDate             TIMESTAMP,
    FirstOccupiedDate               TIMESTAMP,
    FloorplanCount                  SMALLINT,
    GrossSquareFootage              INT,
    Latitude                        DECIMAL(10,7),
    Longitude                       DECIMAL(10,7),
    RentableSquareFootage           INT,
    MSAFIPS                         STRING,
    AccessibleFlag                  BOOLEAN,
    DisplayFlag                     TINYINT,
    Description                     STRING,
    osl_PropertyID                  INT             NOT NULL,
    osl_BuildingID                  INT             NOT NULL,
    RowStartDate                    TIMESTAMP       NOT NULL,
    RowEndDate                      TIMESTAMP       NOT NULL,
    RowIsCurrent                    STRING          NOT NULL,
    IsDeleted                       STRING          NOT NULL,
    IsLastRow                       STRING          NOT NULL,
    osl_CDSPMCID                    INT,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Building dimension — matches RealPage BIX DimBuilding';


-- COMMAND ----------

%sql
-- dim_floor_plan
-- Matches RealPage BIX DimFloorPlan exactly
-- Defines unit types per property
-- e.g. "The Magnolia" = 2BR/2BA, 1050 sqft

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_floor_plan (
    FloorPlanKey                    INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    FloorPlanCode                   STRING          COMMENT 'Short code — A1, B2, C3',
    FloorPlanName                   STRING          COMMENT 'Marketing name — The Magnolia, The Live Oak',
    FloorPlanBrochureName           STRING,
    NumberofBedrooms                DECIMAL(5,0)    COMMENT '0 = studio',
    NumberofBathrooms               DECIMAL(5,0),
    GrossSquareFeet                 INT,
    RentSquareFeet                  INT,
    MaximumOccupants                SMALLINT,
    FloorPlanGroupName              STRING,
    FloorPlanGroupDescription       STRING,
    FloorPlanGroupNumberofBedrooms  DECIMAL(5,0),
    FloorPlanGroupNumberofBathrooms DECIMAL(5,0),
    FloorPlanOnlineDisplayBit       BOOLEAN,
    CommissionAmount                DECIMAL(19,4),
    HighPriceRangeAmount            DECIMAL(19,4),
    LowPriceRangeAmount             DECIMAL(19,4),
    ReserveFeeAmount                DECIMAL(19,4),
    SubsidyRentAmount               DECIMAL(19,4),
    MaximumSqFt                     SMALLINT,
    MinimumSqFt                     SMALLINT,
    RentType                        STRING,
    AvailableFlag                   BOOLEAN,
    DisplayFlag                     BOOLEAN,
    BrochureFlag                    TINYINT,
    ReportUnitOccupancyFlag         BOOLEAN,
    Status                          STRING,
    CommissionPercentage            DECIMAL(5,0),
    SubsidizedPercentage            DECIMAL(5,0),
    osl_FloorPlanGroupID            STRING,
    osl_PropertyID                  INT             NOT NULL,
    osl_FloorPlanID                 INT             NOT NULL,
    RowStartDate                    TIMESTAMP       NOT NULL,
    RowEndDate                      TIMESTAMP       NOT NULL,
    RowIsCurrent                    STRING          NOT NULL,
    IsDeleted                       STRING          NOT NULL,
    IsLastRow                       STRING          NOT NULL,
    osl_PMCID                       INT,
    ToProcess                       STRING,
    OriginalBaseRent                DECIMAL(19,4),
    StartDate                       TIMESTAMP,
    EndDate                         TIMESTAMP,
    Refunddepositamount             DECIMAL(19,4),
    FloorPlanDescription            STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Floor plan dimension — matches RealPage BIX DimFloorPlan';


-- COMMAND ----------

%sql
-- dim_unit
-- Matches RealPage BIX DimUnit exactly
-- Individual apartment units

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_unit (
    UnitKey                         INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    FloorPlanKey                    INT             NOT NULL,
    UnitNumber                      STRING,
    BuildingNumber                  STRING,
    FloorNumber                     SMALLINT,
    GrossSquareFeet                 INT,
    RentableSquareFeet              INT,
    DepositAmount                   DECIMAL(10,4),
    NonRefundableFee                DECIMAL(10,4),
    ComplianceExemptCode            DECIMAL(1,0),
    Hearing                         STRING,
    Mobility                        STRING,
    Vision                          STRING,
    AvailableForOccupancyFlag       STRING,
    UnitDesignation                 STRING,
    UnitDesignationGroup            STRING,
    MadeReadyDate                   DATE,
    MadeReadyBit                    TINYINT,
    UnavailableCode                 STRING,
    BuilderWarrantyExpirationDate   DATE,
    MilitarySubdivision             INT,
    SubPropertyName                 STRING,
    SubPropertyNumber               STRING,
    osl_SubPropertyID               INT,
    osl_FloorPlanID                 INT,
    osl_PropertyID                  INT             NOT NULL,
    osl_UnitID                      INT             NOT NULL,
    osl_PMCID                       INT,
    BuildingKey                     INT,
    BuildingName                    STRING,
    RowStartDate                    TIMESTAMP       NOT NULL,
    RowEndDate                      TIMESTAMP       NOT NULL,
    RowIsCurrent                    STRING          NOT NULL,
    IsDeleted                       STRING          NOT NULL,
    IsLastRow                       STRING          NOT NULL,
    ApartmentID                     DECIMAL(10,0),
    unitDisplayBit                  TINYINT,
    CensusPercentage                DECIMAL(18,0),
    UnitStartDate                   DATE,
    UnitEndDate                     DATE,
    UnitOnlineDisplayBit            TINYINT,
    UnitEndDateBit                  TINYINT,
    unitUniqueIdentity              INT,
    fpDisplayBit                    TINYINT,
    ToProcess                       STRING,
    osl_UnitDesignationID           INT,
    osl_UnitDesignationGroupID      INT,
    Address1                        STRING,
    Address2                        STRING,
    City                            STRING,
    State                           STRING,
    Zip                             STRING,
    County                          STRING,
    HUDExemptFlag                   BOOLEAN,
    HoldFlag                        BOOLEAN,
    NonRevenueFlag                  STRING,
    NoteDescription                 STRING,
    ExpectedTurnDate                TIMESTAMP,
    HoldUntilDate                   TIMESTAMP,
    RHSExemptFlag                   STRING          NOT NULL,
    TCExemptFlag                    STRING          NOT NULL,
    UnitDescription                 STRING,
    SourceKey                       SMALLINT,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Unit dimension — matches RealPage BIX DimUnit';


-- COMMAND ----------

%sql
-- dim_resident
-- Matches RealPage BIX DimResident — household level
-- PII fields are STRING here instead of varbinary
-- since this is synthetic data (no real PII to encrypt)

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_resident (
    ResidentKey                     INT             NOT NULL,
    ResidentUniqueIdentifier        STRING          NOT NULL,
    ResidentFullName                STRING          COMMENT 'varbinary in real RP',
    ResidentMailingName             STRING          COMMENT 'varbinary in real RP',
    IsConventional                  STRING,
    IsFinalPaymentSettled           STRING,
    IsInCollection                  STRING,
    IsMiscellaneousAccount          STRING,
    DoNotAcceptCheck                STRING,
    DoNotAcceptMoneyOrder           STRING,
    NoOfLatePayments                SMALLINT,
    NoOfNSFChecks                   SMALLINT,
    RowStartDate                    TIMESTAMP       NOT NULL,
    RowEndDate                      TIMESTAMP       NOT NULL,
    RowIsCurrent                    STRING          NOT NULL,
    IsDeleted                       STRING          NOT NULL,
    IsLastRow                       STRING          NOT NULL,
    osl_CDSPMCID                    INT,
    osl_PropertyID                  INT,
    osl_reshID                      STRING,
    PropertyKey                     INT,
    LastLatePeriodID                SMALLINT,
    osl_SiteGuestCard               INT,
    StatusCode                      STRING,
    Status                          STRING          COMMENT 'Current, Former, Future, Applicant, etc.',
    AllowPaymentForFormerResidentFlag STRING,
    SourceKey                       SMALLINT,
    reshEvictionHold                BOOLEAN,
    reshEvictionHoldReason          STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Resident dimension — matches RealPage BIX DimResident. Household-level.';


-- COMMAND ----------

%sql
-- dim_resident_member
-- Matches RealPage BIX DimResidentMember
-- Individual people within a household
-- Same PII note as dim_resident — STRING instead of varbinary

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_resident_member (
    ResidentMemberKey               INT             NOT NULL,
    ResidentMemberID                INT             NOT NULL,
    ResidentHouseHoldID             STRING          NOT NULL,
    ResidentLeaseID                 INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    FirstName                       STRING,
    MiddleInitial                   STRING,
    LastName                        STRING,
    Gender                          STRING,
    DBMonth                         STRING          COMMENT 'Encrypted in real RP',
    DBYear                          STRING          COMMENT 'Encrypted in real RP',
    DBDay                           STRING          COMMENT 'Encrypted in real RP',
    MaritalStatus                   STRING,
    PrefCommunicationType           STRING,
    RelationShipCode                STRING,
    LeaseSignerBit                  BOOLEAN,
    LeaseOccupantBit                BOOLEAN,
    LeaseActiveBit                  BOOLEAN,
    LeaseCoSignerBit                BOOLEAN,
    LeaseEmployerBit                BOOLEAN,
    LeaseGuarantorBit               BOOLEAN,
    MailingAddressSameasBit         BOOLEAN,
    BillingAddressSameasBit         BOOLEAN,
    MilitaryActiveDutyMemberBit     BOOLEAN,
    MilitaryBranch                  STRING,
    MilitaryUnit                    DECIMAL(10,0),
    MilitaryDutyPostalCode          STRING,
    MilitaryRank                    STRING,
    MilitaryRankDate                TIMESTAMP,
    familySize                      INT,
    GuestCardID                     INT,
    HouseHoldStatus                 STRING,
    CDSExtractType                  STRING          NOT NULL,
    osl_PropertyID                  INT             NOT NULL,
    osl_PMCID                       INT             NOT NULL,
    IsCurrentResident               BOOLEAN,
    resmDisplayBit                  BOOLEAN         NOT NULL,
    CDSExtractDate                  TIMESTAMP,
    ModifyDate                      TIMESTAMP,
    ResidentPlaceofBirth            STRING,
    ResidentCitizenship             STRING,
    ResidentEthnicity               STRING,
    ResidentRace                    STRING,
    ResidentVeteranBranchCode       STRING,
    IsPreleased                     STRING,
    PreleasedDate                   TIMESTAMP,
    osl_FacultyID                   STRING,
    Coursename                      STRING,
    ucas                            STRING,
    Suffix                          STRING,
    EvictedFlag                     BOOLEAN,
    FelonyFlag                      BOOLEAN,
    JointAppFlag                    BOOLEAN,
    DoNotReRentFlag                 BOOLEAN,
    Description                     STRING,
    ModifiedByID                    INT,
    ChangeDate                      TIMESTAMP,
    osl_wlapptID                    INT,
    osl_pmccustID                   INT,
    SourceSystemKey                 INT,
    SourceKey                       SMALLINT,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Resident member dimension — matches RealPage BIX DimResidentMember';


-- COMMAND ----------

%sql
-- dim_lease_attributes
-- Matches RealPage BIX DimLeaseAttributes
-- One of the most important tables for operational analytics
-- All the lease dates, statuses, and reasons live here

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_lease_attributes (
    LeaseAttributesKey              INT             NOT NULL,
    LeaseUniqueIdentifier           STRING          NOT NULL,
    LeaseTermDescription            STRING,
    LeaseTermInMonths               SMALLINT,
    LeaseType                       STRING          COMMENT 'New, Renewal, Transfer, etc.',
    LeaseTypeID                     STRING,
    LeaseStatus                     STRING,
    LeasingAgentName                STRING          COMMENT 'varbinary in real RP',
    ReasonForLeasing                STRING,
    osl_ReasonForLeasingID          STRING,
    MoveOutReason                   STRING,
    MoveOutReasonGroup              STRING,
    CancelReason                    STRING,
    CancelReasonGroup               STRING,
    LateMethod                      STRING,
    
    -- Status flags
    IsRenewal                       STRING,
    IsTransfer                      STRING,
    IsCancelled                     STRING,
    IsBulkMoveIn                    STRING,
    IsBulkMoveOut                   STRING,
    IsDenyRenewal                   STRING,
    IsEvictionProceedingsStarted    STRING,
    IsNonResidentAccount            STRING,
    IsAccountClosed                 STRING,
    
    -- Key lease dates
    LeaseApplicationDate            DATE,
    LeaseApprovedDate               DATE,
    LeaseRejectedDate               DATE,
    LeaseBeginDate                  DATE,
    LeaseEndDate                    DATE,
    LeaseSignedDate                 DATE,
    LeaseActiveDate                 DATE,
    ScheduledMoveInDate             DATE,
    ActualMoveInDate                DATE,
    NoticeOnDate                    DATE            COMMENT 'When notice to vacate was given',
    NoticeForDate                   DATE            COMMENT 'Date notice is effective for',
    ScheduledMoveOutDate            DATE,
    ActualMoveOutDate               DATE,
    LeaseInactiveDate               DATE,
    CreditApprovedDate              DATE,
    MonthToMonthDate                TIMESTAMP,
    UtilityBillingStartDate         TIMESTAMP,
    
    -- RP internal / SCD
    ModifyDate                      TIMESTAMP,
    osl_LeaseID                     INT             NOT NULL,
    osl_PMCID                       INT,
    osl_PropertyID                  INT,
    IsDeleted                       STRING          NOT NULL,
    CDSExtractDate                  TIMESTAMP,
    IsLastRow                       STRING,
    RowIsCurrent                    STRING,
    RowStartDate                    TIMESTAMP,
    RowEndDate                      TIMESTAMP,
    PropertyKey                     INT,
    IsOnlineApplication             STRING,
    IsOnlineRenewal                 STRING,
    osl_LeaseStatusCode             SMALLINT,
    ToProcess                       STRING,
    osl_ltermID                     INT,
    ModifiedByID                    INT,
    osl_MoveOutID                   STRING,
    osl_CancelID                    STRING,
    MonthToMonthRequestedFlag       STRING,
    SourceResidentStatus            STRING,
    ExternalLeaseID                 STRING,
    EvictionReasonTypeCodeID        STRING,
    EvictionReason                  STRING,
    SourceKey                       SMALLINT,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Lease attributes dimension — matches RealPage BIX DimLeaseAttributes';


-- COMMAND ----------

%sql
-- dim_employee
-- Matches RealPage BIX DimEmployee exactly
-- Thin RP version — system/login data only
-- Enriched staff roster is dim_employee_roster

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_employee (
    EmployeeKey                     INT             NOT NULL,
    EmployeeName                    STRING          COMMENT 'varbinary in real RP',
    EmployeeLogin                   STRING,
    EmployeeCreateDate              DATE,
    osl_EmployeeNumber              STRING          COMMENT 'varbinary in real RP',
    USER_ThirdPartyReferenceNumber  STRING,
    RowStartDate                    TIMESTAMP       NOT NULL,
    RowEndDate                      TIMESTAMP       NOT NULL,
    RowIsCurrent                    STRING          NOT NULL,
    IsDeleted                       STRING          NOT NULL,
    IsLastRow                       STRING          NOT NULL,
    CMPNY_ID                        INT,
    CURRENT_PRPTY_ID                INT,
    osl_CDSPropertyID               INT,
    osl_CDSPMCID                    INT,
    UserDisableBit                  INT,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP,
    SourceKey                       SMALLINT
)
COMMENT 'Employee dimension — matches RealPage BIX DimEmployee';


-- COMMAND ----------

%sql
-- dim_employee_roster (ENRICHED — NOT from RP)
-- Petra Capital internal staff roster
-- Links employees to properties with roles
-- Separate from RP DimEmployee — different source, different purpose
-- One is PMS system users, this is HR/org master data
--
-- Role hierarchy:
--   Regional Manager > Area Manager > Property Manager >
--   APM / Leasing Agent / Service Manager
-- Accounting Managers are cross-property (6-8 properties each)

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_employee_roster (
    RosterKey                       INT             NOT NULL,
    EmployeeKey                     INT             COMMENT 'FK to dim_employee if applicable',
    EmployeeFirstName               STRING          NOT NULL,
    EmployeeLastName                STRING          NOT NULL,
    EmployeeFullName                STRING          NOT NULL,
    EmployeeEmail                   STRING,
    EmployeePhone                   STRING,
    Role                            STRING          NOT NULL    COMMENT 'Regional Manager, Area Manager, Property Manager, APM, Leasing Agent, Service Manager, Accounting Manager',
    PropertyKey                     INT             COMMENT 'FK to dim_property — NULL for area/regional roles',
    MarketKey                       INT             COMMENT 'FK to dim_market — for area-level roles',
    Region                          STRING          COMMENT 'East/West — for regional-level roles',
    ReportsToRosterKey              INT             COMMENT 'FK to this table — manager relationship',
    HireDate                        DATE,
    IsActive                        STRING          NOT NULL    DEFAULT 'Y',
    RecordCreatedDate               TIMESTAMP       NOT NULL    DEFAULT current_timestamp(),
    RecordModifiedDate              TIMESTAMP
)
COMMENT 'Enriched employee roster — Petra Capital master data. Staff-to-property assignments and org chart.';


-- COMMAND ----------

%sql
-- dim_transaction_code
-- Based on RealPage BIX DimTransactionCode
-- Charge/credit type definitions
-- e.g. RENT = base rent, PARK = parking, LATE = late fee

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_transaction_code (
    TransactionCodeKey              INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    TransactionCode                 STRING,
    TransactionCodeDescription      STRING,
    TransactionCodeCategory         STRING,
    TransactionCodeType             STRING          COMMENT 'Charge, Credit, Deposit, etc.',
    SubJournalKey                   INT,
    SubJournalName                  STRING,
    GLAccountNumber                 STRING          COMMENT 'Maps to General Ledger',
    osl_TransactionCodeID           INT,
    osl_PropertyID                  INT,
    osl_PMCID                       INT,
    RowStartDate                    TIMESTAMP,
    RowEndDate                      TIMESTAMP,
    RowIsCurrent                    STRING,
    IsDeleted                       STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP,
    SourceKey                       SMALLINT
)
COMMENT 'Transaction code dimension — charge/credit types for the unit ledger';


-- COMMAND ----------

%sql
-- dim_move_out_reason
-- Based on RealPage BIX DimMoveOutReason
-- Why residents leave — critical for retention analytics

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_move_out_reason (
    MoveOutReasonKey                INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    MoveOutReason                   STRING,
    MoveOutReasonGroup              STRING          COMMENT 'Price, Relocation, Service, Life Event, etc.',
    MoveOutReasonCode               STRING,
    osl_MoveOutReasonID             INT,
    osl_PropertyID                  INT,
    osl_PMCID                       INT,
    RowStartDate                    TIMESTAMP,
    RowEndDate                      TIMESTAMP,
    RowIsCurrent                    STRING,
    IsDeleted                       STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP,
    SourceKey                       SMALLINT
)
COMMENT 'Move-out reason dimension — why residents leave';


-- COMMAND ----------

%sql
-- dim_concession
-- Based on RealPage BIX DimConcession

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_concession (
    ConcessionKey                   INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    ConcessionDescription           STRING,
    ConcessionCode                  STRING,
    ConcessionType                  STRING          COMMENT 'One-time, Recurring, etc.',
    ConcessionCategoryKey           INT,
    Amount                          DECIMAL(19,4),
    Percentage                      DECIMAL(5,2),
    StartDate                       DATE,
    EndDate                         DATE,
    osl_ConcessionID                INT,
    osl_PropertyID                  INT,
    osl_PMCID                       INT,
    RowStartDate                    TIMESTAMP,
    RowEndDate                      TIMESTAMP,
    RowIsCurrent                    STRING,
    IsDeleted                       STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP,
    SourceKey                       SMALLINT
)
COMMENT 'Concession dimension — lease incentives';


-- COMMAND ----------

%sql
-- dim_renewal
-- Based on RealPage BIX DimRenewal

CREATE OR REPLACE TABLE keaton_multifamily_platform.dim.dim_renewal (
    RenewalKey                      INT             NOT NULL,
    PropertyKey                     INT             NOT NULL,
    UnitKey                         INT,
    ResidentKey                     INT,
    LeaseAttributesKey              INT             COMMENT 'Current lease being renewed',
    RenewalStatus                   STRING          COMMENT 'Pending, Accepted, Declined, Expired',
    RenewalType                     STRING,
    OfferDate                       DATE,
    ResponseDate                    DATE,
    osl_RenewalID                   INT,
    osl_PropertyID                  INT,
    osl_PMCID                       INT,
    RowStartDate                    TIMESTAMP,
    RowEndDate                      TIMESTAMP,
    RowIsCurrent                    STRING,
    IsDeleted                       STRING,
    RecordCreatedDate               TIMESTAMP,
    RecordModifiedDate              TIMESTAMP,
    SourceKey                       SMALLINT
)
COMMENT 'Renewal dimension — offers extended to existing residents';


-- COMMAND ----------

%sql
-- VERIFICATION — should see 15 tables
SHOW TABLES IN keaton_multifamily_platform.dim;
