/* ============================================================================
   SAMPLE HEALTHCARE DATABASE (SQL Server)
   - EHR (encounters, dx, px, labs)
   - Claims (headers + lines)
   - Pharmacy (rx claims)
   - Lookups (ICD-10, CPT, LOINC, NDC, names)
   - Synthetic generator proc: dbo.usp_GenerateSyntheticHealthcareData
============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ----------------------------
   1) Create Schemas
---------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ref')    EXEC('CREATE SCHEMA ref');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ehr')    EXEC('CREATE SCHEMA ehr');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'claims') EXEC('CREATE SCHEMA claims');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'rx')     EXEC('CREATE SCHEMA rx');
GO

/* ----------------------------
   2) Drop Tables (optional dev reset)
   Comment out in “keep data” scenarios.
---------------------------- */
IF OBJECT_ID('rx.RxClaims', 'U') IS NOT NULL DROP TABLE rx.RxClaims;
IF OBJECT_ID('claims.ClaimLines', 'U') IS NOT NULL DROP TABLE claims.ClaimLines;
IF OBJECT_ID('claims.Claims', 'U') IS NOT NULL DROP TABLE claims.Claims;

IF OBJECT_ID('ehr.LabResults', 'U') IS NOT NULL DROP TABLE ehr.LabResults;
IF OBJECT_ID('ehr.Procedures', 'U') IS NOT NULL DROP TABLE ehr.Procedures;
IF OBJECT_ID('ehr.Diagnoses', 'U') IS NOT NULL DROP TABLE ehr.Diagnoses;
IF OBJECT_ID('ehr.Encounters', 'U') IS NOT NULL DROP TABLE ehr.Encounters;

IF OBJECT_ID('dbo.PatientCoverage', 'U') IS NOT NULL DROP TABLE dbo.PatientCoverage;
IF OBJECT_ID('dbo.Plans', 'U') IS NOT NULL DROP TABLE dbo.Plans;
IF OBJECT_ID('dbo.Payers', 'U') IS NOT NULL DROP TABLE dbo.Payers;

IF OBJECT_ID('dbo.Facilities', 'U') IS NOT NULL DROP TABLE dbo.Facilities;
IF OBJECT_ID('dbo.Providers', 'U') IS NOT NULL DROP TABLE dbo.Providers;
IF OBJECT_ID('dbo.Patients', 'U') IS NOT NULL DROP TABLE dbo.Patients;

IF OBJECT_ID('ref.NdcCodes', 'U') IS NOT NULL DROP TABLE ref.NdcCodes;
IF OBJECT_ID('ref.LoincCodes', 'U') IS NOT NULL DROP TABLE ref.LoincCodes;
IF OBJECT_ID('ref.CptCodes', 'U') IS NOT NULL DROP TABLE ref.CptCodes;
IF OBJECT_ID('ref.Icd10Codes', 'U') IS NOT NULL DROP TABLE ref.Icd10Codes;
IF OBJECT_ID('ref.DrugNames', 'U') IS NOT NULL DROP TABLE ref.DrugNames;
IF OBJECT_ID('ref.ProviderSpecialties', 'U') IS NOT NULL DROP TABLE ref.ProviderSpecialties;
IF OBJECT_ID('ref.LastNames', 'U') IS NOT NULL DROP TABLE ref.LastNames;
IF OBJECT_ID('ref.FirstNames', 'U') IS NOT NULL DROP TABLE ref.FirstNames;
GO

/* ----------------------------
   3) Reference / Lookup Tables
---------------------------- */
CREATE TABLE ref.FirstNames (
    FirstNameId  int IDENTITY(1,1) PRIMARY KEY,
    FirstName    varchar(50) NOT NULL UNIQUE
);

CREATE TABLE ref.LastNames (
    LastNameId   int IDENTITY(1,1) PRIMARY KEY,
    LastName     varchar(50) NOT NULL UNIQUE
);

CREATE TABLE ref.ProviderSpecialties (
    SpecialtyId  int IDENTITY(1,1) PRIMARY KEY,
    Specialty    varchar(100) NOT NULL UNIQUE
);

CREATE TABLE ref.Icd10Codes (
    Icd10Id      int IDENTITY(1,1) PRIMARY KEY,
    Icd10Code    varchar(10) NOT NULL UNIQUE,
    Description  varchar(200) NULL
);

CREATE TABLE ref.CptCodes (
    CptId        int IDENTITY(1,1) PRIMARY KEY,
    CptCode      varchar(10) NOT NULL UNIQUE,
    Description  varchar(200) NULL
);

CREATE TABLE ref.LoincCodes (
    LoincId      int IDENTITY(1,1) PRIMARY KEY,
    LoincCode    varchar(20) NOT NULL UNIQUE,
    Description  varchar(200) NULL,
    Units        varchar(20) NULL
);

CREATE TABLE ref.DrugNames (
    DrugId       int IDENTITY(1,1) PRIMARY KEY,
    DrugName     varchar(200) NOT NULL UNIQUE
);

CREATE TABLE ref.NdcCodes (
    NdcId        int IDENTITY(1,1) PRIMARY KEY,
    NdcCode      varchar(15) NOT NULL UNIQUE,  -- simplified format
    DrugId       int NOT NULL,
    Strength     varchar(50) NULL,
    DosageForm   varchar(50) NULL,
    CONSTRAINT FK_NdcCodes_DrugNames FOREIGN KEY (DrugId) REFERENCES ref.DrugNames(DrugId)
);
GO

/* ----------------------------
   4) Core Entities
---------------------------- */
CREATE TABLE dbo.Patients (
    PatientId        bigint IDENTITY(1,1) PRIMARY KEY,
    MemberId         varchar(30) NOT NULL UNIQUE,     -- “payer member id”
    FirstName        varchar(50) NOT NULL,
    LastName         varchar(50) NOT NULL,
    DateOfBirth      date NOT NULL,
    Sex              char(1) NOT NULL CHECK (Sex IN ('M','F')),
    ZipCode          char(5) NOT NULL,
    CreatedAt        datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Providers (
    ProviderId       bigint IDENTITY(1,1) PRIMARY KEY,
    Npi              char(10) NOT NULL UNIQUE,        -- simplified: numeric string
    FirstName        varchar(50) NOT NULL,
    LastName         varchar(50) NOT NULL,
    SpecialtyId      int NOT NULL,
    CreatedAt        datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Providers_Specialty FOREIGN KEY (SpecialtyId) REFERENCES ref.ProviderSpecialties(SpecialtyId)
);

CREATE TABLE dbo.Facilities (
    FacilityId       bigint IDENTITY(1,1) PRIMARY KEY,
    FacilityName     varchar(200) NOT NULL,
    FacilityType     varchar(50) NOT NULL,            -- Hospital/Clinic/Lab/etc
    ZipCode          char(5) NOT NULL,
    CreatedAt        datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.Payers (
    PayerId          int IDENTITY(1,1) PRIMARY KEY,
    PayerName        varchar(200) NOT NULL UNIQUE
);

CREATE TABLE dbo.Plans (
    PlanId           int IDENTITY(1,1) PRIMARY KEY,
    PayerId          int NOT NULL,
    PlanName         varchar(200) NOT NULL,
    PlanType         varchar(30) NOT NULL,            -- HMO/PPO/Medicaid/etc
    CONSTRAINT FK_Plans_Payers FOREIGN KEY (PayerId) REFERENCES dbo.Payers(PayerId)
);

CREATE TABLE dbo.PatientCoverage (
    CoverageId       bigint IDENTITY(1,1) PRIMARY KEY,
    PatientId        bigint NOT NULL,
    PlanId           int NOT NULL,
    CoverageStart    date NOT NULL,
    CoverageEnd      date NULL,
    CONSTRAINT FK_Coverage_Patient FOREIGN KEY (PatientId) REFERENCES dbo.Patients(PatientId),
    CONSTRAINT FK_Coverage_Plan    FOREIGN KEY (PlanId) REFERENCES dbo.Plans(PlanId)
);
GO

/* ----------------------------
   5) EHR Tables
---------------------------- */
CREATE TABLE ehr.Encounters (
    EncounterId      bigint IDENTITY(1,1) PRIMARY KEY,
    PatientId        bigint NOT NULL,
    ProviderId       bigint NOT NULL,
    FacilityId       bigint NOT NULL,
    EncounterDate    date NOT NULL,
    EncounterType    varchar(30) NOT NULL,            -- OP/IP/ED/Tele/etc
    Reason           varchar(200) NULL,
    CONSTRAINT FK_Enc_Patient  FOREIGN KEY (PatientId) REFERENCES dbo.Patients(PatientId),
    CONSTRAINT FK_Enc_Provider FOREIGN KEY (ProviderId) REFERENCES dbo.Providers(ProviderId),
    CONSTRAINT FK_Enc_Facility FOREIGN KEY (FacilityId) REFERENCES dbo.Facilities(FacilityId)
);

CREATE TABLE ehr.Diagnoses (
    DiagnosisId      bigint IDENTITY(1,1) PRIMARY KEY,
    EncounterId      bigint NOT NULL,
    Icd10Id          int NOT NULL,
    DxRank           tinyint NOT NULL,                -- 1=primary
    PresentOnAdmit   bit NULL,
    CONSTRAINT FK_Dx_Encounter FOREIGN KEY (EncounterId) REFERENCES ehr.Encounters(EncounterId),
    CONSTRAINT FK_Dx_Icd10     FOREIGN KEY (Icd10Id) REFERENCES ref.Icd10Codes(Icd10Id)
);

CREATE TABLE ehr.Procedures (
    ProcedureId      bigint IDENTITY(1,1) PRIMARY KEY,
    EncounterId      bigint NOT NULL,
    CptId            int NOT NULL,
    PerformedDate    date NOT NULL,
    CONSTRAINT FK_Px_Encounter FOREIGN KEY (EncounterId) REFERENCES ehr.Encounters(EncounterId),
    CONSTRAINT FK_Px_Cpt       FOREIGN KEY (CptId) REFERENCES ref.CptCodes(CptId)
);

CREATE TABLE ehr.LabResults (
    LabResultId      bigint IDENTITY(1,1) PRIMARY KEY,
    EncounterId      bigint NOT NULL,
    LoincId          int NOT NULL,
    ResultDate       date NOT NULL,
    ResultValueNum   decimal(18,4) NULL,
    ResultValueText  varchar(100) NULL,
    Units            varchar(20) NULL,
    AbnormalFlag     char(1) NULL CHECK (AbnormalFlag IN ('H','L','N')),
    CONSTRAINT FK_Lab_Encounter FOREIGN KEY (EncounterId) REFERENCES ehr.Encounters(EncounterId),
    CONSTRAINT FK_Lab_Loinc     FOREIGN KEY (LoincId) REFERENCES ref.LoincCodes(LoincId)
);
GO

/* ----------------------------
   6) Claims Tables
---------------------------- */
CREATE TABLE claims.Claims (
    ClaimId          bigint IDENTITY(1,1) PRIMARY KEY,
    ClaimNumber      varchar(30) NOT NULL UNIQUE,
    PatientId        bigint NOT NULL,
    PlanId           int NOT NULL,
    ProviderId       bigint NOT NULL,
    FacilityId       bigint NOT NULL,
    ServiceFromDate  date NOT NULL,
    ServiceThruDate  date NOT NULL,
    BillType         varchar(10) NULL,                -- simplified
    ClaimStatus      varchar(20) NOT NULL,            -- Paid/Denied/Pended
    TotalCharge      decimal(18,2) NOT NULL,
    AllowedAmount    decimal(18,2) NOT NULL,
    PaidAmount       decimal(18,2) NOT NULL,
    CreatedAt        datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Claim_Patient  FOREIGN KEY (PatientId) REFERENCES dbo.Patients(PatientId),
    CONSTRAINT FK_Claim_Plan     FOREIGN KEY (PlanId) REFERENCES dbo.Plans(PlanId),
    CONSTRAINT FK_Claim_Provider FOREIGN KEY (ProviderId) REFERENCES dbo.Providers(ProviderId),
    CONSTRAINT FK_Claim_Facility FOREIGN KEY (FacilityId) REFERENCES dbo.Facilities(FacilityId)
);

CREATE TABLE claims.ClaimLines (
    ClaimLineId      bigint IDENTITY(1,1) PRIMARY KEY,
    ClaimId          bigint NOT NULL,
    LineNumber       int NOT NULL,
    CptId            int NOT NULL,
    Units            int NOT NULL,
    ChargeAmount     decimal(18,2) NOT NULL,
    AllowedAmount    decimal(18,2) NOT NULL,
    PaidAmount       decimal(18,2) NOT NULL,
    CONSTRAINT UQ_ClaimLine UNIQUE (ClaimId, LineNumber),
    CONSTRAINT FK_ClaimLine_Claim FOREIGN KEY (ClaimId) REFERENCES claims.Claims(ClaimId),
    CONSTRAINT FK_ClaimLine_Cpt   FOREIGN KEY (CptId) REFERENCES ref.CptCodes(CptId)
);
GO

/* ----------------------------
   7) Pharmacy Claims
---------------------------- */
CREATE TABLE rx.RxClaims (
    RxClaimId        bigint IDENTITY(1,1) PRIMARY KEY,
    RxClaimNumber    varchar(30) NOT NULL UNIQUE,
    PatientId        bigint NOT NULL,
    PlanId           int NOT NULL,
    PrescriberId     bigint NOT NULL,
    PharmacyNpi      char(10) NOT NULL,               -- simplified: not a full provider entity here
    NdcId            int NOT NULL,
    FillDate         date NOT NULL,
    DaysSupply       int NOT NULL,
    Quantity         decimal(18,3) NOT NULL,
    IngredientCost   decimal(18,2) NOT NULL,
    DispensingFee    decimal(18,2) NOT NULL,
    TotalPaid        decimal(18,2) NOT NULL,
    CONSTRAINT FK_Rx_Patient   FOREIGN KEY (PatientId) REFERENCES dbo.Patients(PatientId),
    CONSTRAINT FK_Rx_Plan      FOREIGN KEY (PlanId) REFERENCES dbo.Plans(PlanId),
    CONSTRAINT FK_Rx_Prescriber FOREIGN KEY (PrescriberId) REFERENCES dbo.Providers(ProviderId),
    CONSTRAINT FK_Rx_Ndc       FOREIGN KEY (NdcId) REFERENCES ref.NdcCodes(NdcId)
);
GO

/* ----------------------------
   8) Helpful Indexes (basic)
---------------------------- */
CREATE INDEX IX_Encounters_PatientDate ON ehr.Encounters(PatientId, EncounterDate);
CREATE INDEX IX_Diagnoses_Encounter     ON ehr.Diagnoses(EncounterId);
CREATE INDEX IX_Procedures_Encounter    ON ehr.Procedures(EncounterId);
CREATE INDEX IX_Labs_Encounter          ON ehr.LabResults(EncounterId);

CREATE INDEX IX_Claims_PatientDate      ON claims.Claims(PatientId, ServiceFromDate);
CREATE INDEX IX_ClaimLines_Claim        ON claims.ClaimLines(ClaimId);

CREATE INDEX IX_RxClaims_PatientDate    ON rx.RxClaims(PatientId, FillDate);
GO

/* ============================================================================
   Stored Procedure: Generate Synthetic Data
   - @Rows: core table row target (default 100,000)
   - Generates lookups if empty
============================================================================ */
CREATE OR ALTER PROCEDURE dbo.usp_GenerateSyntheticHealthcareData
    @Rows int = 100000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Rows IS NULL OR @Rows <= 0
        THROW 50000, '@Rows must be a positive integer.', 1;

    BEGIN TRY
        BEGIN TRAN;

        /* ----------------------------
           A) Seed Lookup Tables (only if empty)
        ---------------------------- */
        IF NOT EXISTS (SELECT 1 FROM ref.FirstNames)
        BEGIN
            INSERT INTO ref.FirstNames(FirstName)
            VALUES ('James'),('Mary'),('John'),('Patricia'),('Robert'),('Jennifer'),('Michael'),('Linda'),
                   ('William'),('Elizabeth'),('David'),('Barbara'),('Richard'),('Susan'),('Joseph'),('Jessica'),
                   ('Thomas'),('Sarah'),('Charles'),('Karen'),('Christopher'),('Nancy'),('Daniel'),('Lisa'),
                   ('Matthew'),('Betty'),('Anthony'),('Margaret'),('Mark'),('Sandra'),
                   ('Andrew'),('Ashley'),('Joshua'),('Kimberly'),('Kevin'),('Emily'),
                   ('Brian'),('Donna'),('George'),('Michelle'),('Timothy'),('Carol'),
                   ('Ronald'),('Amanda'),('Edward'),('Melissa'),('Jason'),('Deborah');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.LastNames)
        BEGIN
            INSERT INTO ref.LastNames(LastName)
            VALUES ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),('Davis'),
                   ('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),('Gonzalez'),('Wilson'),('Anderson'),
                   ('Thomas'),('Taylor'),('Moore'),('Jackson'),('Martin'),('Lee'),('Perez'),('Thompson'),
                   ('White'),('Harris'),('Sanchez'),('Clark'),('Ramirez'),('Lewis'),('Robinson'),
                   ('Walker'),('Young'),('Allen'),('King'),('Wright'),('Scott'),('Torres'),('Nguyen'),
                   ('Hill'),('Flores'),('Green'),('Adams'),('Nelson'),('Baker'),('Hall'),('Rivera');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.ProviderSpecialties)
        BEGIN
            INSERT INTO ref.ProviderSpecialties(Specialty)
            VALUES ('Family Medicine'),('Internal Medicine'),('Pediatrics'),('OB/GYN'),('Cardiology'),
                   ('Orthopedics'),('Dermatology'),('Neurology'),('Psychiatry'),('Emergency Medicine'),
                   ('Radiology'),('Anesthesiology'),('General Surgery'),('Endocrinology'),('Oncology'),
                   ('Gastroenterology'),('Pulmonology'),('Nephrology'),('Urology'),('Ophthalmology');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.Icd10Codes)
        BEGIN
            /* Simplified sample ICD-10 set (not exhaustive) */
            INSERT INTO ref.Icd10Codes(Icd10Code, Description)
            VALUES ('E11.9','Type 2 diabetes mellitus without complications'),
                   ('I10','Essential (primary) hypertension'),
                   ('J06.9','Acute upper respiratory infection, unspecified'),
                   ('M54.5','Low back pain'),
                   ('F41.1','Generalized anxiety disorder'),
                   ('E78.5','Hyperlipidemia, unspecified'),
                   ('J45.909','Asthma, unspecified, uncomplicated'),
                   ('K21.9','GERD without esophagitis'),
                   ('N39.0','UTI, site not specified'),
                   ('R07.9','Chest pain, unspecified'),
                   ('R51.9','Headache, unspecified'),
                   ('R10.9','Abdominal pain, unspecified'),
                   ('Z00.00','Encounter for general adult medical exam w/o abnormal findings'),
                   ('Z12.11','Encounter for screening for malignant neoplasm of colon'),
                   ('Z23','Encounter for immunization'),
                   ('M17.11','Unilateral primary osteoarthritis, right knee'),
                   ('I25.10','Atherosclerotic heart disease of native coronary artery w/o angina'),
                   ('E03.9','Hypothyroidism, unspecified'),
                   ('G47.33','Obstructive sleep apnea'),
                   ('F32.9','Major depressive disorder, single episode, unspecified');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.CptCodes)
        BEGIN
            /* Simplified sample CPT set */
            INSERT INTO ref.CptCodes(CptCode, Description)
            VALUES ('99213','Office/outpatient visit est'),
                   ('99214','Office/outpatient visit est, detailed'),
                   ('93000','Electrocardiogram'),
                   ('80053','Comprehensive metabolic panel'),
                   ('85025','CBC with differential'),
                   ('83036','Hemoglobin A1c'),
                   ('80061','Lipid panel'),
                   ('36415','Venipuncture'),
                   ('71046','Chest X-ray 2 views'),
                   ('73562','Knee X-ray 3 views'),
                   ('90686','Influenza vaccine'),
                   ('90715','Tdap vaccine'),
                   ('81003','Urinalysis, automated'),
                   ('84443','TSH'),
                   ('45378','Colonoscopy, diagnostic'),
                   ('99441','Telephone evaluation'),
                   ('93010','ECG interpretation'),
                   ('12002','Simple repair of superficial wounds'),
                   ('20610','Arthrocentesis, major joint'),
                   ('97110','Therapeutic exercises');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.LoincCodes)
        BEGIN
            /* Simplified sample LOINC set */
            INSERT INTO ref.LoincCodes(LoincCode, Description, Units)
            VALUES ('4548-4','Hemoglobin A1c/Hemoglobin.total in Blood','%'),
                   ('718-7','Hemoglobin [Mass/volume] in Blood','g/dL'),
                   ('6690-2','Leukocytes [#/volume] in Blood','10^3/uL'),
                   ('2093-3','Cholesterol [Mass/volume] in Serum or Plasma','mg/dL'),
                   ('2085-9','HDL Cholesterol','mg/dL'),
                   ('13457-7','LDL Cholesterol','mg/dL'),
                   ('6298-4','Potassium','mmol/L'),
                   ('2951-2','Sodium','mmol/L'),
                   ('2160-0','Creatinine','mg/dL'),
                   ('3094-0','Urea nitrogen','mg/dL'),
                   ('1751-7','Albumin','g/dL'),
                   ('1975-2','Bilirubin.total','mg/dL'),
                   ('2885-2','Protein.total','g/dL'),
                   ('5792-7','Glucose','mg/dL'),
                   ('14647-2','Triglyceride','mg/dL'),
                   ('3016-3','Thyrotropin (TSH)','uIU/mL');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.DrugNames)
        BEGIN
            INSERT INTO ref.DrugNames(DrugName)
            VALUES ('Metformin'),('Lisinopril'),('Atorvastatin'),('Levothyroxine'),
                   ('Albuterol'),('Omeprazole'),('Sertraline'),('Amlodipine'),
                   ('Hydrochlorothiazide'),('Losartan'),('Gabapentin'),('Azithromycin'),
                   ('Amoxicillin'),('Fluoxetine'),('Insulin glargine'),('Montelukast');
        END

        IF NOT EXISTS (SELECT 1 FROM ref.NdcCodes)
        BEGIN
            /* Simplified NDC-like codes; one+ per drug */
            INSERT INTO ref.NdcCodes(NdcCode, DrugId, Strength, DosageForm)
            SELECT CONCAT('0000', RIGHT('0000' + CAST(d.DrugId AS varchar(4)), 4), '-01-01'),
                   d.DrugId,
                   CASE WHEN d.DrugName IN ('Metformin') THEN '500 mg'
                        WHEN d.DrugName IN ('Lisinopril') THEN '10 mg'
                        WHEN d.DrugName IN ('Atorvastatin') THEN '20 mg'
                        WHEN d.DrugName IN ('Levothyroxine') THEN '50 mcg'
                        WHEN d.DrugName IN ('Albuterol') THEN '90 mcg/act'
                        WHEN d.DrugName IN ('Omeprazole') THEN '20 mg'
                        WHEN d.DrugName IN ('Sertraline') THEN '50 mg'
                        ELSE '10 mg' END,
                   CASE WHEN d.DrugName IN ('Albuterol') THEN 'Inhaler' ELSE 'Tablet' END
            FROM ref.DrugNames d;
        END

        /* Seed payers/plans/facilities if empty */
        IF NOT EXISTS (SELECT 1 FROM dbo.Payers)
        BEGIN
            INSERT INTO dbo.Payers(PayerName)
            VALUES ('Acme Health'),('Blue Example'),('United Sample'),('State Medicaid'),('Medicare');
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Plans)
        BEGIN
            INSERT INTO dbo.Plans(PayerId, PlanName, PlanType)
            SELECT p.PayerId,
                   CONCAT(p.PayerName, ' Standard'),
                   CASE WHEN p.PayerName LIKE '%Medicaid%' THEN 'Medicaid'
                        WHEN p.PayerName LIKE '%Medicare%' THEN 'Medicare'
                        ELSE (CASE WHEN (p.PayerId % 2)=0 THEN 'PPO' ELSE 'HMO' END)
                   END
            FROM dbo.Payers p;

            INSERT INTO dbo.Plans(PayerId, PlanName, PlanType)
            SELECT p.PayerId, CONCAT(p.PayerName, ' Plus'), 'PPO'
            FROM dbo.Payers p
            WHERE p.PayerName NOT IN ('State Medicaid','Medicare');
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Facilities)
        BEGIN
            ;WITH n AS (
                SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM sys.all_objects a CROSS JOIN sys.all_objects b
            )
            INSERT INTO dbo.Facilities(FacilityName, FacilityType, ZipCode)
            SELECT CONCAT('Facility ', rn),
                   CASE WHEN rn % 5 = 0 THEN 'Hospital'
                        WHEN rn % 5 = 1 THEN 'Clinic'
                        WHEN rn % 5 = 2 THEN 'Lab'
                        WHEN rn % 5 = 3 THEN 'Imaging'
                        ELSE 'UrgentCare' END,
                   RIGHT('00000' + CAST(10000 + (rn * 37 % 89999) AS varchar(5)), 5)
            FROM n;
        END

        /* ----------------------------
           B) Build a reusable Numbers source up to @Rows
           (Uses sys.all_objects cross joins to get enough rows.)
        ---------------------------- */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        /* Patients: ~@Rows */
        INSERT INTO dbo.Patients WITH (TABLOCK)
            (MemberId, FirstName, LastName, DateOfBirth, Sex, ZipCode)
        SELECT
            CONCAT('M', RIGHT('0000000000' + CAST(n AS varchar(10)), 10)),
            fn.FirstName,
            ln.LastName,
            DATEADD(DAY, -1 * (ABS(CHECKSUM(NEWID())) % (365*85)), CAST('2025-12-13' AS date)), -- DOB within ~85 years
            CASE WHEN (ABS(CHECKSUM(NEWID())) % 2) = 0 THEN 'M' ELSE 'F' END,
            RIGHT('00000' + CAST(10000 + (ABS(CHECKSUM(NEWID())) % 89999) AS varchar(5)), 5)
        FROM nums
        CROSS APPLY (SELECT TOP (1) FirstName FROM ref.FirstNames ORDER BY NEWID()) fn
        CROSS APPLY (SELECT TOP (1) LastName  FROM ref.LastNames  ORDER BY NEWID()) ln
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Patients);  -- guard: only generate if table empty

        /* Providers: ~@Rows */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO dbo.Providers WITH (TABLOCK)
            (Npi, FirstName, LastName, SpecialtyId)
        SELECT
            RIGHT('0000000000' + CAST(1000000000 + n AS varchar(10)), 10),
            fn.FirstName,
            ln.LastName,
            (SELECT TOP (1) SpecialtyId FROM ref.ProviderSpecialties ORDER BY NEWID())
        FROM nums
        CROSS APPLY (SELECT TOP (1) FirstName FROM ref.FirstNames ORDER BY NEWID()) fn
        CROSS APPLY (SELECT TOP (1) LastName  FROM ref.LastNames  ORDER BY NEWID()) ln
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Providers);

        /* Coverage: ~@Rows */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO dbo.PatientCoverage WITH (TABLOCK)
            (PatientId, PlanId, CoverageStart, CoverageEnd)
        SELECT
            p.PatientId,
            (SELECT TOP (1) PlanId FROM dbo.Plans ORDER BY NEWID()),
            DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 3650), CAST('2025-12-13' AS date)), -- within ~10 years
            NULL
        FROM nums
        JOIN dbo.Patients p
          ON p.PatientId = n
        WHERE NOT EXISTS (SELECT 1 FROM dbo.PatientCoverage);

        /* Encounters: ~@Rows */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO ehr.Encounters WITH (TABLOCK)
            (PatientId, ProviderId, FacilityId, EncounterDate, EncounterType, Reason)
        SELECT
            p.PatientId,
            1 + (ABS(CHECKSUM(NEWID())) % (SELECT COUNT_BIG(*) FROM dbo.Providers)),
            1 + (ABS(CHECKSUM(NEWID())) % (SELECT COUNT_BIG(*) FROM dbo.Facilities)),
            DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 1460), CAST('2025-12-13' AS date)), -- last ~4 years
            CASE WHEN n % 10 = 0 THEN 'ED'
                 WHEN n % 10 = 1 THEN 'IP'
                 WHEN n % 10 = 2 THEN 'Tele'
                 ELSE 'OP' END,
            CASE WHEN n % 6 = 0 THEN 'Follow-up'
                 WHEN n % 6 = 1 THEN 'Annual physical'
                 WHEN n % 6 = 2 THEN 'Acute complaint'
                 WHEN n % 6 = 3 THEN 'Medication refill'
                 WHEN n % 6 = 4 THEN 'Lab review'
                 ELSE 'Screening' END
        FROM nums
        JOIN dbo.Patients p
          ON p.PatientId = n
        WHERE NOT EXISTS (SELECT 1 FROM ehr.Encounters);

        /* Diagnoses: ~@Rows (1 dx per encounter) */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO ehr.Diagnoses WITH (TABLOCK)
            (EncounterId, Icd10Id, DxRank, PresentOnAdmit)
        SELECT
            e.EncounterId,
            (SELECT TOP (1) Icd10Id FROM ref.Icd10Codes ORDER BY NEWID()),
            1,
            CASE WHEN e.EncounterType = 'IP' THEN 1 ELSE NULL END
        FROM nums
        JOIN ehr.Encounters e
          ON e.EncounterId = n
        WHERE NOT EXISTS (SELECT 1 FROM ehr.Diagnoses);

        /* Procedures: ~@Rows (1 px per encounter) */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO ehr.Procedures WITH (TABLOCK)
            (EncounterId, CptId, PerformedDate)
        SELECT
            e.EncounterId,
            (SELECT TOP (1) CptId FROM ref.CptCodes ORDER BY NEWID()),
            e.EncounterDate
        FROM nums
        JOIN ehr.Encounters e
          ON e.EncounterId = n
        WHERE NOT EXISTS (SELECT 1 FROM ehr.Procedures);

        /* Labs: ~@Rows (1 lab per encounter) */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO ehr.LabResults WITH (TABLOCK)
            (EncounterId, LoincId, ResultDate, ResultValueNum, ResultValueText, Units, AbnormalFlag)
        SELECT
            e.EncounterId,
            l.LoincId,
            e.EncounterDate,
            CAST((ABS(CHECKSUM(NEWID())) % 20000) / 100.0 AS decimal(18,4)),
            NULL,
            l.Units,
            CASE WHEN (ABS(CHECKSUM(NEWID())) % 10) = 0 THEN 'H'
                 WHEN (ABS(CHECKSUM(NEWID())) % 10) = 1 THEN 'L'
                 ELSE 'N' END
        FROM nums
        JOIN ehr.Encounters e
          ON e.EncounterId = n
        CROSS APPLY (SELECT TOP (1) LoincId, Units FROM ref.LoincCodes ORDER BY NEWID()) l
        WHERE NOT EXISTS (SELECT 1 FROM ehr.LabResults);

        /* Claims headers: ~@Rows (roughly aligned to encounters/patients) */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO claims.Claims WITH (TABLOCK)
            (ClaimNumber, PatientId, PlanId, ProviderId, FacilityId, ServiceFromDate, ServiceThruDate,
             BillType, ClaimStatus, TotalCharge, AllowedAmount, PaidAmount)
        SELECT
            CONCAT('C', RIGHT('000000000000' + CAST(n AS varchar(12)), 12)),
            e.PatientId,
            (SELECT TOP (1) pc.PlanId FROM dbo.PatientCoverage pc WHERE pc.PatientId = e.PatientId ORDER BY pc.CoverageStart DESC),
            e.ProviderId,
            e.FacilityId,
            e.EncounterDate,
            e.EncounterDate,
            CASE WHEN e.EncounterType='IP' THEN '111' ELSE '131' END,
            CASE WHEN n % 12 = 0 THEN 'Denied'
                 WHEN n % 12 = 1 THEN 'Pended'
                 ELSE 'Paid' END,
            CAST(50.00 + (ABS(CHECKSUM(NEWID())) % 200000) / 10.0 AS decimal(18,2)),
            CAST(30.00 + (ABS(CHECKSUM(NEWID())) % 150000) / 10.0 AS decimal(18,2)),
            CAST(10.00 + (ABS(CHECKSUM(NEWID())) % 140000) / 10.0 AS decimal(18,2))
        FROM nums
        JOIN ehr.Encounters e
          ON e.EncounterId = n
        WHERE NOT EXISTS (SELECT 1 FROM claims.Claims);

        /* Claim lines: ~@Rows (1 line per claim) */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO claims.ClaimLines WITH (TABLOCK)
            (ClaimId, LineNumber, CptId, Units, ChargeAmount, AllowedAmount, PaidAmount)
        SELECT
            c.ClaimId,
            1,
            (SELECT TOP (1) CptId FROM ref.CptCodes ORDER BY NEWID()),
            1 + (ABS(CHECKSUM(NEWID())) % 4),
            CAST(c.TotalCharge AS decimal(18,2)),
            CAST(c.AllowedAmount AS decimal(18,2)),
            CAST(CASE WHEN c.ClaimStatus='Paid' THEN c.PaidAmount ELSE 0 END AS decimal(18,2))
        FROM nums
        JOIN claims.Claims c
          ON c.ClaimId = n
        WHERE NOT EXISTS (SELECT 1 FROM claims.ClaimLines);

        /* Rx claims: ~@Rows */
        ;WITH nums AS (
            SELECT TOP (@Rows)
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
            FROM sys.all_objects a
            CROSS JOIN sys.all_objects b
        )
        INSERT INTO rx.RxClaims WITH (TABLOCK)
            (RxClaimNumber, PatientId, PlanId, PrescriberId, PharmacyNpi, NdcId,
             FillDate, DaysSupply, Quantity, IngredientCost, DispensingFee, TotalPaid)
        SELECT
            CONCAT('R', RIGHT('000000000000' + CAST(n AS varchar(12)), 12)),
            p.PatientId,
            (SELECT TOP (1) pc.PlanId FROM dbo.PatientCoverage pc WHERE pc.PatientId = p.PatientId ORDER BY pc.CoverageStart DESC),
            1 + (ABS(CHECKSUM(NEWID())) % (SELECT COUNT_BIG(*) FROM dbo.Providers)),
            RIGHT('0000000000' + CAST(2000000000 + (ABS(CHECKSUM(NEWID())) % 9000000) AS varchar(10)), 10),
            (SELECT TOP (1) NdcId FROM ref.NdcCodes ORDER BY NEWID()),
            DATEADD(DAY, -1*(ABS(CHECKSUM(NEWID())) % 1460), CAST('2025-12-13' AS date)),
            CASE WHEN n % 8 = 0 THEN 90 ELSE 30 END,
            CAST(10 + (ABS(CHECKSUM(NEWID())) % 90) AS decimal(18,3)),
            CAST(5.00 + (ABS(CHECKSUM(NEWID())) % 50000) / 100.0 AS decimal(18,2)),
            CAST(1.00 + (ABS(CHECKSUM(NEWID())) % 1500) / 100.0 AS decimal(18,2)),
            CAST(6.00 + (ABS(CHECKSUM(NEWID())) % 52000) / 100.0 AS decimal(18,2))
        FROM nums
        JOIN dbo.Patients p
          ON p.PatientId = n
        WHERE NOT EXISTS (SELECT 1 FROM rx.RxClaims);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;

        DECLARE @msg nvarchar(4000) = CONCAT(
            'Error: ', ERROR_MESSAGE(),
            ' (Line ', ERROR_LINE(), ', Proc ', COALESCE(ERROR_PROCEDURE(), '<adhoc>'), ')'
        );
        THROW 50001, @msg, 1;
    END CATCH
END
GO

/* ============================================================================
   Run the generator (defaults to 100k)
============================================================================ */
-- EXEC dbo.usp_GenerateSyntheticHealthcareData @Rows = 100000;

/* Quick sanity checks */
SELECT COUNT(*) AS Patients    FROM dbo.Patients;
SELECT COUNT(*) AS Providers   FROM dbo.Providers;
SELECT COUNT(*) AS Encounters  FROM ehr.Encounters;
SELECT COUNT(*) AS Diagnoses   FROM ehr.Diagnoses;
SELECT COUNT(*) AS Procedures  FROM ehr.Procedures;
SELECT COUNT(*) AS LabResults  FROM ehr.LabResults;
SELECT COUNT(*) AS Claims      FROM claims.Claims;
SELECT COUNT(*) AS ClaimLines  FROM claims.ClaimLines;
SELECT COUNT(*) AS RxClaims    FROM rx.RxClaims;
