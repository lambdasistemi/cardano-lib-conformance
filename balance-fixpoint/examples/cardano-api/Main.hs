{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Cardano.Api qualified as Api
import Cardano.Api.Genesis qualified as Genesis
import Cardano.Api.Ledger qualified as Ledger
import Cardano.Api.Plutus qualified as Script
import Cardano.Ledger.Alonzo.Scripts qualified as Alonzo
import Cardano.Ledger.Api qualified as LedgerApi
import Cardano.Slotting.EpochInfo qualified as Slotting
import Cardano.Slotting.Slot qualified as Slotting
import Cardano.Slotting.Time qualified as Slotting
import Control.Monad (unless)
import Data.Functor.Identity (Identity)
import Data.Maybe (fromMaybe)
import Data.Ratio ((%))
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Lens.Micro ((&))
import System.Environment (lookupEnv)

inputLovelace :: Integer
inputLovelace = 12_000_000

basePayment :: Integer
basePayment = 10_000_000

fixtureAddress :: Api.AddressInEra Api.ConwayEra
fixtureAddress =
    fromMaybe (error "invalid fixture address") $
        Api.deserialiseAddress
            (Api.AsAddressInEra Api.AsConwayEra)
            "addr_test1vzpfxhjyjdlgk5c0xt8xw26avqxs52rtf69993j4tajehpcue4v2v"

fixtureTxIn :: Api.TxIn
fixtureTxIn =
    let txId =
            either (error . show) id $
                Api.deserialiseFromRawBytesHex
                    "be6efd42a3d7b9a00d09d77a5d41e55ceaf0bd093a8aa8a893ce70d9caafd978"
     in Api.TxIn txId (Api.TxIx 0)

fixtureProtocolParams :: Ledger.PParams LedgerApi.ConwayEra
fixtureProtocolParams =
    LedgerApi.upgradePParams conwayUpgrade $
        LedgerApi.upgradePParams () $
            LedgerApi.upgradePParams alonzoUpgrade $
                LedgerApi.upgradePParams () $
                    LedgerApi.upgradePParams () $
                        Genesis.sgProtocolParams Genesis.shelleyGenesisDefaults
  where
    conwayUpgrade :: Ledger.UpgradeConwayPParams Identity
    conwayUpgrade = Ledger.cgUpgradePParams Genesis.conwayGenesisDefaults

    alonzoUpgrade :: Alonzo.UpgradeAlonzoPParams Identity
    alonzoUpgrade =
        Alonzo.UpgradeAlonzoPParams
            { Alonzo.uappCoinsPerUTxOWord = Ledger.CoinPerWord $ Ledger.Coin 34_482
            , Alonzo.uappCostModels = Alonzo.emptyCostModels
            , Alonzo.uappPrices =
                Ledger.Prices
                    { Ledger.prSteps = fromMaybe maxBound $ Ledger.boundRational $ 721 % 10_000_000
                    , Ledger.prMem = fromMaybe maxBound $ Ledger.boundRational $ 577 % 10_000
                    }
            , Alonzo.uappMaxTxExUnits = Ledger.ExUnits 140_000_000 10_000_000_000
            , Alonzo.uappMaxBlockExUnits = Ledger.ExUnits 62_000_000 20_000_000_000
            , Alonzo.uappMaxValSize = 5000
            , Alonzo.uappCollateralPercentage = 150
            , Alonzo.uappMaxCollateralInputs = 3
            }

coinFromOutput :: Api.TxOut context Api.ConwayEra -> Integer
coinFromOutput (Api.TxOut _ value _ _) =
    Api.unLovelace $ Api.selectLovelace $ Api.txOutValueToValue value

balancePass :: Integer -> Either String (Integer, Integer)
balancePass previousFee = do
    let sbe = Api.ShelleyBasedEraConway
        recipient = basePayment - previousFee
        content =
            Api.defaultTxBodyContent sbe
                & Api.setTxIns
                    [(fixtureTxIn, Api.BuildTxWith $ Api.KeyWitness Api.KeyWitnessForSpending)]
                & Api.setTxOuts
                    [ Api.TxOut
                        fixtureAddress
                        (Api.lovelaceToTxOutValue sbe recipient)
                        Api.TxOutDatumNone
                        Script.ReferenceScriptNone
                    ]
        epochInfo =
            Api.LedgerEpochInfo $
                Slotting.fixedEpochInfo (Slotting.EpochSize 100) (Slotting.mkSlotLength 1000)
        utxo =
            Api.UTxO
                [
                    ( fixtureTxIn
                    , Api.TxOut
                        fixtureAddress
                        (Api.lovelaceToTxOutValue sbe inputLovelace)
                        Api.TxOutDatumNone
                        Script.ReferenceScriptNone
                    )
                ]
    Api.BalancedTxBody balanced _ change (Ledger.Coin fee) <-
        either (Left . show) Right $
            Api.makeTransactionBodyAutoBalance
                sbe
                (Api.SystemStart $ posixSecondsToUTCTime 0)
                epochInfo
                (Api.LedgerProtocolParameters fixtureProtocolParams)
                mempty
                mempty
                mempty
                utxo
                content
                fixtureAddress
                Nothing
    let outputTotal = sum $ map coinFromOutput $ Api.txOuts balanced
        changeCoin = coinFromOutput change
    unless (inputLovelace == outputTotal + fee) $
        Left "autobalance candidate did not conserve lovelace"
    unless (changeCoin >= 0) $ Left "negative change"
    pure (fee, changeCoin)

runOuterLoop :: Int -> IO ()
runOuterLoop bound = go 1 0
  where
    go pass previousFee
        | pass > bound = fail "cardano-api outer loop did not converge within its bound"
        | otherwise = do
            (fee, change) <- either fail pure $ balancePass previousFee
            putStrLn $
                "pass "
                    <> show pass
                    <> ": guessed fee="
                    <> show previousFee
                    <> ", required fee="
                    <> show fee
                    <> ", change="
                    <> show change
            if fee == previousFee
                then putStrLn $ "cardano-api outer loop converged in " <> show pass <> " passes"
                else go (pass + 1) fee

main :: IO ()
main = do
    falsify <- lookupEnv "FALSIFY"
    runOuterLoop $ maybe 8 (const 1) falsify
