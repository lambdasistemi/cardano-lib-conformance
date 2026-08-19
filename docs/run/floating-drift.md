# Floating drift mode

Pinned mode answers "does the documented claim still match its evidence
pin?". Floating mode answers "does current upstream still have the same
capability shape?" — the same gate runs with one or more inputs overridden
to their moving branch or current release.

The exact `--override-input` invocations, including the npm surfaces whose
version must be resolved first, are listed in
[the domain README](../balance-fixpoint/README.md#floating-drift-mode).

Floating red is review evidence, not automatically an upstream regression.
A missing required string may mean an API moved or was renamed, and a red
absence check says the previously missing capability may now exist: inspect
upstream and update the skill and matrix instead of weakening the check.

## Scheduled drift run

`.github/workflows/fixpoint-evidence-drift` runs the full floating
invocation monthly (`17 6 1 * *`) and on `workflow_dispatch`. It resolves
the current `@evolution-sdk/evolution` and `@meshsdk/core` versions, runs
`nix flake check` with every input overridden, and on failure opens — or
comments on — an open issue titled "Fixpoint evidence drift detected" with
the full log attached.
