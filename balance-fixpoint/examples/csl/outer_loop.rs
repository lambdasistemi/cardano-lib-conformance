use cardano_serialization_lib::*;

const INPUT: u64 = 5_000_000;
const TIP: u64 = 1_000_000;
const MAX_PASSES: usize = 8;

#[derive(Debug, PartialEq)]
enum BalanceError {
    NonConvergent { bound: usize },
    Library(String),
}

fn fixture_address() -> Address {
    let key_hash = Ed25519KeyHash::from_bytes(vec![7; 28]).expect("fixture key hash");
    EnterpriseAddress::new(0, &Credential::from_keyhash(&key_hash)).to_address()
}

fn fresh_builder(fee_guess: u64) -> Result<TransactionBuilder, BalanceError> {
    let config = TransactionBuilderConfigBuilder::new()
        .fee_algo(&LinearFee::new(&BigNum::from(44_u64), &BigNum::from(155_381_u64)))
        .pool_deposit(&BigNum::from(500_000_000_u64))
        .key_deposit(&BigNum::from(2_000_000_u64))
        .max_value_size(5_000)
        .max_tx_size(16_384)
        .coins_per_utxo_byte(&BigNum::from(4_310_u64))
        .build()
        .map_err(|e| BalanceError::Library(e.to_string()))?;
    let address = fixture_address();
    let mut builder = TransactionBuilder::new(&config);
    let input = TransactionInput::new(
        &TransactionHash::from_bytes(vec![42; 32]).expect("fixture transaction hash"),
        0,
    );
    builder
        .add_regular_input(&address, &input, &Value::new(&BigNum::from(INPUT)))
        .map_err(|e| BalanceError::Library(e.to_string()))?;
    let refund = INPUT
        .checked_sub(TIP + fee_guess)
        .ok_or_else(|| BalanceError::Library("fee exceeds fixture input".into()))?;
    builder
        .add_output(&TransactionOutput::new(
            &address,
            &Value::new(&BigNum::from(refund)),
        ))
        .map_err(|e| BalanceError::Library(e.to_string()))?;
    builder
        .add_output(&TransactionOutput::new(
            &address,
            &Value::new(&BigNum::from(TIP)),
        ))
        .map_err(|e| BalanceError::Library(e.to_string()))?;
    builder.set_min_fee(&BigNum::from(fee_guess));
    Ok(builder)
}

fn balance(bound: usize) -> Result<(Transaction, usize), BalanceError> {
    let mut fee_guess = 0;
    for pass in 1..=bound {
        // A candidate is disposable: the fee-dependent output is rebuilt from fixtures.
        let builder = fresh_builder(fee_guess)?;
        let required = builder
            .min_fee()
            .map_err(|e| BalanceError::Library(e.to_string()))?;
        if required == BigNum::from(fee_guess) {
            let tx = builder
                .build_tx()
                .map_err(|e| BalanceError::Library(e.to_string()))?;
            return Ok((tx, pass));
        }
        fee_guess = required.into();
    }
    Err(BalanceError::NonConvergent { bound })
}

fn main() {
    assert_eq!(
        balance(1),
        Err(BalanceError::NonConvergent { bound: 1 }),
        "the deliberately too-small bound must be rejected"
    );
    if std::env::var_os("FALSIFY").is_some() {
        balance(1).expect("FALSIFY: a one-pass loop must not converge");
    }

    let (tx, passes) = balance(MAX_PASSES).expect("bounded outer loop converged");
    let fee: u64 = tx.body().fee().into();
    let refund: u64 = tx.body().outputs().get(0).amount().coin().into();
    let required: u64 = fresh_builder(fee).unwrap().min_fee().unwrap().into();
    assert!(passes <= MAX_PASSES);
    assert!(fee >= required, "converged fee must be sufficient");
    assert_eq!(INPUT, refund + fee + TIP, "lovelace must be conserved");
    if let Some(dir) = std::env::var_os("ARTIFACT_DIR") {
        std::fs::create_dir_all(&dir).expect("create artifact directory");
        std::fs::write(std::path::Path::new(&dir).join("transaction.cbor"), tx.to_bytes())
            .expect("write converged transaction CBOR");
    }
    println!("CSL outer loop converged in {passes} passes at fee {fee}");
}
