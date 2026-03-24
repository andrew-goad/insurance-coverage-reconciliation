/************************************************************************************
   CONTACT INFORMATION:
   Name: Andrew R. Goad
   LinkedIn: linkedin.com/in/andrewrgoad
   Email: ar.goad@yahoo.com
   
   BACKGROUND: Determine bank issued policy adjustment following Customer 
               provided proof of coverage.
               -> Within work.coverage_adjustment_final, variable coverage_days_pct 
               represents the percentage factor owed back to the customer.
               
   VARIABLE: coverage_days_pct represents the percentage factor owed back 
             to the customer.
************************************************************************************/

/* OBJECTIVES: 
        Starting Population: work.intake includes id column, bank issued policy start/end dates, 
        and N number of proof of coverage dates
        OBJ 1.1) Merge overlapping coverage dates.
        OBJ 1.2) Compare coverage against bank issued policy.
             ->Customer Centric Approach: Lapses < X days (macro &lapse_threshold) will be considered covered.
   Customer is only responsible for lapses greater or equal to X days.*/

%let lapse_threshold = ; 

/*OBJ 1.1) Merge overlapping coverage dates.*/

/*Sort work.intake by id, bank issued policy start/end, and coverage dates. 
  Select distinct id, policy start/end, and coverage dates*/
proc sort data=intake nodupkey;
    by id policy_start policy_end coverage_start coverage_end;
run;

/*Transpose coverage dates
  work.coverage_start_dates has id, policy_start, policy_end, and many coverage_start# variables 
  with the earliest date in coverage_start1*/
proc transpose data=intake out=coverage_start_dates (drop=_NAME_) prefix=coverage_start;
    by id policy_start policy_end;
    var coverage_start;
run;

/*work.coverage_end_dates has id, policy_start, policy_end, and many coverage_end# variables 
  with the earliest date in coverage_end1*/
proc transpose data=intake out=coverage_end_dates (drop=_NAME_) prefix=coverage_end;
    by id policy_start policy_end;
    var coverage_end;
run;

/*Identify number of coverage date columns. The only other variables in our WORK.coverage_start_dates 
  dataset are id and policy_start/policy_end.
  Subtract by 3 (i.e. subtract the id and policy_start/policy_end columns) to get number of
  coverage date columns*/
proc sql;
    select nvar-3 into :nvar from dictionary.tables where libname='WORK' and memname='COVERAGE_START_DATES';
quit;

/*== The purpose of coverage_date_ranges is to merge overlapping coverage dates. ==*/
%macro coverage_date_ranges;
    /*If more than one set of coverage date ranges exist, then proceed with merging overlapping coverage dates*/
    %if &nvar > 1 %then %do;
        data coverage_date_ranges;
            merge coverage_start_dates coverage_end_dates;
            by id policy_start policy_end;

            /*Create two nested do Loops. Eval condition will only trigger logic when the difference between the do Loop is 1.
              Using this we can compare each subsequent coverage date range (i Loop) against the prior coverage date range (h Loop).
              Recall above that we have our data sorted by id policy start policy_end coverage start coverage_end.*/
            %do h=1 %to &nvar;
                %do i=2 %to &nvar;
                    %if %eval(&i - &h) = 1 %then %do;
                        /*if there are coverage dates to compare, proceed*/
                        if missing(coverage_start&i) ne 1 and missing(coverage_start&h) ne 1 then do;
                            /*If the subsequent coverage start date minus one day is less than or equal to the prior coverage end date
                              then persist the prior coverage start date value in the subsequent start date.
                              Accomplish this by setting subsequent coverage start date equal to prior coverage start date AND
                              setting prior coverage start date equal to null AND
                              adjusting coverage end date SEE BELOW*/
                            if (coverage_start&i - 1) le coverage_end&h then do;
                                coverage_start&i = coverage_start&h * 1;
                                coverage_start&h = coverage_start&h * .; 

                                /*Adjust coverage end date: Set subsequent coverage end date equal to the Later of the two coverage end dates
                                  Set prior coverage end date equal to null*/
                                if (coverage_end&i) lt coverage_end&h then do;
                                    coverage_end&i = coverage_end&h * 1;
                                    coverage_end&h = coverage_end&h * .;
                                end;
                                else do coverage_end&h = coverage_end&h * .;
                                end;
                            end;
                        end; 
                    %end;
                %end;
            %end;
        run;
    %end;
    /*if only one pair of coverage date ranges exist, no need to merge overlapping coverage ranges.*/
    %else %do;
        data coverage_date_ranges;
            merge coverage_start_dates coverage_end_dates;
            by id policy_start policy_end;
        run;
    %end;

    /*Place each coverage start# and coverage_end# variable name in a separate macro variable.*/
    proc sql;
        select distinct name into :s1-:s9999 from dictionary.columns where libname='WORK' and memname='COVERAGE_START_DATES' and 
             UPCASE(name) ne "ID" and UPCASE(name) ne "POLICY_START" and UPCASE(name) ne "POLICY_END";
        select distinct name into :e1-:e9999 from dictionary.columns where libname='WORK' and memname='COVERAGE_END_DATES' and 
             UPCASE(name) ne "ID" and UPCASE(name) ne "POLICY_START" and UPCASE(name) ne "POLICY_END";
    quit;

    /*Re-stock coverage date range table removing transposing:
      1) Loop through each set of coverage start and end dates.
      2) Rename coverage_start# and coverage_end# drop the # suffix
      3) Drop the coverage date ranges we set to null above during the merger of overlapping coverage.*/
    %do j = 1 %to &sqlobs; /*&sqlobs represents the number of coverage date columns.*/
        %let varkeep&j = &&s&j &&e&j rename= (&&s&j = coverage_start &&e&j = coverage_end);

        data coverage_date_ranges&j (where= (missing(coverage_start) ne 1));
            set coverage_date_ranges (keep= id policy_start policy_end &&varkeep&j);
            label coverage_start = "coverage_start";
            label coverage_end = "coverage_end";
        run;
    %end;

    data coverage_date_ranges_final;
        set coverage_range1-coverage_range&sqlobs;
        by id policy_start policy_end coverage_start coverage_end;
    run;
%mend coverage_date_ranges;
%coverage_date_ranges;

/*OBJ 1.2) Compare coverage against bank issued policy.
  ->Customer Centric Approach: Lapses < X days (macro &lapse_threshold) will be considered covered.*/
%macro lapse_review;
    /*Initial review to determine whether policy adjustments from the provided coverage dates.
      NOTE: final calculations are below. this initial step simply narrows the scope to cases with
      policy adjustments due.
      NOTE 2: Recall the dataset is stacked, so these calculations are done at the id / coverage date range Level*/
    data initial_policy_days_adjustment (where= (initial_policy_days_adjustment ne 0));
        set coverage_date_ranges_final;
        
        /*1) No policy adjustment if provided coverage began after policy end or ended before policy start*/
        if coverage_start ge policy_end or coverage_end le policy_start then do;
            initial_policy_days_adjustment = 0;
        end;
        /*2) Full policy adjustment if provided coverage began on or before policy start + Lapse threshold AND
             coverage ended on or after policy end*/
        else if coverage_start le (policy_start + &lapse_threshold) and coverage_end ge policy_end then do;
             initial_policy_days_adjustment = (policy_end - policy_start);
        end;
        /*3) Partial policy adjustment if coverage began on or before policy start and ended prior to policy end*/
        else if coverage_start le policy_start and coverage_end < policy_end then do;
             initial_policy_days_adjustment = (coverage_end - policy_start);
        end;
        /*4) Partial policy adjustment if coverage began after policy start, before policy end, and ended on or after policy end.*/
        else if coverage_start > policy_start and coverage_start le policy_end and coverage_end ge policy_end then do;
             initial_policy_days_adjustment = policy_end - coverage_start;
        end;
        /*5) Partial policy adjustment if coverage began after policy start and ended prior to policy end*/
        else if coverage_start > policy_start and coverage_end < policy_end then do;
             initial_policy_days_adjustment = coverage_end - coverage_start;
        end;
        /*Flag records with a policy days adjustment*/
        if initial_policy_days_adjustment ne 0 then num_cov = 1;
    run;

    /*For all accounts with due a policy days adjustment,
      begin by reviewing coverage Lapses on the borders (i.e. first and Last id records).
      This makes sense because it is the only time you are comparing against policy_start and policy_end.
      Subsequent Logic will then compare all mid points (i.e. coverage dates against coverage dates)*/
    data lapse_start (keep= id lapse_start where= (missing(lapse_start) ne 1))
         lapse_end (keep= id lapse_end where= (missing(lapse_end) ne 1));
         set initial_policy_days_adjustment;
         by id;
         /*If the first record for an id, then initialize Lapse_start (# of days after policy start that coverage began)*/
         if first.id then lapse_start = coverage_start - policy_start;
         /*If Lapse_start is within the Lapse threshold then set to 0*/
         if lapse_start le &lapse_threshold and missing(lapse_start) ne 1 then lapse_start = 0;
         /*If the Last record for an id, then initialize Lapse_end (# of days prior to policy end that coverage concluded)*/
         if last.id then lapse_end = policy_end - coverage_end;
         /*If Lapse_end is within the Lapse threshold then set to 0*/
         if lapse_end le &lapse_threshold and missing(lapse_end) ne 1 then lapse_end = 0;
    run;

    /*Join Lapse start/end information to the initial_policy_days_adjustments dataset*/
    data initial_policy_days_adjustment;
        merge initial_policy_days_adjustment lapse_start lapse_end;
        by id;
    run;

    /*Sort data prior to transposing Coverage_Start/Coverage_End*/
    proc sort data=initial_policy_days_adjustment;
        by id policy_start policy_end lapse_start lapse_end coverage_start coverage_end;
    run;

    /*== Transposing the overlap merge adjusted Coverage_Start/Coverage_End from coverage_date_ranges macro ==*/
    proc transpose data= initial_policy_days_adjustment out=coverage_start_lapse_review (drop= _name_ _label_) prefix=coverage_start;
        by id policy_start policy_end lapse_start lapse_end;
        var coverage_start;
    run;
    proc transpose data= initial_policy_days_adjustment out=coverage_end_lapse_review (drop= _name_ _label_) prefix=coverage_end;
        by id policy_start policy_end lapse_start lapse_end;
        var coverage_end;
    run;

    /*== Sum "num cov", which is the number of provided coverage dates that had an initial policy days adjustment
         between policy_start and policy_end ==*/
    proc means data= initial_policy_days_adjustment noprint;
        by id policy_start policy_end lapse_start lapse_end;
        var num_cov;
        output out=num_cov (keep= id policy_start policy_end lapse_start lapse_end num_cov) sum=;
    run;

    /*== Number of Coverage Start Date columns now that we've narrowed scope to coverage dates that had an initial policy days adjustment.
         Subtract 5 due to five non coverage start date columns (id, policy start, policy_end, Lapse start, and Lapse_end). ==*/
    proc sql;
        select nvar-5 into :nvar from dictionary.tables where libname='WORK' and memname='COVERAGE_START_LAPSE_REVIEW';
    quit;

    /*Review Coverage Lapses between coverage dates (i.e. start/end Lapse reviewed above).
      Calculate the Lapses between coverage_end of 1st policy and coverage_start of 2nd policy*/
    data coverage_adjustment_final;
        merge num_cov coverage_start_lapse_review coverage_end_lapse_review;
        by id policy_start policy_end lapse_start lapse_end;
        
        /*If more than one set provided coverage dates that had a policy days adjustment 
          between policy_start and policy_end, then do*/
        if num_cov > 1 then do;
            /*similar to above, use nested do Loops, %eval function to compare coverage date Lapses*/
            %do h=1 %to &nvar;
                %do i=2 %to &nvar;
                    %if %eval(&i - &h) = 1 %then %do;
                        /*if not missing two sets of dates, then perform Lapse calculation.
                          subtract prior coverage end date from subsequent coverage start date.
                          subtract 1 to avoid counting the subsequent coverage start date as part of the Lapse.
                          if that math is <= &lapse_threshold, then consider lapse = 0*/
                        if missing(coverage_start&i) ne 1 and missing(coverage_end&h) ne 1 then do;
                            lapse&h = coverage_start&i - coverage_end&h - 1;
                            if lapse&h le &lapse_threshold then lapse&h = 0;
                        end;
                        /*if missing one or both sets of coverage dates, then there is no Lapse*/
                        else lapse&h = .;
                    %end;
                %end;
            %end;
        end;
        
        /*Final OBJ 1.2 Calculations
          Responsible_Days: Sum of remaining Lapse in coverage. This represents the number of days that the bank issued policy
          is still valid.
          Coverage_Days: Difference between original bank issued policy and the remaining Lapse in coverage.
          This represents the portion of the bank issued policy due back to the customer (in days).
          Percentages created to assist financial remediation Logic.*/
        responsible_days = SUM(of lapse:, lapse_start, lapse_end);
        coverage_days = (policy_end - policy_start) - responsible_days;

        format coverage_days_pct responsible_days_pct percent10.2;
        coverage_days_pct = coverage_days / (coverage_days + responsible_days);
        responsible_days_pct = responsible_days / (coverage_days + responsible_days);
    run;
%mend lapse_review;
%lapse_review;
