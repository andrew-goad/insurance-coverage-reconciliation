/* Coverage Overlap Merge (OBJ 1.1) — adapted from
   src/policy_coverage_reconciliation.sas, the coverage_date_ranges engine.
   Sorts and transposes proof-of-coverage windows, then collapses
   overlapping/contiguous windows via nested macro loops. */

%let lapse_threshold = 30;

proc sort data=intake nodupkey;
    by id policy_start policy_end coverage_start coverage_end;
run;

proc transpose data=intake out=coverage_start_dates (drop=_NAME_) prefix=coverage_start;
    by id policy_start policy_end;
    var coverage_start;
run;

proc transpose data=intake out=coverage_end_dates (drop=_NAME_) prefix=coverage_end;
    by id policy_start policy_end;
    var coverage_end;
run;

proc sql;
    select nvar-3 into :nvar from dictionary.tables where libname='WORK' and memname='COVERAGE_START_DATES';
quit;

%macro coverage_date_ranges;
    %if &nvar > 1 %then %do;
        data coverage_date_ranges;
            merge coverage_start_dates coverage_end_dates;
            by id policy_start policy_end;
            %do h=1 %to &nvar;
                %do i=2 %to &nvar;
                    %if %eval(&i - &h) = 1 %then %do;
                        if missing(coverage_start&i) ne 1 and missing(coverage_start&h) ne 1 then do;
                            if (coverage_start&i - 1) le coverage_end&h then do;
                                coverage_start&i = coverage_start&h * 1;
                                coverage_start&h = coverage_start&h * .;
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
    %else %do;
        data coverage_date_ranges;
            merge coverage_start_dates coverage_end_dates;
            by id policy_start policy_end;
        run;
    %end;
%mend coverage_date_ranges;
%coverage_date_ranges;

proc print data=coverage_date_ranges;
    format coverage_start1-coverage_start3 coverage_end1-coverage_end3 yymmdd10.;
    title "Consolidated Coverage Date Ranges (overlap merge)";
run;
