use pallas_primitives::{alonzo, conway};

const FIXTURE_INPUT: u64 = 5_000_000;
const FEE_A: u64 = 44;
const FEE_B: u64 = 155_381;

fn alonzo_coin(value: &alonzo::Value) -> u64 {
    match value {
        alonzo::Value::Coin(coin) | alonzo::Value::Multiasset(coin, _) => *coin,
    }
}

fn conway_coin(value: &conway::Value) -> u64 {
    match value {
        conway::Value::Coin(coin) | conway::Value::Multiasset(coin, _) => *coin,
    }
}

fn output_coin(output: &conway::TransactionOutput) -> u64 {
    match output {
        conway::TransactionOutput::Legacy(output) => alonzo_coin(&output.amount),
        conway::TransactionOutput::PostAlonzo(output) => conway_coin(&output.value),
    }
}

fn main() {
    let path = std::env::args().nth(1).expect("usage: pallas-crossval TX.cbor");
    let bytes = std::fs::read(path).expect("read producer artifact");
    let tx: conway::Tx = pallas_codec::minicbor::decode(&bytes)
        .expect("artifact must decode as a structurally valid Conway transaction");
    let body = &tx.transaction_body;
    assert!(body.reference_inputs.is_none(), "fixture unexpectedly uses reference inputs");
    let minimum_fee = FEE_A * bytes.len() as u64 + FEE_B;
    assert!(body.fee >= minimum_fee, "declared fee is below raw-byte minimum");
    let outputs = body.outputs.iter().map(output_coin).sum::<u64>();
    let fixture_input = if std::env::var_os("FALSIFY").is_some() {
        FIXTURE_INPUT + 1
    } else {
        FIXTURE_INPUT
    };
    assert_eq!(fixture_input, outputs + body.fee, "decoded value is not conserved");
    println!("Pallas decoded Conway tx: {} bytes, fee {}, outputs {}", bytes.len(), body.fee, outputs);
}
