options obs=100;

/* Synthetic consolidated proof window per account — the output shape of
   the engine's coverage_date_ranges_final table (one merged window per id).
   Conceptual schema per the README: id, policy_start, policy_end,
   coverage_start, coverage_end. */
data coverage_date_ranges_final;
  informat policy_start policy_end coverage_start coverage_end yymmdd10.;
  format    policy_start policy_end coverage_start coverage_end yymmdd10.;
  input id $ policy_start policy_end coverage_start coverage_end;
  datalines;
A101 2023-01-01 2023-12-31 2023-01-20 2023-12-20
B202 2023-01-01 2023-12-31 2023-02-15 2023-11-30
C303 2023-01-01 2023-12-31 2023-04-01 2023-09-30
;
run;
