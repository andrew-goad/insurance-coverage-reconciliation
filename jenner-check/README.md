# Jenner compatibility bundles

This directory was added by a pull request from the
[Jenner](https://jenneranalytics.com) project. Each `tNNN_*` subdirectory
is a small, self-contained SAS bundle adapted from code in this
repository. Each one runs on Jenner — a SAS-compatible engine — and the
captured result is frozen alongside it so you can reproduce it yourself.

## What's in here

```
jenner-check/
├── README.md            # this file
├── run_jenner.sh        # runner (macOS/Linux); .bat for Windows; .sas for desktop
├── run_jenner.bat
├── run_jenner.sas
├── t001_coverage_overlap_merge/
│   ├── autoexec.sas     # options + synthetic work.intake; prepended automatically
│   ├── script.sas       # the SAS under test, adapted from src/
│   ├── expected.json    # frozen pass criteria (status, exit_code, log markers)
│   ├── expected/        # a human-readable snapshot of the captured run
│   │   ├── log.txt
│   │   ├── output.txt
│   │   └── files.md
│   └── meta.json        # provenance: source file, blob sha, commit
├── t002_lapse_review_adjustment/
└── t003_proof_consolidation_restack/
```

The bundles draw their data from small synthetic `datalines` blocks that
mirror the conceptual `work.intake` schema described in your README, so
no external library or proprietary data is required to run them.

## How to run it

From inside `jenner-check/` (macOS/Linux):

```bash
./run_jenner.sh --all          # run every bundle
./run_jenner.sh t001_coverage_overlap_merge   # run one bundle
```

The runner concatenates each bundle's `autoexec.sas` and `script.sas`,
submits them to the Jenner API, and checks the result against
`expected.json`. Windows users can run `run_jenner.bat`; on the Jenner
desktop app, `run_jenner.sas` does the same against a local engine. You
can also paste any `script.sas` into the hosted workspace at
[jenneranalytics.com](https://jenneranalytics.com).

## Optional: Jenner Compatible badge

If you'd like to show Jenner compatibility on your README, paste the
markdown below. Entirely optional — merging this PR is not a commitment
to display anything.

```markdown
[![Jenner Compatible](https://jenneranalytics.com/badges/jenner-compatible.svg)](https://jenneranalytics.com)
```

## Don't want future PRs from us?

Reply to this PR with `no-more-prs` (case-insensitive) anywhere in a
comment, or open an issue titled `jenner-check: opt out`. We'll record
your repo as do-not-contact and stop automated PRs.

## About this project

Jenner is a SAS-compatible engine. Full context is at
[jenneranalytics.com](https://jenneranalytics.com).
