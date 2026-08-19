# Cardano library conformance

This repository provides pinned, executable interface and behavioral
conformance checks for Cardano libraries. Conformance is organized by
capability domain: each new Cardano developer skill contributes a new domain,
with its own evidence, examples, and cross-library validation, while the
repository keeps one root Nix flake as the unified gate.

## Domains

| Domain | Capability | Evidence |
|---|---|---|
| [`balance-fixpoint`](balance-fixpoint/README.md) | Bounded transaction balancing when outputs or redeemers depend on the candidate transaction | 31 pinned interface checks, four worked-example checks, and two independent runtime cross-validations |

The first domain retains its original check names for compatibility. Future
domains should prefix check names with their domain when ambiguity is possible.

## Run the conformance gate

```sh
nix flake check
```

`flake.lock` fixes all upstream sources. See each domain README for its claim
map, falsification protocol, floating-drift commands, and known limits.
