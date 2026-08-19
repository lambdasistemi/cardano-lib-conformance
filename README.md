# Fixpoint evidence bundle

This bundle turns the version-pinned API claims behind the `fixpoint` skill into
31 source-evidence checks plus four worked-example checks. It also preserves the two independent audits, both gap
matrices, and all nine raw probe handoffs byte-for-byte under `static/`.

## Examples

Runnable and compile-checked caller-owned bounded balance loops for CSL,
Evolution SDK, cardano-client-lib, and Scalus are documented in
[`examples/README.md`](examples/README.md). Each is wired into `nix flake check`;
Mesh was dropped under the documented timebox priority.

## Run the pinned gate

```sh
nix flake check
```

`flake.lock` fixes every source and its content hash. The two npm releases are
fixed at `@evolution-sdk/evolution@0.5.12` and `@meshsdk/core@1.9.1`; Mesh's
`transaction` and `common` packages are independently pinned at `1.9.1` because
the relevant implementation and evaluator declarations live there.

The `tx-tools-unit` check builds the upstream pinned pure unit check, not a text
surrogate. The other checks invoke the same strict-shell programs exposed under
`apps`; they inspect their flake input store paths using `rg` and fail when a
required declaration disappears. The `*-no-candidate-hook` checks also fail with
an explicit “update the fixpoint skill” diagnostic if a currently absent hook
appears.

## Claim map

The four P rows below are the Step 4 decision rules: ordinary balance, a
fee-dependent output, candidate observation/re-entry, and a recursive
redeemer/min-UTxO value.

| Surface and pin | P1 | P2 | P3 | P4 | Establishment |
|---|---|---|---|---|---|
| Cardano Tx Tools `7bfe95b` | `tx-tools-p1-balance` + `tx-tools-unit` | `tx-tools-p2-fee-output` | `tx-tools-p3-peek` | `tx-tools-p4-recursive-redeemer` | probe evidence; independently re-derived by final external audit |
| Evolution SDK `0.5.12` | `evolution-p1-balance-phases` | `evolution-p2-fixed-output-rebuild` | `evolution-p3-evaluator-exunits-only` | `evolution-p4-indexed-redeemer-only` | probe evidence; audit corrected P3 to “candidate visible, ExUnits-only return” |
| Cardano CLI `11.0.0.0` | static matrix/`cardano-cli.txt` | static matrix/`cardano-cli.txt` | static matrix/`cardano-cli.txt` | static matrix/`cardano-cli.txt` | probe CLI help; audit corroborated auto-balance only |
| cardano-api `b951a63` (`10.19.1.0`) | `cardano-api-p1-autobalance` | `cardano-api-p2-fixed-body-rebuild` | `cardano-api-p3-no-candidate-hook` | `cardano-api-p4-fixed-redeemer-rebuild` | probe evidence; independently re-derived by final external audit |
| CSL `6b42538` (`17.0.0`) | `csl-p1-change` | `csl-p2-external-loop-primitives` | `csl-p3-no-candidate-hook` | `csl-p4-fixed-redeemer-rebuild` | probe evidence; independently re-derived by final external audit |
| Pallas `cdee91d` (`1.1.1`) | `pallas-raw-not-balancer` | same raw-assembler check | same raw-assembler check | same raw-assembler check | probe evidence; independently re-derived by final external audit |
| cardano-client-lib `v0.7.2` | `ccl-p1-balance` | `ccl-p2-updateoutputfunction` | `ccl-p3-transaction-transform` | `ccl-p4-explicit-bound-required` | stable-pin probe; final audit independently confirmed capability at `v0.7.2` |
| Scalus `v1.0.0` | `scalus-p1-bounded-balance` | `scalus-p2-diffhandler` | `scalus-p3-candidate-transaction` | `scalus-p4-delayed-before-balance` | stable-pin probe; final audit independently confirmed capability at `v1.0.0` |
| Mesh SDK `1.9.1` | `mesh-p1-complete-balances` | `mesh-p2-fixed-output-rebuild` | `mesh-p3-evaluator-exunits-only` | `mesh-p4-fixed-redeemer-rebuild` | probe evidence; audit corrected P3 to “candidate visible, ExUnits-only return” |

`ledger-fee-api-pinned` separately guards the ledger-level
`estimateMinFeeTx`, `calcMinFeeTx`, and `calcMinFeeTxNativeScriptWits` rule at
`a9e78ae`.

The two audit reports are necessarily static evidence: they record human
judgment about wording, corpus policy, caveats, and cross-artifact consistency,
which a source-string check cannot establish. Cardano CLI is static-only because
the supplied evidence is a captured `--help` surface and no exact source flake
pin was part of the evidence contract. These limitations are explicit rather
than being presented as executable proof.

The preserved matrices contain 36 cells total: 15 `SUPPORTED`, 10
`EXPRESSIBLE-WITH-EFFORT`, 7 `NO-HOOK`, and 4 `NOT-APPLICABLE`.

## Floating drift mode

Pinned mode answers “does the documented claim still match its evidence pin?”
Floating mode answers “does current upstream still have the same capability
shape?” Run the same gate with one or more inputs overridden:

```sh
nix flake check --override-input tx-tools github:lambdasistemi/cardano-tx-tools
nix flake check --override-input csl github:Emurgo/cardano-serialization-lib
nix flake check --override-input pallas github:txpipe/pallas
nix flake check --override-input ccl github:bloxbean/cardano-client-lib
nix flake check --override-input scalus github:scalus3/scalus
nix flake check --override-input cardano-api github:IntersectMBO/cardano-api
nix flake check --override-input cardano-ledger github:IntersectMBO/cardano-ledger
```

For npm, resolve the current release number and override every package used by
that surface in the same invocation:

```sh
evolution_version=$(npm view @evolution-sdk/evolution version)
nix flake check --override-input evolution "https://registry.npmjs.org/@evolution-sdk/evolution/-/evolution-${evolution_version}.tgz"

mesh_version=$(npm view @meshsdk/core version)
nix flake check \
  --override-input mesh-core "https://registry.npmjs.org/@meshsdk/core/-/core-${mesh_version}.tgz" \
  --override-input mesh-transaction "https://registry.npmjs.org/@meshsdk/transaction/-/transaction-${mesh_version}.tgz" \
  --override-input mesh-common "https://registry.npmjs.org/@meshsdk/common/-/common-${mesh_version}.tgz"
```

Floating red is review evidence, not automatically an upstream regression. A
missing required string may mean an API moved or was renamed. In particular, a
red absence check says the previously missing capability may now exist: inspect
upstream and update the skill and matrix instead of weakening the check.

## Falsification

Each app accepts `FALSIFY=1`, which changes a required expectation to a value
that cannot be present. This is the test-of-the-test used during bundle creation:

```sh
FALSIFY=1 nix run .#tx-tools-p1-balance
```

All 31 apps were observed failing under this mutation and then passing again
with the mutation absent. The complete `CHECK-FALSIFIED` journal is in the
worker `STATUS.md`.
