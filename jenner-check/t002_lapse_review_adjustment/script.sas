/* Lapse Review & Adjustment Factor (OBJ 1.2) — adapted from the
   lapse_review macro in src/policy_coverage_reconciliation.sas.
   Compares each consolidated proof window against the bank-issued
   policy window, applies the configurable lapse threshold, and produces
   the key adjustment factor coverage_days_pct (percentage owed back). */

%let lapse_threshold = 30;

/* Initial review — narrow scope to coverage windows that create a
   policy-days adjustment. (verbatim five-case window comparison) */
data initial_policy_days_adjustment (where= (initial_policy_days_adjustment ne 0));
    set coverage_date_ranges_final;

    /*1) No policy adjustment if coverage began after policy end or ended before policy start*/
    if coverage_start ge policy_end or coverage_end le policy_start then do;
        initial_policy_days_adjustment = 0;
    end;
    /*2) Full adjustment if coverage began on/before policy start + threshold AND ended on/after policy end*/
    else if coverage_start le (policy_start + &lapse_threshold) and coverage_end ge policy_end then do;
         initial_policy_days_adjustment = (policy_end - policy_start);
    end;
    /*3) Partial if coverage began on/before policy start and ended prior to policy end*/
    else if coverage_start le policy_start and coverage_end < policy_end then do;
         initial_policy_days_adjustment = (coverage_end - policy_start);
    end;
    /*4) Partial if coverage began after policy start, before policy end, ended on/after policy end*/
    else if coverage_start > policy_start and coverage_start le policy_end and coverage_end ge policy_end then do;
         initial_policy_days_adjustment = policy_end - coverage_start;
    end;
    /*5) Partial if coverage began after policy start and ended prior to policy end*/
    else if coverage_start > policy_start and coverage_end < policy_end then do;
         initial_policy_days_adjustment = coverage_end - coverage_start;
    end;
    if initial_policy_days_adjustment ne 0 then num_cov = 1;
run;

/* Border lapses on first/last id records, forgiven within the threshold. */
data lapse_start (keep= id lapse_start where= (missing(lapse_start) ne 1))
     lapse_end   (keep= id lapse_end   where= (missing(lapse_end)   ne 1));
     set initial_policy_days_adjustment;
     by id;
     if first.id then lapse_start = coverage_start - policy_start;
     if lapse_start le &lapse_threshold and missing(lapse_start) ne 1 then lapse_start = 0;
     if last.id then lapse_end = policy_end - coverage_end;
     if lapse_end le &lapse_threshold and missing(lapse_end) ne 1 then lapse_end = 0;
run;

data initial_policy_days_adjustment;
    merge initial_policy_days_adjustment lapse_start lapse_end;
    by id;
run;

/* Final OBJ 1.2 calculations — responsible_days, coverage_days, and the
   percentage factors. (verbatim adjustment-factor formulas) */
data coverage_adjustment_final;
    set initial_policy_days_adjustment;

    responsible_days = SUM(of lapse:, lapse_start, lapse_end);
    coverage_days = (policy_end - policy_start) - responsible_days;

    format coverage_days_pct responsible_days_pct percent10.2;
    coverage_days_pct    = coverage_days / (coverage_days + responsible_days);
    responsible_days_pct = responsible_days / (coverage_days + responsible_days);
run;

proc print data=coverage_adjustment_final;
    var id coverage_days responsible_days coverage_days_pct responsible_days_pct;
    title "Coverage Adjustment Factors (coverage_days_pct = % owed back to customer)";
run;
