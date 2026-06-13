options obs=100;

/* Synthetic work.intake — proof-of-coverage windows per account.
   Mirrors the conceptual schema documented in the project README:
   id, policy_start, policy_end, coverage_start, coverage_end.
   Includes overlapping and contiguous proof windows to exercise the merge. */
data intake;
  informat policy_start policy_end coverage_start coverage_end yymmdd10.;
  format    policy_start policy_end coverage_start coverage_end yymmdd10.;
  input id $ policy_start policy_end coverage_start coverage_end;
  datalines;
A101 2023-01-01 2023-12-31 2023-01-20 2023-04-30
A101 2023-01-01 2023-12-31 2023-04-20 2023-08-15
A101 2023-01-01 2023-12-31 2023-10-01 2023-12-20
B202 2023-01-01 2023-12-31 2023-02-01 2023-06-30
B202 2023-01-01 2023-12-31 2023-06-15 2023-12-15
;
run;

%let nvar_dummy = ;
