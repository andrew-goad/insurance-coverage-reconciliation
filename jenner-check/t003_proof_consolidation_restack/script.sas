/* Metadata-Driven Restack — adapted from the coverage_date_ranges macro
   in src/policy_coverage_reconciliation.sas. Reads the transposed
   coverage_start#/coverage_end# column names from dictionary.columns into
   macro-variable lists, then loops to un-transpose each window into a
   normalized (coverage_start, coverage_end) row table. This is the
   dictionary.columns / dynamic-loop technique highlighted in the README. */

/* Place each coverage_start#/coverage_end# variable name into a macro var. */
proc sql;
    select distinct name into :s1-:s9999 from dictionary.columns where libname='WORK' and memname='COVERAGE_START_DATES' and
         UPCASE(name) ne "ID" and UPCASE(name) ne "POLICY_START" and UPCASE(name) ne "POLICY_END";
    select distinct name into :e1-:e9999 from dictionary.columns where libname='WORK' and memname='COVERAGE_END_DATES' and
         UPCASE(name) ne "ID" and UPCASE(name) ne "POLICY_START" and UPCASE(name) ne "POLICY_END";
quit;

%macro restack;
    /* Loop through each coverage window: rename coverage_start#/coverage_end#
       to coverage_start/coverage_end, drop the windows merged away to null. */
    %do j = 1 %to &sqlobs;
        %let varkeep&j = &&s&j &&e&j rename= (&&s&j = coverage_start &&e&j = coverage_end);

        data coverage_date_ranges&j (where= (missing(coverage_start) ne 1));
            set coverage_date_ranges (keep= id policy_start policy_end &&varkeep&j);
            label coverage_start = "coverage_start";
            label coverage_end   = "coverage_end";
        run;

        proc print data=coverage_date_ranges&j;
            format coverage_start coverage_end yymmdd10.;
            title "Restacked coverage window &j";
        run;
    %end;
%mend restack;
%restack;
