# Worked outer-loop examples

Use a bounded caller-owned loop when an output depends on the eventual fee and the
library cannot observe and rewrite that output during its own balancing pass:

1. Pin protocol parameters and the synthetic input set for every pass.
2. Start from a fee guess, derive the fee-dependent output, and allocate a fresh builder.
3. Build the candidate, inspect its required fee, and repeat with that fee as the next guess.
4. Stop only when the fee is unchanged; fail with a distinct non-convergence error at the bound.
5. After convergence, validate fee sufficiency and value conservation.

## CSL 17.0.0

[`csl/outer_loop.rs`](csl/outer_loop.rs) is a complete offline Rust program. It
uses CSL's `TransactionBuilder`, `set_fee`, `min_fee`, and `build_tx` against a
fixed protocol-parameter fixture and synthetic UTxO. The runtime check also
proves that a one-pass broken variant is rejected. This complements CSL matrix
cells P2–P4, where the primitives exist but the candidate callback does not.

```sh
nix build .#checks.x86_64-linux.example-csl-outer-loop
```

## Evolution SDK 0.5.12

[`evolution/outer-loop.ts`](evolution/outer-loop.ts) expresses the same loop with
the public `makeTxBuilder`, `collectFrom`, `payToAddress`, `build`, `estimateFee`,
and `toTransaction` surface. The check typechecks it with `tsc` against the
pinned npm tarball; it does not execute because the release's Effect/runtime
dependency tree is not included in this evidence bundle. It complements P2–P4:
fresh builds and candidate inspection exist, while the evaluator returns only
execution units.

```sh
nix build .#checks.x86_64-linux.example-evolution-outer-loop
```

## cardano-client-lib 0.7.2

[`ccl/OuterLoop.java`](ccl/OuterLoop.java) composes
`feeCalculator(..., UpdateOutputFunction)` with `balanceTx`, places that native
hook inside a caller-owned eight-pass loop, and runs entirely offline from
fixed-output Maven jars. Every pass serializes a real CCL transaction, so the
fee guess is based on the candidate's actual byte length. The program rejects a
one-pass loop and checks fee observation and value conservation. This
complements P2–P4 and makes the caller-owned bound explicit outside CCL's
internal adjustment retries.

```sh
nix build .#checks.x86_64-linux.example-ccl-native-hook
```

## Scalus 1.0.0

[`scalus/OuterLoop.scala`](scalus/OuterLoop.scala) supplies a typed `DiffHandler`
and a caller-owned bound around a fresh-candidate transform. It records the
ordering constraint that delayed datum/redeemer builders run before min-UTxO
and balancing. The check is compile-only: the published ledger POM has eight
direct runtime dependencies plus enough transitive artifacts to exceed the
ten-jar direct-pinning cutoff. This complements Scalus P2–P4.

```sh
nix build .#checks.x86_64-linux.example-scalus-diffhandler
```

Mesh was dropped at the bottom of the timebox priority list. Its static P1–P4
checks remain unchanged; there is no worked Mesh example in this slice.
