# Per-check invocations

Every check is also exposed as a strict-shell app under `apps`, so a single
claim can be run on its own:

```sh
nix build .#checks.x86_64-linux.tx-tools-p1-balance
nix run .#tx-tools-p1-balance
```

## Falsification

Each app accepts `FALSIFY=1`, which changes a required expectation to a value
that cannot be present. This is the test-of-the-test:

```sh
FALSIFY=1 nix run .#tx-tools-p1-balance
```

The source-evidence apps were observed failing under this mutation and then
passing again with the mutation absent. The reusable-example documentation has
its own falsified drift check:

```sh
FALSIFY=1 nix run .#examples-docs-inline
```

## Check names

Source-evidence checks, by surface:

| Surface | Checks |
|---|---|
| Cardano Tx Tools | `tx-tools-p1-balance`, `tx-tools-p2-fee-output`, `tx-tools-p3-peek`, `tx-tools-p4-recursive-redeemer` |
| Evolution SDK | `evolution-p1-balance-phases`, `evolution-p2-fixed-output-rebuild`, `evolution-p3-evaluator-exunits-only`, `evolution-p4-indexed-redeemer-only` |
| cardano-api | `cardano-api-p1-autobalance`, `cardano-api-p2-fixed-body-rebuild`, `cardano-api-p3-no-candidate-hook`, `cardano-api-p4-fixed-redeemer-rebuild` |
| Cardano Serialization Lib | `csl-p1-change`, `csl-p2-external-loop-primitives`, `csl-p3-no-candidate-hook`, `csl-p4-fixed-redeemer-rebuild` |
| Pallas | `pallas-raw-not-balancer` |
| cardano-client-lib | `ccl-p1-balance`, `ccl-p2-updateoutputfunction`, `ccl-p3-transaction-transform`, `ccl-p4-explicit-bound-required` |
| Scalus | `scalus-p1-bounded-balance`, `scalus-p2-diffhandler`, `scalus-p3-candidate-transaction`, `scalus-p4-delayed-before-balance` |
| Mesh SDK | `mesh-p1-complete-balances`, `mesh-p2-fixed-output-rebuild`, `mesh-p3-evaluator-exunits-only`, `mesh-p4-fixed-redeemer-rebuild` |
| Cardano Ledger | `ledger-fee-api-pinned` |

Unit, example, and cross-validation checks:

`tx-tools-unit`, `example-csl-outer-loop`, `example-evolution-outer-loop`,
`example-ccl-native-hook`, `example-scalus-diffhandler`, `crossval-csl`,
`crossval-ccl`, `examples-docs-inline`.

Cardano CLI has no executable check: the supplied evidence is a captured
`--help` surface, so its cells live in the
[gap matrix](../balance-fixpoint/gap-matrix.md) and in
[`cardano-cli.txt`](../balance-fixpoint/static/cardano-cli.txt) only.
