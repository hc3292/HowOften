{DEFAULT @cdm_database = 'ohdsi'}
{DEFAULT @cdm_database_schema = 'ohdsi.dbo'}
{DEFAULT @results_database = 'ohdsi'}
{DEFAULT @results_database_schema = 'ohdsi.dbo'}
{DEFAULT @min_persons_exposed = '10'}


--create cohort definition
IF OBJECT_ID('@results_database_schema.IR_cohort_definition', 'U') IS NOT NULL
	drop table @results_database_schema.IR_cohort_definition;

create table @results_database_schema.IR_cohort_definition
(
	cohort_definition_id bigint,
	cohort_name varchar(500),
	concept_id bigint,
	cohort_type int  --0: exposure, 1: outcome with 1st diagnosis; 2: outcome with 1st diagnosis + hospital
)
;


--create cohort summary
IF OBJECT_ID('@results_database_schema.IR_cohort_summary', 'U') IS NOT NULL
	drop table @results_database_schema.IR_cohort_summary;

create table @results_database_schema.IR_cohort_summary
(
	cohort_definition_id bigint,
	num_persons bigint
)
;

--create IR exposure outcome summary
IF OBJECT_ID('@results_database_schema.IR_exposure_outcome_summary', 'U') IS NOT NULL
	drop table @results_database_schema.IR_exposure_outcome_summary ;

CREATE TABLE @results_database_schema.IR_exposure_outcome_summary (
	target_cohort_definition_id int NOT NULL,
	outcome_cohort_definition_id bigint NULL,
	num_persons int NULL,
	num_persons_prior_outcome int NULL,
	num_persons_at_risk int NULL,
	num_persons_post_30d int NULL,
	pt_30d numeric(38, 6) NULL,
	ip_30d numeric(24, 12) NULL,
	ir_30d numeric(38, 20) NULL,
	num_persons_post_365d int NULL,
	pt_365d numeric(38, 6) NULL,
	ip_365d numeric(24, 12) NULL,
	ir_365d numeric(38, 20) NULL,
	num_persons_post_pp int NULL,
	pt_pp numeric(38, 6) NULL,
	ip_pp numeric(24, 12) NULL,
	ir_pp numeric(38, 20) NULL,
	num_persons_post_itt int NULL,
	pt_itt numeric(38, 6) NULL,
	ip_itt numeric(24, 12) NULL,
	ir_itt numeric(38, 20) NULL,
	num_persons_at_risk_30d_fulltime int NULL,
	pt_30d_fulltime numeric(38, 6) NULL,
	ip_30d_fulltime numeric(24, 12) NULL,
	ir_30d_fulltime numeric(38, 20) NULL,
	num_persons_at_risk_365d_fulltime int NULL,
	pt_365d_fulltime numeric(38, 6) NULL,
	ip_365d_fulltime numeric(24, 12) NULL,
	ir_365d_fulltime numeric(38, 20) NULL
)


/************************************************
*************************************************

Calculate incidence rates for all incident outcomes

**************************************************
*************************************************/


--all exposure cohorts:  new users of drugs, newly diagnosed,1yr washout
IF OBJECT_ID('#exposure_cohort', 'U') IS NOT NULL
	drop table #exposure_cohort;

--create table #exposure_cohort  as
select de1.person_id as subject_id, de1.cohort_definition_id, de1.cohort_start_date, de1.cohort_end_date, op1.observation_period_end_date
into #exposure_cohort
from
(select person_id, drug_concept_id as cohort_definition_id, drug_era_start_date as cohort_start_date, drug_era_end_date as cohort_end_date, row_number() over (partition by person_id, drug_concept_id order by drug_era_start_date asc) rn1
from @cdm_database_schema.drug_era
where drug_concept_id > 0
--and drug_concept_id in (select descendant_concept_id from concept_ancestor where ancestor_concept_id = 1308216)
) de1
inner join @cdm_database_schema.observation_period op1
on de1.person_id = op1.person_id
and de1.cohort_start_date >= dateadd(dd,365,op1.observation_period_start_date)
and de1.cohort_start_date <= op1.observation_period_end_date
and de1.rn1 = 1
;

insert into @results_database_schema.IR_cohort_definition (cohort_definition_id, cohort_name, concept_id, cohort_type)
select e1.cohort_definition_id, 'New users of: ' + c1.concept_name as cohort_name, c1.concept_id, 0 as cohort_type
from
(
select distinct cohort_definition_id
from #exposure_cohort
) e1
inner join @cdm_database_schema.concept c1
on e1.cohort_definition_id = c1.concept_id
;


--ToDo: should min_persons_exposed be 1000 or 10
insert into @results_database_schema.IR_cohort_summary (cohort_definition_id, num_persons)
select c1.cohort_definition_id,
		count(c1.subject_id) as num_persons
	from #exposure_cohort c1
	group by c1.cohort_definition_id
	having count(c1.subject_id) > 1000 --@min_persons_exposed
;








--define set of concepts to be used as eligble concepts
IF OBJECT_ID('#concept_anc_group', 'U') IS NOT NULL
	drop table #concept_anc_group;

--create a temp table of concepts to aggregate to:
--create table #concept_anc_group  as
select ca1.ancestor_concept_id, ca1.descendant_concept_id
into #concept_anc_group
from @cdm_database_schema.concept_ancestor ca1
inner join
(
select c1.concept_id, c1.concept_name, c1.vocabulary_id, c1.domain_id
from @cdm_database_schema.concept c1
inner join @cdm_database_schema.concept_ancestor ca1
on ca1.ancestor_concept_id = 441840 /* clinical finding */
and c1.concept_id = ca1.descendant_concept_id
where c1.concept_name not like '%finding'
and c1.concept_name not like 'disorder of%'
and c1.concept_name not like 'finding of%'
and c1.concept_name not like 'finding related to%'
and c1.concept_name not like 'disease of%'
and c1.concept_name not like 'injury of%'
and c1.concept_name not like '%by site'
and c1.concept_name not like '%by body site'
and c1.concept_name not like '%by mechanism'
and c1.concept_name not like '%of body region'
and c1.concept_name not like '%of anatomical site'
and c1.concept_name not like '%of specific body structure%'
and c1.concept_name not in ('Disease','Clinical history and observation findings','General finding of soft tissue','Traumatic AND/OR non-traumatic injury','Drug-related disorder',
	'Traumatic injury', 'Mass of body structure','Soft tissue lesion','Neoplasm and/or hamartoma','Inflammatory disorder','Congenital disease','Inflammation of specific body systems','Disorder due to infection',
	'Musculoskeletal and connective tissue disorder','Inflammation of specific body organs','Complication','Finding by method','General finding of observation of patient',
	'O/E - specified examination findings','Skin or mucosa lesion','Skin lesion',	'Complication of procedure', 'Mass of trunk','Mass in head or neck', 'Mass of soft tissue','Bone injury','Head and neck injury',
	'Acute disease','Chronic disease', 'Lesion of skin and/or skin-associated mucous membrane')
and c1.domain_id = 'Condition'
) t1
on ca1.ancestor_concept_id = t1.concept_id
;


select count(*) from #concept_anc_group


--outcome cohorts 1:  first diagnosis of any sort
IF OBJECT_ID('#outcome_cohort_1', 'U') IS NOT NULL
	drop table #outcome_cohort_1;

--create table #outcome_cohort_1  as
select t1.person_id as subject_id, cast(t1.ancestor_concept_id as bigint)*100+1 as cohort_definition_id, t1.cohort_start_date, t1.cohort_start_date as cohort_end_date
into #outcome_cohort_1
from
(
select co1.person_id, ca1.ancestor_concept_id, min(co1.condition_start_date) as cohort_start_date
from @cdm_database_schema.condition_occurrence co1
inner join #concept_anc_group ca1
on co1.condition_concept_id = ca1.descendant_concept_id
group by co1.person_id, ca1.ancestor_concept_id
) t1
;


--outcome cohorts 2:  first diagnosis of a condition that is observed at hospital at some point
IF OBJECT_ID('#outcome_cohort_2', 'U') IS NOT NULL
	drop table #outcome_cohort_2;

--create table #outcome_cohort_2  as
select t1.person_id as subject_id, cast(t1.ancestor_concept_id as bigint)*100+2 as cohort_definition_id, t1.cohort_start_date, t1.cohort_start_date as cohort_end_date
into #outcome_cohort_2
from
(
select co1.person_id, ca1.ancestor_concept_id, min(co1.condition_start_date) as cohort_start_date
from @cdm_database_schema.condition_occurrence co1
inner join #concept_anc_group ca1
on co1.condition_concept_id = ca1.descendant_concept_id
group by co1.person_id, ca1.ancestor_concept_id
) t1
inner join
(
select co1.person_id, ca1.ancestor_concept_id, min(vo1.visit_start_date) as cohort_start_date
from @cdm_database_schema.condition_occurrence co1
inner join @cdm_database_schema.visit_occurrence vo1
on co1.person_Id = vo1.person_id
and co1.visit_occurrence_id = vo1.visit_occurrence_id
and visit_concept_id = 9201
inner join #concept_anc_group ca1
on co1.condition_concept_id = ca1.descendant_concept_id
group by co1.person_id, ca1.ancestor_concept_id
) t2
on t1.person_id = t2.person_id
and t1.ancestor_concept_id = t2.ancestor_concept_id
;


--outcome cohorts:  combine both types together
IF OBJECT_ID('#outcome_cohort', 'U') IS NOT NULL
	drop table #outcome_cohort;

--create table #outcome_cohort  as
select t1.* into #outcome_cohort
from
(
select subject_id, cohort_definition_id, cohort_start_date, cohort_end_date
from #outcome_cohort_1

union

select subject_id, cohort_definition_id, cohort_start_date, cohort_end_date
from #outcome_cohort_2
) t1
;




insert into @results_database_schema.IR_cohort_definition (cohort_definition_id, cohort_name, concept_id, cohort_type)
select e1.cohort_definition_id, case when right(e1.cohort_definition_id, 1) = '1' then 'First diagnosis of: ' when right(e1.cohort_definition_id, 1) = '2' then 'First diagnosis and >=1 hospitalization with: ' else 'Other type of: ' end + c1.concept_name as cohort_name, c1.concept_id, right(e1.cohort_definition_id, 1) as cohort_type
from
(
select distinct cohort_definition_id
from #outcome_cohort
) e1
inner join concept c1
on left(e1.cohort_definition_id, len(e1.cohort_definition_id)-2) = c1.concept_id
;


insert into @results_database_schema.IR_cohort_summary (cohort_definition_id, num_persons)
select c1.cohort_definition_id,
		count(c1.subject_id) as num_persons
	from #outcome_cohort c1
	group by c1.cohort_definition_id
	having count(c1.subject_id) > 10 --@min_persons_outcome
;



IF OBJECT_ID('#drug_summary', 'U') IS NOT NULL
	drop table #drug_summary;

--create table #drug_summary  as
select c1.cohort_definition_id,
		--count, regardless of length of available time-at-risk
		count(c1.subject_id) as num_persons,
		sum(datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date >= dateadd(dd,30,c1.cohort_start_date) then dateadd(dd,30,c1.cohort_start_date) else c1.observation_period_end_date end)/365.25) as pt_30d_post,
		sum(datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date >= dateadd(dd,365,c1.cohort_start_date) then dateadd(dd,365,c1.cohort_start_date) else c1.observation_period_end_date end)/365.25) as pt_365d_post,
		sum(datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date > c1.cohort_end_date then c1.cohort_end_date else c1.observation_period_end_date end)/365.25) as pt_pp_post,
		sum(datediff(dd,c1.cohort_start_date, c1.observation_period_end_date)/365.25) as pt_itt_post,
		--only count if have full time-at-risk
		sum(case when c1.observation_period_end_date >= dateadd(dd,30,c1.cohort_start_date) then 1 else 0 end) as num_persons_30d_fulltime,
		sum(datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date >= dateadd(dd,30,c1.cohort_start_date) then dateadd(dd,30,c1.cohort_start_date) else c1.cohort_start_date end)/365.25) as pt_30d_post_fulltime,
		sum(case when c1.observation_period_end_date >= dateadd(dd,365,c1.cohort_start_date) then 1 else 0 end) as num_persons_365d_fulltime,
		sum(datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date >= dateadd(dd,365,c1.cohort_start_date) then dateadd(dd,365,c1.cohort_start_date) else c1.cohort_start_date end)/365.25) as pt_365d_post_fulltime
into #drug_summary
	from #exposure_cohort c1
		inner join @results_database_schema.IR_cohort_summary cs1
		on c1.cohort_definition_id = cs1.cohort_definition_id
	group by c1.cohort_definition_id
;



IF OBJECT_ID('#drug_outcome_count', 'U') IS NOT NULL
	drop table #drug_outcome_count;

--create table #drug_outcome_count  as
select c1.cohort_definition_id as target_cohort_definition_id, oc1.cohort_definition_id as outcome_cohort_definition_id,
	--count # of persons with prior events and censored time for those prior event persons, regardless of length of available time-at-risk
	sum(case when oc1.cohort_start_date <= c1.cohort_start_date then 1 else 0 end) as num_persons_prior_outcome,
	sum(case when oc1.cohort_start_date <= c1.cohort_start_date then datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date > dateadd(dd,30,c1.cohort_start_date) then dateadd(dd,30,c1.cohort_start_date) else c1.observation_period_end_date end) else 0 end/365.25) as pt_30d_censor_prior,
	sum(case when oc1.cohort_start_date <= c1.cohort_start_date then datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date > dateadd(dd,365,c1.cohort_start_date) then dateadd(dd,365,c1.cohort_start_date) else c1.observation_period_end_date end) else 0 end/365.25) as pt_365d_censor_prior,
	sum(case when oc1.cohort_start_date <= c1.cohort_start_date then datediff(dd,c1.cohort_start_date,c1.observation_period_end_date) else 0 end/365.25) as pt_itt_censor_prior,
	sum(case when oc1.cohort_start_date <= c1.cohort_start_date then datediff(dd,c1.cohort_start_date,c1.cohort_end_date) else 0 end/365.25) as pt_pp_censor_prior,

	--only count if have full time-at-risk
	sum(case when c1.observation_period_end_date >= dateadd(dd,30,c1.cohort_start_date) and oc1.cohort_start_date <= c1.cohort_start_date then 1 else 0 end) as num_persons_prior_outcome_30d_fulltime,
	sum(case when c1.observation_period_end_date >= dateadd(dd,30,c1.cohort_start_date) and oc1.cohort_start_date <= c1.cohort_start_date then datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date > dateadd(dd,30,c1.cohort_start_date) then dateadd(dd,30,c1.cohort_start_date) else c1.observation_period_end_date end) else 0 end/365.25) as pt_30d_censor_prior_fulltime,
	sum(case when c1.observation_period_end_date >= dateadd(dd,365,c1.cohort_start_date) and oc1.cohort_start_date <= c1.cohort_start_date then 1 else 0 end) as num_persons_prior_outcome_365d_fulltime,
	sum(case when c1.observation_period_end_date >= dateadd(dd,365,c1.cohort_start_date) and oc1.cohort_start_date <= c1.cohort_start_date then datediff(dd,c1.cohort_start_date, case when c1.observation_period_end_date > dateadd(dd,365,c1.cohort_start_date) then dateadd(dd,365,c1.cohort_start_date) else c1.observation_period_end_date end) else 0 end/365.25) as pt_365d_censor_prior_fulltime,

	--count, regardless of length of available time-at-risk
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= dateadd(dd,30,c1.cohort_start_date) then 1 else 0 end) as num_persons_post_30d,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= dateadd(dd,30,c1.cohort_start_date) then datediff(dd,oc1.cohort_start_date,dateadd(dd,30,c1.cohort_start_date)) else 0 end/365.25) as pt_30d_censor_post,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= dateadd(dd,365,c1.cohort_start_date) then 1 else 0 end) as num_persons_post_365d,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= dateadd(dd,365,c1.cohort_start_date) then datediff(dd,oc1.cohort_start_date,dateadd(dd,365,c1.cohort_start_date)) else 0 end/365.25) as pt_365d_censor_post,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= c1.observation_period_end_date then 1 else 0 end) as num_persons_post_itt,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= c1.observation_period_end_date then datediff(dd,oc1.cohort_start_date,c1.observation_period_end_date) else 0 end/365.25) as pt_itt_censor_post,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= c1.cohort_end_date then 1 else 0 end) as num_persons_post_pp,
	sum(case when oc1.cohort_start_date > c1.cohort_start_date and oc1.cohort_start_date <= c1.cohort_end_date then datediff(dd,oc1.cohort_start_date,c1.cohort_end_date) else 0 end/365.25) as pt_pp_censor_post
	into #drug_outcome_count
from
#exposure_cohort c1
inner join #outcome_cohort oc1
on c1.subject_id = oc1.subject_id
group by c1.cohort_definition_id, oc1.cohort_definition_id
;



IF OBJECT_ID('#drug_outcome_summary', 'U') IS NOT NULL
	drop table #drug_outcome_summary;

--create table #drug_outcome_summary  as
select do1.target_cohort_definition_id,
	do1.outcome_cohort_definition_id,
	d1.num_persons,
	do1.num_persons_prior_outcome,
	d1.num_persons - do1.num_persons_prior_outcome as num_persons_at_risk,
	d1.num_persons_30d_fulltime - do1.num_persons_prior_outcome_30d_fulltime as num_persons_at_risk_30d_fulltime,
	d1.num_persons_365d_fulltime - do1.num_persons_prior_outcome_365d_fulltime as num_persons_at_risk_365d_fulltime,
	do1.num_persons_post_30d,
	d1.pt_30d_post - do1.pt_30d_censor_prior - do1.pt_30d_censor_post as pt_30d,
	do1.num_persons_post_365d,
	d1.pt_365d_post - do1.pt_365d_censor_prior - do1.pt_365d_censor_post as pt_365d,
	do1.num_persons_post_pp,
	d1.pt_pp_post - do1.pt_pp_censor_prior - do1.pt_pp_censor_post as pt_pp,
	do1.num_persons_post_itt,
	d1.pt_itt_post - do1.pt_itt_censor_prior - do1.pt_itt_censor_post as pt_itt,
	d1.pt_30d_post_fulltime - do1.pt_30d_censor_prior_fulltime - do1.pt_30d_censor_post as pt_30d_fulltime,
	d1.pt_365d_post_fulltime - do1.pt_365d_censor_prior_fulltime - do1.pt_365d_censor_post as pt_365d_fulltime
into #drug_outcome_summary
from
#drug_summary d1
inner join
#drug_outcome_count do1
on d1.cohort_definition_id = do1.target_cohort_definition_id
;






insert into @results_database_schema.IR_exposure_outcome_summary
	select dos1.target_cohort_definition_id,
		dos1.outcome_cohort_definition_id,
		dos1.num_persons,
		dos1.num_persons_prior_outcome,
		dos1.num_persons_at_risk,
		case when dos1.num_persons_post_30d > 10 then dos1.num_persons_post_30d else null end as num_persons_post_30d,
		dos1.pt_30d,
		case when dos1.num_persons_post_30d > 10 and dos1.num_persons_at_risk > 0 then 1.0*dos1.num_persons_post_30d / dos1.num_persons_at_risk else null end as ip_30d,
		case when dos1.num_persons_post_30d > 10 and dos1.pt_30d > 0 then 1.0*dos1.num_persons_post_30d / dos1.pt_30d else null end as ir_30d,
		case when dos1.num_persons_post_365d > 10 then dos1.num_persons_post_365d else null end as num_persons_post_365d,
		dos1.pt_365d,
		case when dos1.num_persons_post_365d > 10 and dos1.num_persons_at_risk > 0 then 1.0*dos1.num_persons_post_365d / dos1.num_persons_at_risk else null end as ip_365d,
		case when dos1.num_persons_post_365d > 10 and dos1.pt_365d > 0 then 1.0*dos1.num_persons_post_365d / dos1.pt_365d else null end as ir_365d,
		case when dos1.num_persons_post_pp > 10 then dos1.num_persons_post_pp else null end as num_persons_post_pp,
		dos1.pt_pp,
		case when dos1.num_persons_post_pp > 10 and dos1.num_persons_at_risk > 0 then 1.0*dos1.num_persons_post_pp / dos1.num_persons_at_risk else null end as ip_pp,
		case when dos1.num_persons_post_pp > 10 and dos1.pt_pp > 0 then 1.0*dos1.num_persons_post_pp / dos1.pt_pp else null end as ir_pp,
		case when dos1.num_persons_post_itt > 10 then dos1.num_persons_post_itt else null end as num_persons_post_itt,
		dos1.pt_itt,
		case when dos1.num_persons_post_itt > 10 and dos1.num_persons_at_risk > 0 then 1.0*dos1.num_persons_post_itt / dos1.num_persons_at_risk else null end as ip_itt,
		case when dos1.num_persons_post_itt > 10 and dos1.pt_itt > 0 then 1.0*dos1.num_persons_post_itt / dos1.pt_itt else null end as ir_itt,
		dos1.num_persons_at_risk_30d_fulltime,
		dos1.pt_30d_fulltime,
		case when dos1.num_persons_post_30d > 10 and dos1.num_persons_at_risk_30d_fulltime > 0 then 1.0*dos1.num_persons_post_30d / dos1.num_persons_at_risk_30d_fulltime else null end as ip_30d_fulltime,
		case when dos1.num_persons_post_30d > 10 and dos1.pt_30d_fulltime > 0 then 1.0*dos1.num_persons_post_30d / dos1.pt_30d_fulltime else null end as ir_30d_fulltime,
		dos1.num_persons_at_risk_365d_fulltime,
		dos1.pt_365d_fulltime,
		case when dos1.num_persons_post_365d > 10 and dos1.num_persons_at_risk_365d_fulltime > 0 then 1.0*dos1.num_persons_post_365d / dos1.num_persons_at_risk_365d_fulltime else null end as ip_365d_fulltime,
		case when dos1.num_persons_post_365d > 10 and dos1.pt_365d_fulltime > 0 then 1.0*dos1.num_persons_post_365d / dos1.pt_365d_fulltime else null end as ir_365d_fulltime
	from #drug_outcome_summary dos1
	where dos1.num_persons_post_itt > 10
;
