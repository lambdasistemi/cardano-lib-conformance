<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Modified principles: Change Workflow (cell flips now require the proving
  check and gap-matrix page update in the same PR)
- Added sections: Principle IX, Record Primacy
- Removed sections: none
- Templates requiring updates:
  - ⚠ .specify/templates/plan-template.md — absent; this repository has no
    Spec Kit templates installed, so no Constitution Check block exists yet
  - ⚠ .specify/templates/spec-template.md — absent
  - ⚠ .specify/templates/tasks-template.md — absent
  - ✅ docs/constitution.md — includes this canonical file verbatim
  - ✅ README.md — already states the gate and domain model this codifies
- Follow-up TODOs: none
-->

# Cardano Library Conformance Constitution

## Core Principles

### I. Falsification Before Trust (NON-NEGOTIABLE)

Every check MUST be shown able to fail before it is trusted. Each check is
exposed as an app accepting `FALSIFY=1`, which mutates a required
expectation into one that cannot be satisfied; the check MUST be observed
failing under that mutation and passing again without it, and the
observation MUST be journalled. A check that has never been seen red is not
evidence, whatever colour it currently reports.

### II. Frozen Evidence Is Immutable

Raw probe handoffs, gap matrices, and audit reports under `static/` are
preserved byte-for-byte. They MUST NOT be edited, reformatted, corrected,
or regenerated. New understanding is added by wrapping: a new file, a new
page, a new check that supersedes the reading. The record of what was
observed, and when, survives the conclusions drawn from it.

### III. Pinned Claims, Explicit Unknowns

Every claim MUST name the version or commit it was established against, and
`flake.lock` MUST fix that source and its content hash. What was not probed
is stated as `NOT-PROBED`, and a surface whose evidence cannot support an
executable check is marked static-only with the reason given. Absence of
evidence MUST NOT be presented as verified capability, and a limitation is
recorded as a limitation rather than omitted.

### IV. Ledger Validity, Not Byte Equality

Byte equality between libraries is an explicit non-goal. Cardano admits
legitimate encoding differences, and the minimum fee is a function of each
transaction's actual bytes. The conformance claim is that each produced
transaction independently satisfies the applicable ledger-level structural,
fee, and value rules, re-derived by independently pinned code.

### V. Two Kinds of Conformance

Interface conformance is established by pinned checks over source evidence;
behavioral conformance is established by runnable examples. Neither
substitutes for the other: a present declaration does not prove the loop
converges, and a converging example does not prove the declaration is the
documented one. A claim states which kind of evidence supports it.

### VI. The Default Gate Stays Light

`nix flake check` MUST remain runnable by any skeptic without special
infrastructure. Source-evidence checks stay cheap inspections of pinned
input store paths. Heavy closures — compilers, toolchains, runtimes, and
anything requiring a live node — live behind an explicit tier that is named
and documented, never silently attached to the default gate.

### VII. Neutrality: Capabilities, Not Rankings

The matrix classifies capability shapes — `SUPPORTED`,
`EXPRESSIBLE-WITH-EFFORT`, `NO-HOOK`, `NOT-APPLICABLE`, `NOT-PROBED` — and
MUST NOT rank, score, or recommend libraries. `NOT-APPLICABLE` is a
statement about intended scope, not a defect. A cell flips only by PR with
a check as proof; maintainers are welcome to contribute their own cells on
the same terms.

### VIII. Floating Mode Is the Drift Detector

Pinned mode answers whether the documented claim still matches its evidence
pin. Floating mode answers whether current upstream still has the same
capability shape. A failing absence check means the capability may now
exist: inspect upstream, then update the skill and the matrix. A failing
presence check means a possible breaking regression. Floating red is review
evidence, and MUST NOT be resolved by weakening the check.

### IX. Record Primacy (NON-NEGOTIABLE)

Documentation, specifications, vision, and acceptance outrank implementation,
always. Code is regenerable from a good record; the record is not regenerable
from code. Every PR MUST ship the documentation needed to explain and verify
its change in the same diff. Scope cuts land on implementation, never on the
record that defines the intended outcome and its acceptance.

## Evidence and Tiers

- One root Nix flake is the unified gate for every domain.
- Each domain owns its evidence, examples, and cross-validation, and keeps
  its claim map, falsification protocol, floating-drift commands, and known
  limits in its own README.
- Checks are exposed both as flake checks and as strict-shell apps, so any
  single claim can be run and falsified in isolation.
- Cross-validation is performed by independently pinned code, not by the
  library that produced the artifact.
- Human judgment that a source-string check cannot establish — wording,
  corpus policy, caveats, cross-artifact consistency — is preserved as
  static audit evidence and labelled as such.

## Change Workflow

- A capability claim or matrix cell flips ONLY in the same PR as the check
  that establishes it. The corresponding gap-matrix documentation page MUST
  update in that same diff; documentation and matrix cells follow the check,
  never lead it.
- New checks land with their falsification observation.
- Scheduled floating runs open or update a drift issue with the full log;
  drift is triaged as review evidence and closed by updating claims, not by
  relaxing expectations.
- Removing or weakening a check requires stating in the PR what evidence
  replaces it.

## Governance

This constitution supersedes conflicting practice in this repository. Every
PR is reviewed against it, and a deviation MUST be justified in the PR
description rather than absorbed silently.

Amendments are made by PR editing this file. Versioning is semantic:
MAJOR for removing or redefining a principle, MINOR for adding a principle
or materially expanding guidance, PATCH for clarifications and wording. The
version line below is updated in the same PR as the change it describes.

**Version**: 1.1.0 | **Ratified**: 2026-08-19 | **Last Amended**: 2026-08-20
