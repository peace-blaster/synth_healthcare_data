create or alter procedure dbo.member_payment_report
    @MemberId varchar(30)
    , @PayerName varchar(200)
with recompile
as
begin
    SET NOCOUNT ON;
    select
        PA.PayerName
		, PL.PlanName
        , P.MemberId
        , P.FirstName
        , P.LastName
        , P.ZipCode as PatientZipCode
        , F.FacilityName
        , F.FacilityType
        , F.ZipCode as FacilityZipCode
		, PR.Npi as ProviderNpi
		, PR.LastName as ProviderLastName
		, PS.Specialty as ProviderSpecialty
		, C.ClaimNumber
		, C.ServiceFromDate
		, C.ServiceThruDate
		, C.BillType
		, C.ClaimStatus
		, C.TotalCharge
		, C.AllowedAmount
		, C.PaidAmount
		, C.CreatedAt
    from dbo.Patients P
    join dbo.PatientCoverage PC
        on PC.PatientId = P.PatientId
	join dbo.Plans PL
		on PL.PlanId = PC.PlanId
    join dbo.Payers PA
        on PA.PayerId = PL.PayerId
    join claims.Claims C
        on C.PatientId = P.PatientId
    join dbo.Facilities F
        on F.FacilityId = C.FacilityId
	join dbo.Providers PR
		on PR.ProviderId = C.ProviderId
	join ref.ProviderSpecialties PS
		on PS.SpecialtyId = PR.SpecialtyId
    where
        P.MemberId = @MemberId
        and
        PA.PayerName = @PayerName
    order by C.ServiceFromDate;
end;

-- exec dbo.member_payment_report @MemberId = M0000000001, @PayerName = 'United Sample';