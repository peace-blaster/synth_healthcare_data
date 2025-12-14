select C.patientId,
	sum(case when ClaimStatus='paid' then 1 else 0 end) as claims_paid
from claims.Claims C
group by C.patientId
order by claims_paid desc;

/*
observe that no patient in the database has more than one paid claim
*/