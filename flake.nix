{
  description = "Runnable, drift-detecting evidence for the Cardano fixpoint skill";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    tx-tools.url = "github:lambdasistemi/cardano-tx-tools/7bfe95bf5ef3bfa846e62bcae94cf377b66ad0d0";

    csl = {
      url = "github:Emurgo/cardano-serialization-lib/6b4253814f1831fee06cda2718fd47174960ace1";
      flake = false;
    };
    pallas = {
      url = "github:txpipe/pallas/cdee91d931132338570e6e6fef3191a61586d61b";
      flake = false;
    };
    ccl = {
      url = "github:bloxbean/cardano-client-lib/v0.7.2";
      flake = false;
    };
    scalus = {
      url = "github:scalus3/scalus/v1.0.0";
      flake = false;
    };
    cardano-api = {
      url = "github:IntersectMBO/cardano-api/b951a6380b8896a199fd2c4b751600b16029233b";
      flake = false;
    };
    cardano-ledger = {
      url = "github:IntersectMBO/cardano-ledger/a9e78ae63cf8870f0ce6ce76bd7029b82ddb47e1";
      flake = false;
    };
    evolution = {
      url = "https://registry.npmjs.org/@evolution-sdk/evolution/-/evolution-0.5.12.tgz";
      flake = false;
    };
    mesh-core = {
      url = "https://registry.npmjs.org/@meshsdk/core/-/core-1.9.1.tgz";
      flake = false;
    };
    mesh-transaction = {
      url = "https://registry.npmjs.org/@meshsdk/transaction/-/transaction-1.9.1.tgz";
      flake = false;
    };
    mesh-common = {
      url = "https://registry.npmjs.org/@meshsdk/common/-/common-1.9.1.tgz";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkSystem = system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = pkgs.lib;
          sources = {
            txTools = inputs."tx-tools".outPath;
            inherit (inputs) csl pallas ccl scalus evolution;
            api = inputs."cardano-api";
            ledger = inputs."cardano-ledger";
            meshTransaction = inputs."mesh-transaction";
            meshCommon = inputs."mesh-common";
          };

          renderRequire = source: assertion: ''
            needle=${lib.escapeShellArg assertion.text}
            if [[ "''${FALSIFY:-0}" == "1" ]]; then
              needle="''${needle}__FALSIFIED__"
            fi
            if ! rg --fixed-strings --quiet -- "$needle" ${source}/${assertion.file}; then
              printf 'required evidence missing: ${assertion.file}: %s\n' "$needle" >&2
              exit 1
            fi
          '';
          renderForbid = source: assertion: ''
            if rg --ignore-case --regexp ${lib.escapeShellArg assertion.regex} ${source}/${assertion.path}; then
              echo "drift detected: forbidden hook appeared in ${assertion.path}: ${assertion.regex}" >&2
              echo "Update the fixpoint skill and its matrix if upstream gained this capability." >&2
              exit 1
            fi
          '';
          mkApp = name: spec: pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.ripgrep ];
            text =
              lib.concatMapStrings (renderRequire spec.source) spec.require
              + lib.concatMapStrings (renderForbid spec.source) (spec.forbid or [ ]);
          };
          mkCheck = name: app:
            pkgs.runCommand name {
              nativeBuildInputs = [ pkgs.glibcLocales ];
              LANG = "C.UTF-8";
              LC_ALL = "C.UTF-8";
            } ''
              set -euo pipefail
              ${lib.getExe app}
              touch $out
            '';

          specs = {
            "tx-tools-p1-balance" = {
              source = sources.txTools;
              require = [
                { file = "src-tx-build/Cardano/Tx/Balance.hs"; text = "balanceTx ::"; }
                { file = "src-tx-build/Cardano/Tx/Balance.hs"; text = "FeeNotConverged"; }
              ];
            };
            "tx-tools-p2-fee-output" = {
              source = sources.txTools;
              require = [
                { file = "src-tx-build/Cardano/Tx/Balance.hs"; text = "balanceFeeLoop ::"; }
                { file = "src-tx-build/Cardano/Tx/Balance.hs"; text = "Coin ->"; }
              ];
            };
            "tx-tools-p3-peek" = {
              source = sources.txTools;
              require = [
                { file = "src-tx-build/Cardano/Tx/Build.hs"; text = "Peek ::"; }
                { file = "src-tx-build/Cardano/Tx/Build.hs"; text = "ConwayTx -> Convergence a"; }
              ];
            };
            "tx-tools-p4-recursive-redeemer" = {
              source = sources.txTools;
              require = [
                { file = "test/Cardano/Tx/Build/MinUtxoSpec.hs"; text = "peek (observeTxOutCoin ix)"; }
                { file = "test/Cardano/Tx/Build/MinUtxoSpec.hs"; text = "spendScript treasuryIn (toRedeemer lov)"; }
              ];
            };

            "csl-p1-change" = {
              source = sources.csl;
              require = [
                { file = "rust/src/builders/tx_builder.rs"; text = "pub fn add_change_if_needed"; }
                { file = "rust/src/builders/tx_builder.rs"; text = "self.min_fee()"; }
              ];
            };
            "csl-p2-external-loop-primitives" = {
              source = sources.csl;
              require = [
                { file = "rust/src/builders/tx_builder.rs"; text = "pub fn set_fee"; }
                { file = "rust/src/builders/tx_builder.rs"; text = "pub fn min_fee"; }
                { file = "rust/src/builders/tx_builder.rs"; text = "pub fn build(&self)"; }
              ];
            };
            "csl-p3-no-candidate-hook" = {
              source = sources.csl;
              require = [
                { file = "rust/src/builders/tx_builder.rs"; text = "pub struct TransactionBuilder"; }
              ];
              forbid = [
                { path = "rust/src/builders/tx_builder.rs"; regex = "(observe|on)[_-]?candidate|candidate[_-]?(callback|hook)|Convergence"; }
              ];
            };
            "csl-p4-fixed-redeemer-rebuild" = {
              source = sources.csl;
              require = [
                { file = "rust/src/builders/tx_builder.rs"; text = "pub fn build_tx(&self)"; }
                { file = "rust/src/builders/tx_builder.rs"; text = "pub fn set_fee"; }
              ];
            };

            "pallas-raw-not-balancer" = {
              source = sources.pallas;
              require = [
                { file = "pallas-txbuilder/src/conway.rs"; text = "with no automatic fee/ex-units calculation"; }
                { file = "pallas-txbuilder/src/conway.rs"; text = "\"Raw\" means no balancing"; }
              ];
            };

            "ccl-p1-balance" = {
              source = sources.ccl;
              require = [
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/helper/BalanceTxBuilders.java"; text = "public static TxBuilder balanceTx"; }
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/helper/BalanceTxBuilders.java"; text = "FeeCalculators.feeCalculator"; }
              ];
            };
            "ccl-p2-updateoutputfunction" = {
              source = sources.ccl;
              require = [
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/helper/FeeCalculators.java"; text = "updateOutputWithFeeFunc.accept"; }
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/helper/FeeCalculators.java"; text = "interface UpdateOutputFunction"; }
              ];
            };
            "ccl-p3-transaction-transform" = {
              source = sources.ccl;
              require = [
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/TxBuilder.java"; text = "void apply(TxBuilderContext context, Transaction txn)"; }
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/TxBuilder.java"; text = "default TxBuilder andThen"; }
              ];
            };
            "ccl-p4-explicit-bound-required" = {
              source = sources.ccl;
              require = [
                { file = "function/src/main/java/com/bloxbean/cardano/client/function/TxBuilder.java"; text = "@FunctionalInterface"; }
              ];
              forbid = [
                { path = "function/src/main/java"; regex = "Fixpoint|NonConvergent|Convergence"; }
              ];
            };

            "scalus-p1-bounded-balance" = {
              source = sources.scalus;
              require = [
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = "def balanceFeeAndChangeWithTokens("; }
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = "BalanceDidNotConverge"; }
              ];
            };
            "scalus-p2-diffhandler" = {
              source = sources.scalus;
              require = [
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = "type DiffHandler = (Value, Transaction)"; }
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = "diffHandler(diff, txWithFees)"; }
              ];
            };
            "scalus-p3-candidate-transaction" = {
              source = sources.scalus;
              require = [
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = "diffHandler: (Value, Transaction)"; }
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = "Either[TxBalancingError, Transaction]"; }
              ];
            };
            "scalus-p4-delayed-before-balance" = {
              source = sources.scalus;
              require = [
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionStepsProcessor.scala"; text = "replaceDelayedRedeemers("; }
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = ".ensureMinAdaAll(protocolParams)"; }
                { file = "scalus-cardano-ledger/shared/src/main/scala/scalus/cardano/txbuilder/TransactionBuilder.scala"; text = ".balance(combinedDiffHandler"; }
              ];
            };

            "evolution-p1-balance-phases" = {
              source = sources.evolution;
              require = [
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "feeCalculation"; }
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "changeCreation"; }
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "evaluation"; }
              ];
            };
            "evolution-p2-fixed-output-rebuild" = {
              source = sources.evolution;
              require = [
                { file = "dist/sdk/builders/operations/Operations.d.ts"; text = "readonly assets: CoreAssets.Assets"; }
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "Fresh state per build()"; }
              ];
            };
            "evolution-p3-evaluator-exunits-only" = {
              source = sources.evolution;
              require = [
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "readonly evaluator?: Evaluator"; }
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "evaluate: (tx: Transaction.Transaction"; }
                { file = "dist/sdk/builders/TransactionBuilder.d.ts"; text = "ReadonlyArray<EvalRedeemer"; }
              ];
              forbid = [
                { path = "dist/sdk/builders/TransactionBuilder.d.ts"; regex = "evaluate:.*(TransactionBuilder|TxOut|Output).*=>"; }
              ];
            };
            "evolution-p4-indexed-redeemer-only" = {
              source = sources.evolution;
              require = [
                { file = "dist/sdk/builders/RedeemerBuilder.d.ts"; text = "readonly index: number"; }
                { file = "dist/sdk/builders/RedeemerBuilder.d.ts"; text = "readonly utxo: UTxO.UTxO"; }
                { file = "dist/sdk/builders/RedeemerBuilder.d.ts"; text = "SelfRedeemerFn = (input: IndexedInput)"; }
              ];
              forbid = [
                { path = "dist/sdk/builders/RedeemerBuilder.d.ts"; regex = "IndexedInput.*(fee|outputs|transaction)"; }
              ];
            };

            "cardano-api-p1-autobalance" = {
              source = sources.api;
              require = [
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "makeTransactionBodyAutoBalance"; }
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "figure out the overall min fees"; }
              ];
            };
            "cardano-api-p2-fixed-body-rebuild" = {
              source = sources.api;
              require = [
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "-> TxBodyContent BuildTx era"; }
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "BalancedTxBody era"; }
              ];
            };
            "cardano-api-p3-no-candidate-hook" = {
              source = sources.api;
              require = [
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "makeTransactionBodyAutoBalance"; }
              ];
              forbid = [
                { path = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; regex = "(observe|on)[_-]?candidate|candidate[_-]?(callback|hook)|Convergence"; }
              ];
            };
            "cardano-api-p4-fixed-redeemer-rebuild" = {
              source = sources.api;
              require = [
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "substituteExecutionUnits"; }
                { file = "cardano-api/src/Cardano/Api/Tx/Internal/Fee.hs"; text = "-> TxBodyContent BuildTx era"; }
              ];
            };

            "mesh-p1-complete-balances" = {
              source = sources.meshTransaction;
              require = [
                { file = "dist/index.d.ts"; text = "complete: (customizedTx?: Partial<MeshTxBuilderBody>)"; }
                { file = "dist/index.js"; text = "const txPrototype = await this.selectUtxos()"; }
                { file = "dist/index.js"; text = "await clonedBuilder.evaluateRedeemers()"; }
              ];
            };
            "mesh-p2-fixed-output-rebuild" = {
              source = sources.meshTransaction;
              require = [
                { file = "dist/index.d.ts"; text = "txOut: (address: string, amount: Asset[])"; }
                { file = "dist/index.d.ts"; text = "meshTxBuilderBody: MeshTxBuilderBody"; }
                { file = "dist/index.d.ts"; text = "getActualFee: () => bigint"; }
              ];
            };
            "mesh-p3-evaluator-exunits-only" = {
              source = sources.meshCommon;
              require = [
                { file = "dist/index.d.ts"; text = "interface IEvaluator"; }
                { file = "dist/index.d.ts"; text = "evaluateTx"; }
                { file = "dist/index.d.ts"; text = "Promise<Omit<Action, \"data\">[]>"; }
              ];
              forbid = [
                { path = "dist/index.d.ts"; regex = "evaluateTx.*(TxOutput|MeshTxBuilderBody).*=>"; }
              ];
            };
            "mesh-p4-fixed-redeemer-rebuild" = {
              source = sources.meshTransaction;
              require = [
                { file = "dist/index.d.ts"; text = "txInRedeemerValue: (redeemer: BuilderData"; }
                { file = "dist/index.d.ts"; text = "completeUnbalanced: (customizedTx?: MeshTxBuilderBody)"; }
              ];
            };

            "ledger-fee-api-pinned" = {
              source = sources.ledger;
              require = [
                { file = "libs/cardano-ledger-core/src/Cardano/Ledger/Tools.hs"; text = "estimateMinFeeTx"; }
                { file = "libs/cardano-ledger-core/src/Cardano/Ledger/Tools.hs"; text = "calcMinFeeTx"; }
                { file = "libs/cardano-ledger-core/src/Cardano/Ledger/Tools.hs"; text = "calcMinFeeTxNativeScriptWits"; }
              ];
            };
          };

          evidenceApps = lib.mapAttrs mkApp specs;
          evidenceChecks = lib.mapAttrs mkCheck evidenceApps;
          txToolsUnitResult = inputs."tx-tools".checks.${system}.unit;
          txToolsUnitApp = pkgs.writeShellApplication {
            name = "tx-tools-unit";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              target=${txToolsUnitResult}
              if [[ "''${FALSIFY:-0}" == "1" ]]; then
                target="${txToolsUnitResult}/__FALSIFIED__"
              fi
              test -e "$target" || {
                echo "pinned Cardano Tx Tools unit check did not produce its result" >&2
                exit 1
              }
            '';
          };
          txToolsUnit = pkgs.runCommand "tx-tools-unit" { } ''
            set -euo pipefail
            ${lib.getExe txToolsUnitApp}
            touch $out
          '';
          allApps = evidenceApps // { tx-tools-unit = txToolsUnitApp; };
        in {
          checks = evidenceChecks // { tx-tools-unit = txToolsUnit; };
          apps = lib.mapAttrs (_: app: {
            type = "app";
            program = lib.getExe app;
          }) allApps;
        };
      perSystem = forAllSystems mkSystem;
    in {
      checks = nixpkgs.lib.mapAttrs (_: value: value.checks) perSystem;
      apps = nixpkgs.lib.mapAttrs (_: value: value.apps) perSystem;
    };
}
