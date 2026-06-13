options obs=100;

/* Synthetic transposed coverage tables — the output shape of the engine's
   PROC TRANSPOSE step: id + policy window + many coverage_start#/coverage_end#
   columns. Drives the metadata-driven restack via dictionary.columns. */
data coverage_start_dates;
  informat policy_start policy_end coverage_start1 coverage_start2 coverage_start3 yymmdd10.;
  format    policy_start policy_end coverage_start1 coverage_start2 coverage_start3 yymmdd10.;
  input id $ policy_start policy_end coverage_start1 coverage_start2 coverage_start3;
  datalines;
A101 2023-01-01 2023-12-31 2023-01-20 2023-04-20 2023-10-01
B202 2023-01-01 2023-12-31 2023-02-01 2023-06-15 .
;
run;

data coverage_end_dates;
  informat policy_start policy_end coverage_end1 coverage_end2 coverage_end3 yymmdd10.;
  format    policy_start policy_end coverage_end1 coverage_end2 coverage_end3 yymmdd10.;
  input id $ policy_start policy_end coverage_end1 coverage_end2 coverage_end3;
  datalines;
A101 2023-01-01 2023-12-31 2023-04-30 2023-08-15 2023-12-20
B202 2023-01-01 2023-12-31 2023-06-30 2023-12-15 .
;
run;

data coverage_date_ranges;
  merge coverage_start_dates coverage_end_dates;
  by id policy_start policy_end;
run;
