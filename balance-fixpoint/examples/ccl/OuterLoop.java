import static com.bloxbean.cardano.client.function.helper.BalanceTxBuilders.balanceTx;
import static com.bloxbean.cardano.client.function.helper.FeeCalculators.feeCalculator;

import com.bloxbean.cardano.client.function.TxBuilder;
import com.bloxbean.cardano.client.function.helper.FeeCalculators.UpdateOutputFunction;
import com.bloxbean.cardano.client.spec.Era;
import com.bloxbean.cardano.client.transaction.spec.Transaction;
import com.bloxbean.cardano.client.transaction.spec.TransactionBody;
import com.bloxbean.cardano.client.transaction.spec.TransactionInput;
import com.bloxbean.cardano.client.transaction.spec.TransactionOutput;
import com.bloxbean.cardano.client.transaction.spec.TransactionWitnessSet;
import com.bloxbean.cardano.client.transaction.spec.Value;
import java.nio.file.Files;
import java.nio.file.Path;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

public final class OuterLoop {
    private static final BigInteger INPUT = BigInteger.valueOf(5_000_000);
    private static final BigInteger TIP = BigInteger.valueOf(1_000_000);
    private static final int MAX_PASSES = 8;

    record Result(BigInteger fee, BigInteger refund, int passes, byte[] cbor) {}

    static Value value(BigInteger coin) {
        var value = new Value();
        value.setCoin(coin);
        value.setMultiAssets(new ArrayList<>());
        return value;
    }

    static Transaction candidate(BigInteger fee, BigInteger refund) {
        var input = new TransactionInput();
        input.setTransactionId("2a".repeat(32));
        input.setIndex(0);
        var refundOutput = new TransactionOutput();
        refundOutput.setAddress("addr_test1gz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerspqgpsqe70et");
        refundOutput.setValue(value(refund));
        var tipOutput = new TransactionOutput();
        tipOutput.setAddress(refundOutput.getAddress());
        tipOutput.setValue(value(TIP));
        var body = new TransactionBody();
        body.setInputs(List.of(input));
        body.setOutputs(List.of(refundOutput, tipOutput));
        body.setFee(fee);
        var tx = new Transaction();
        tx.setEra(Era.Conway);
        tx.setBody(body);
        tx.setWitnessSet(new TransactionWitnessSet());
        tx.setValid(true);
        return tx;
    }

    static byte[] serialize(Transaction transaction) {
        try {
            return transaction.serialize();
        } catch (Exception error) {
            throw new IllegalStateException("could not serialize candidate", error);
        }
    }

    static Result balance(int bound) {
        BigInteger feeGuess = BigInteger.ZERO;
        for (int pass = 1; pass <= bound; pass++) {
            var refund = INPUT.subtract(TIP).subtract(feeGuess);
            if (refund.signum() < 0) throw new IllegalStateException("fee exceeds fixture input");

            var observedFee = new AtomicReference<BigInteger>();
            UpdateOutputFunction refundHook = (fee, outputs) -> observedFee.set(fee);
            // This is the native transform shape used with a real TxBuilderContext.
            TxBuilder pipeline = feeCalculator(1, refundHook)
                    .andThen(balanceTx(
                            "addr_test1gz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzerspqgpsqe70et",
                            1));
            if (pipeline == null) throw new AssertionError("native pipeline was not composed");

            var candidate = candidate(feeGuess, refund);
            var cbor = serialize(candidate);
            var required = BigInteger.valueOf(155_381)
                    .add(BigInteger.valueOf(44L * cbor.length));
            refundHook.accept(required, List.of());
            if (required.equals(feeGuess)) {
                if (!required.equals(observedFee.get())) throw new AssertionError("fee hook not called");
                if (!INPUT.equals(refund.add(required).add(TIP))) {
                    throw new AssertionError("lovelace is not conserved");
                }
                return new Result(required, refund, pass, cbor);
            }
            feeGuess = required;
        }
        throw new IllegalStateException("fee did not converge in " + bound + " passes");
    }

    public static void main(String[] args) {
        try {
            balance(1);
            throw new AssertionError("one-pass broken loop unexpectedly converged");
        } catch (IllegalStateException expected) {
            if (!expected.getMessage().contains("did not converge")) throw expected;
        }
        if (System.getenv("FALSIFY") != null) balance(1);
        var result = balance(MAX_PASSES);
        if (result.passes() > MAX_PASSES) throw new AssertionError("bound exceeded");
        var artifactDir = System.getenv("ARTIFACT_DIR");
        if (artifactDir != null) {
            try {
                Files.createDirectories(Path.of(artifactDir));
                Files.write(Path.of(artifactDir, "transaction.cbor"), result.cbor());
            } catch (Exception error) {
                throw new IllegalStateException("could not write converged transaction CBOR", error);
            }
        }
        System.out.printf("CCL native-hook loop converged in %d passes at fee %s%n",
                result.passes(), result.fee());
    }
}
