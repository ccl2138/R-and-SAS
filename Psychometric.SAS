
*|**********************************************************************;
* Project           : Psychometric
*
* Program name      : \Claire\Cognitive\Final Programs Data Output\Cognitive Final Program.sas
*                       This file was created by extensively modifing this previous program:
*                           \Claire\Cognitive\Initial SAS and R programs for cognitive\psych CLEAN.sas
*                   
*
* Author            : CCL
*
* Date created      : 07/29/2013
*
* Purpose           :1. Is there a relationship between phenomenology of the 
*					FSE at baseline and baseline neuropsychological testing in the FEBSTAT cohort?
*					2. Is there a relationship between demographics of the FEBSTAT cohort at 
*					baseline and baseline neuropsychological testing?
*
*
* Related files		: All should be contained in 'Final Programs Data Output' folder.  Previous note:
*                           lots i think?  I'm going to make a final program at some point which will make
*                         this one redundant but currently (today is 04/05/2013), I think the vineland.sas program
*                         and maybe the neuro_format.sas program seem important?
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* 
*
*|**********************************************************************;


libname cmac '\\10.115.15.133\cdc\Claire\Macros';
options mautosource sasautos='\\10.115.15.133\cdc\Claire\Macros';
options nodate nocenter nonumber linesize = 150 pagesize = 45 mprint symbolgen spool mstored sasmstore = cmac;

/* *contains psychometric stuff, TCR01 and T1h01; */
    /* **CCL 07/29/2013: using data released on 07/19/2013 */
libname febstat "\\10.115.15.133\cdc\FEBSTAT\Datasets"; 
    /* Hippocampal Volume data */
libname hipp_vol "\\10.115.15.133\cdc\Claire\Darrel Lewis Data\Hippocampal Volume Data";

libname finaldat "\\10.115.15.133\cdc\Claire\Cognitive\Final Programs Data Output";

options fmtsearch = (febstat.fmt32 finaldat.cognitive_fmts); 
/* ************************************************************************************************************************ */
        /*proc format library = finaldat.cognitive_fmts;*/
        /*    value durconsfmt 0- <60 = "< 60 min Duration FSE" 60 - high = "> 60 min Duration FSE" OTHER = "Missing Value";*/
        /*    value focconsfmt 1,2 = "Focal Seizure" 3,4 = "non-Focal Seizure" OTHER = "Missing Value";*/
        /*    value typconsfmt 1 = "Continuous" 2,3 = "Intermittent" OTHER = "Missing Value";*/
        /*    value pszconsfmt 1 = "Prior FS" 2 = "No Prior FS" OTHER = "Missing Value";*/
        /*    value priconsfmt 1 = "Normal Prior Development" 2,3 = "Abnormal/suspect Prior Development" OTHER = "Missing Value";*/
        /*    value race_ethfmt 0 = "White, Non-Hispanic" 1 = "Black, Non-Hispanic" 2 = "Hispanic" 3 = "Other, Non-Hispanic" OTHER = "Missing Value";*/
        /*    value sexfmt 0 = "Male" 1 = "Female" OTHER = "Missing Value";*/
        /*    run;*/
/* ************************************************************************************************************************ */


/* Bring in Neuropsych data (latest release as of 07/29/2013: 7/18/2013 & 7/19/2013), TCR01, & T1H01 */
    /* First make dataset with baseline characteristics from TCR01 & T1H01 */
    /* PHENOM_DEMO: n=199 | var = 13 */
    proc sql;
        create table phenom_demo as
        select tcr.idnum, tcr.iecnum, tcr.dob, tcr.datesz, tcr.durcons, tcr.typcons, tcr.foccons, tcr.pszcons, tcr.pricons,
                t1h.sex, t1h.race, t1h.etnicity, 
                CASE
                when t1h.etnicity = 1 then 2
                when t1h.etnicity = 0 and t1h.race = 0 then 0
                when t1h.etnicity = 0 and t1h.race = 1 then 1
                when t1h.etnicity = 0 and t1h.race = 2 then 3
                when t1h.etnicity = 0 and t1h.race = 3 then 2
                when t1h.etnicity = 0 and t1h.race in (4, 5, 6, 7) then 3
                else .
                end as race_eth
        from febstat.tcr01(where = (sznum = 1 and idnum ne "2P038")) as tcr
        RIGHT JOIN
            febstat.t1h01(where = (idnum ne "2P038")) as t1h
        on tcr.idnum = t1h.idnum
        order by idnum;
        quit;

    /* NEUROPSYCH_ONLY: N = 312 | Var = 10 */
    data neuropsych_only;
        set febstat.neuropsych_7_18_13;
        where (visitcode1 in (20, 2) | visitcode2 in (20, 2) | visitcode3 in (20, 2));
        /* change subject_id to IDNUM */
        idnum = input(trim(left(subject_id)), $5.);

        /* delete 2P038 */
        if idnum = "2P038" then delete;

        keep idnum dotest visitcode1 visitcode2 visitcode3 bayley_motor_adj bayley_mental_adj McCarthy_memory_tscore ppvt_version ppvt_stand;
        run;

    /* MRI Volume data at baseline and 1 year */
    /* HIPP_VOL: N = 304 | Var = 7 */
    proc sql;
        create table hipp_volume as
        select idnum, datepart(doscan) format = MMDDYY10. as doscan, MRItypeMain, MRItypeSecond, MRItypeThird, right_vol, left_vol
        from hipp_vol.all_volumes_merged_t1_t2
        where idnum contains "P" and idnum ne "2P038" and (mritypemain in (1, 2, 20) | mritypesecond in (1, 2, 20) | mritypethird in (1, 2, 20))
        order by idnum, doscan;
        quit;
    
/* *Fuzzy merge* on visit codes but check times between psych visit and MRI */
    /* NEURO: N = 312 | Var = 30 */
    proc sql;
        create table neuro as
        select *, yrdif(datepart(phenom_demo.dob), neuro_vol.dotest, 'ACT/ACT')*12 as age_test
        from
        (select neuro_0.*, mri_0.doscan, mri_0.MRITYPEMAIN, mri_0.MRITYPESECOND, mri_0.MRITYPETHIRD, mri_0.right_vol, mri_0.left_vol, 
                    datdif(neuro_0.dotest, mri_0.doscan, 'ACT/ACT') as neuro_mri_time
        from 
            (neuropsych_only(where = (visitcode1 = 20 | visitcode2 = 20 | visitcode3 = 20)) as neuro_0
             LEFT JOIN
             hipp_volume(where = (mritypemain in (1, 20) | mritypesecond in (1, 20) | mritypethird in (1, 20))) as mri_0
             on neuro_0.idnum = mri_0.idnum)
         OUTER UNION CORRESPONDING
         select neuro_1.*, mri_1.doscan, mri_1.MRITYPEMAIN, mri_1.MRITYPESECOND, mri_1.MRITYPETHIRD, mri_1.right_vol, mri_1.left_vol, 
                    datdif(neuro_1.dotest, mri_1.doscan, 'ACT/ACT') as neuro_mri_time
         from
              (neuropsych_only(where = (visitcode1 = 2 | visitcode2 = 2 | visitcode3 = 2)) as neuro_1
               LEFT JOIN
               hipp_volume(where = (mritypemain = 2 | mritypesecond = 2 | mritypethird = 2)) as mri_1
               on neuro_1.idnum = mri_1.idnum)) as neuro_vol
        LEFT JOIN
        phenom_demo 
        on neuro_vol.idnum = phenom_demo.idnum;
        quit;

        data neuro;
            modify neuro;
            attrib doscan label = "Date of MRI";
            attrib neuro_mri_time label = "Time, in days, between Neuro and MRI exams";
            attrib durcons format = durconsfmt. label = "Duration of FSE";
            attrib typcons format = typconsfmt. label = "Continuous or Intermittent FSE";
            attrib foccons format = focconsfmt. label = "Focal Seizure";
            attrib pszcons format = pszconsfmt. label = "Prior Febrile Seizures";
            attrib pricons format = priconsfmt. label = "Prior Development";
            attrib sex format = sexfmt. label = "Sex";
            attrib race_eth format = race_ethfmt. label = "Race / Ethnicity";
            attrib age_test label = "Age at time of neuro exam";
            run;

    
        /* **CCL 07/29/2013: there are 9 subs with MRI/Neuro exams more than 6 mo apart and 2 with MRI/Neuro exams more than 1 year apart. */
        proc sql number;
            title "More than 6 mo between Neuropsych visit and MRI";
            select idnum, visitcode1, mritypemain, dotest format = MMDDYY10., doscan format = MMDDYY10., abs(neuro_mri_time) as time_diff
            from neuro
            where abs(neuro_mri_time) > 180;
            quit;

/* ************************************************************************************************************************ */
/* ************************************************************************************************************************ */
/* **CCL 07/29/2013: save out NEURO dataset */
data finaldat.neuro(label = "NEURO: N=312; Var=312 | Last saved out %date by CCL");
    set neuro;
    run;



/*** PSYCHOMETRIC DATA SET -- double scored;*/
data one ;
length idnum $ 5;
set redc.neuropsych_redcap_mar3012_modify (rename = (dob = dobpsych subject_id = idnum ));
	where idnum contains 'P' and idnum ne '2P038';
	idnum=substr(idnum,1,5);
	informat idnum $5.;
	format idnum $5.;
	dot = put( dotest, best10.) + 0; 
run;


/**I'm taking the 1 mo for all subjects -- even those with Recurrent SE;*/
/** BRINGING IN TCR01 ** formatted version;*/
data two;
	set fmtdat.tcr01;
	where idnum contains 'P' and idnum ne "2P038" and sznum = 1 ;
	run;

/*** T1H01;*/
data three;
	set fmtdat.t1h01;
	where idnum contains 'P' and idnum ne '2P038';
	run;

/*** DATA PROBLEMS;*/
/*	** subject 3P016 has a mix up in his date of 1mo visit -- actual date of visit is Nov 14 2006 sas date: ;*/
/*	** subject 1P037 has a duplicate visitcode1 = 20 -- mabye 1 month after recurrent or miscoded;*/

/*** merging using proc sql -- keeping only observations for 1 mo visit (visitcode1 = 20);*/
/*** VARIABLES TO KEEP:*/
/*psychometrics (dataset = ONE)*/
    /*bayley_motor_adj */
    /*bayley_mental_adj*/
    /*mccarthy_memory_tscore*/
    /*ppvt_stand*/
    /*vineland_comm_stand*/
    /*vineland_dl_stand*/
    /*vineland_social_stand*/
    /*vineland_motor_stand*/
    /*abc_comp*/

/*TCR01 (dataset = TWO)*/
    /*agemo*/
    /*durlong*/
    /*contin*/
    /*focal*/
    /*pszcons*/
    /*devel*/

/*T1H01 (dataset = THREE)*/
    /*sex*/
    /*race_eth*/


proc sql;
	create table neuro as
	select 	count(distinct a.idnum),
			a.bayley_motor_adj as bayleyMotor, a.bayley_mental_adj as bayleyMental, a.mccarthy_memory_tscore as McCarthy, a.ppvt_stand as ppvt, a.vineland_comm_stand,
			a.vineland_dl_stand, a.vineland_social_stand, a.vineland_motor_stand, a.abc_comp, a.visitcode1, a.dotest,
			b.idnum, b.agemon, b.durlong, b.contin, b.focal, b.pszcons, b.devel, b.sznum,
			c.sex, c.race_eth, c.datese  
	from one as a, two as b, three as c
	where a.idnum = b.idnum and a.idnum = c.idnum and b.sznum = 1 and a.visitcode1 = 20
	order by idnum;
quit;
	
proc sort data = fmtdat.tcr03(keep = idnum mritypemain impcons ) out=tcr03;
	by idnum;
	where mritypemain = 1;
	run;

/*** so the analysis consisted of ttests all of the scores over the demographic variables;*/
/*	** making the table was an absolute nightmare, so try and program SAS to do it.;*/

*this macro outputs the three datasets needed to make each factors / tests little dataset;
******************************************************************************;
*************************** MACRO HEADER *************************************;
*
* Macro: %OUTDAT(factor=,flab=,testvar=, dataname=);
*
* Parameters        :
*   FACTOR -     	variable name of the dichotomous variable you want the values of &testvar tested                                              
*   FLAB -          short name (label) of the factor variable (pronounced "F - lab" not "flab")
*   TESTVAR - 		variable name of the numeric data you want tested over levels of &factor             
*	DATANAME -		name of dataset to be used 
*   
* Macro Output		:
*	3 datasets named t_&flab s_&flab and f_&flab
*
* Macro Dependency: (List those macros needed to be called prior to this macro)  
* 
* Example call      :                                                                          
* %OUTDAT(FACTOR=sex,FLAB=gender,TESTVAR=bayley_motor_adj,DATANAME=neuro);
****************************************************************************;

%MACRO OUTDAT(factor=,flab=,testvar=,dataname=);
	ods listing close;
	ods output "T-Tests"=t_&flab._&testvar "Statistics"=s_&flab._&testvar "Equality of Variances"=f_&flab._&testvar;
		proc ttest data = &dataname;
			title "ttest of &testvar by &flab";
				var &testvar;
				class &factor;
				where &testvar > 0 ;
		run;
	ods output close;
	ods listing;
%MEND OUTDAT;


%OUTDAT(FACTOR=sex,FLAB=gender,TESTVAR=BayleyMotor,DATANAME=neuro);

** this is the macro to make the little datasets with just what we need;
******************************************************************************;
*************************** MACRO HEADER *************************************;
*
* Macro: %FTABLE(flab=,fvar=);
*
* Parameters        :
*   FLAB -          short name (label) of the factor variable (pronounced "F - lab" not "flab")
*						** note: MUST BE THE SAME AS IN %OUTDAT
*   FVAR - 			name of new dataset created that has just the levels, n, averages and p-value from the ttest  
*	TESTVAR - 		name of variable being tested MUST BE THE SAME AS TESTVAR IN %OUTDAT
*   
* Macro Output		:
*	1 dataset named &FVAR_&TESTVAR
*
* Macro Dependency: (List those macros needed to be called prior to this macro)  
*	%OUTDAT() 
* 
* Example call      :                                                                          
* %FTABLE(FLAB=sex,fvar=ttestsex,testvar=bayley_motor_adj);
****************************************************************************;

%MACRO ftable(flab=,fvar=,testvar=);
	proc sql;
		create table &fvar._&testvar as
		select 	s.class as factor length = 20, s.n as number_&testvar, s.mean as &testvar,
				t.probt as probt_&testvar format = 8.4, t.variances,
				f.probf
		from s_&flab._&testvar as s, t_&flab._&testvar as t, f_&flab._&testvar as f
		where s.n > 0 and (f.probf > 0.05 and t.variances = 'Equal') or (f.probf < 0.05 and t.variances = 'Unequal');
	quit;	

	data &fvar._&testvar;
		set &fvar._&testvar;
			factname = vlabel(factor);
			if number_&testvar < 0 then delete;
		run;
%MEND ftable;

*%FTABLE(flab=gender,fvar=sex,testvar=BayleyMotor);

/* FACTLIST = list of factors: variable name of factor*/
/*LABLIST = list of labels for factor variables*/
/*VARLIST = list of labels for output datasets*/
/*TESTLIST = list of outcome measures to be compared over factors*/;

 %LET factlist = sex agemon durlong contin focal pszcons devel;
 %LET lablist = sex agemon durlong contin focal pszcons devel;
 %LET varlist = sex agemon durlong contin focal pszcons devel;
 %LET testlist = BayleyMotor BayleyMental McCarthy PPVT;

%MACRO RUNMACS;
  %LOCAL i j;
	%LET j=1;
		%DO %UNTIL(NOT %LENGTH(%SCAN(&testlist,&j)));
			%LET i=1;
			%DO %UNTIL(NOT %LENGTH(%SCAN(&varlist,&i)));
				%OUTDAT(FACTOR=%SCAN(&factlist,&i), FLAB=%SCAN(&lablist,&i), TESTVAR=%SCAN(&testlist,&j), DATANAME=neuro); 
				%FTABLE(FLAB=%SCAN(&lablist,&i),FVAR=%SCAN(&varlist,&i),TESTVAR=%SCAN(&testlist,&j));
				%LET i=%EVAL(&i+1);
			%END;
			%LET j=%EVAL(&j+1);
		%END;
%MEND RUNMACS;

%RUNMACS;

** next, append all the datasets together?; *make sure you leave out whichever factor you're going to use for the base dataset;
%LET factAppList = agemon durlong contin focal pszcons devel;

%MACRO SetAppend(testvar=,basefact=);

	data base_&testvar;
	set &basefact._&testvar(drop = Variances Probf);
	run;

	%LET i=1;
		%DO %UNTIL(NOT %LENGTH(%SCAN(&factAppList,&i)));
			%LET appSet = %SCAN(&factAppList,&i);
			proc append base = base_&testvar data = &appSet._&testvar(drop = Variances Probf) FORCE;
				run;
			%LET i = %EVAL(&i+1);
		%END;
%MEND SetAppend;


%SETAPPEND(testvar=BayleyMotor,basefact=sex);
%SETAPPEND(testvar=BayleyMental,basefact=sex);
%SETAPPEND(testvar=McCarthy,basefact=sex);
%SETAPPEND(testvar=ppvt,basefact=sex);

*just saving the 4 sets I need;
proc datasets library = work;
	save base_bayleyMotor base_BayleyMental base_McCarthy base_ppvt neuro;
	quit;
	run;

proc sql;
create table neuroFactors as
		select 	a.*, b.*, c.*, d.*
		from base_bayleyMental as a, base_bayleyMotor as b, base_mccarthy as c, base_ppvt as d
		where a.factor = b.factor and b.factor = c.factor and c.factor = d.factor;
	quit;	
	
data neurofactors_rpt;
length factname $40;
	set neurofactors;
run;

/*** so make all the tables, merge them together and output with proc report and ta-da!  it will be amazing;*/
/*** now its just a matter of an EPIC proc report and viola!;*/

ods listing close;
ods pdf style = journal file="\\10.115.15.133\cdc\Claire\Cognitive\Final Programs Data Output\Cognitive Results.PDF";

proc report data = neuroFactors_rpt nowd ;
	title "Cognitive Scores by Factor";
	column factor factName number_bayleyMental probt_bayleyMental number_bayleyMotor probt_BayleyMotor number_McCarthy probt_mccarthy
			number_ppvt probt_ppvt;
	define factName /order order = formatted;
	define factor / display order = formatted;

	define number_bayleyMental / display;
	define probt_bayleyMental / display;
	define number_bayleyMotor / display;
	define probt_bayleyMotor / display;
	define number_mccarthy / display;
	define probt_maccarthy / display;
	define number_ppvt / display;
	define probt_ppvt / display;

	run;
ods pdf close;
ods listing;


/* ************************************************************************************************************************ */
/* ** END OF PROGRAM ** */
    /* ** CCL 07/10/2013 ** */
