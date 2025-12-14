select
	E.EncounterId
	, E.PatientId
	, LC.LoincCode
	, LC.[Description]
	, LR.ResultValueNum as LabResult
	, LC.Units
from ehr.Encounters E
join ehr.LabResults LR
	on E.EncounterId=LR.EncounterId
left join ref.LoincCodes LC
	on LC.LoincId=LR.LoincId;

/*
lab results by encounter
*/

select
	ED.EncounterId
	, ED.DxRank
	, IC.Icd10Code DX_CODE
	, IC.[Description] dx_description
from ehr.diagnoses ED
left join ref.Icd10Codes IC
	on IC.Icd10Id=ED.Icd10Id;

/*
diagnosis results by encounter
*/