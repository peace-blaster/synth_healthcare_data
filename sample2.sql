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