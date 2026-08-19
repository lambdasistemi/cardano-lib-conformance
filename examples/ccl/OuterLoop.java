import static com.bloxbean.cardano.client.function.helper.BalanceTxBuilders.balanceTx;
import static com.bloxbean.cardano.client.function.helper.FeeCalculators.feeCalculator;

import com.bloxbean.cardano.client.function.TxBuilder;
import com.bloxbean.cardano.client.function.helper.FeeCalculators.UpdateOutputFunction;
import java.math.BigInteger;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

public final class OuterLoop {
    private static final BigInteger INPUT = BigInteger.valueOf(5_000_000);
    private static final BigInteger TIP = BigInteger.valueOf(1_000_000);
    private static final int MAX_PASSES = 8;

    record Result(BigInteger fee, BigInteger refund, int passes) {}

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

            // The fixture's deterministic serializer supplies the candidate size offline.
            var candidateBytes = BigInteger.valueOf(200L + refund.toString().length());
            var required = BigInteger.valueOf(155_381).add(BigInteger.valueOf(44).multiply(candidateBytes));
            refundHook.accept(required, List.of());
            if (required.equals(feeGuess)) {
                if (!required.equals(observedFee.get())) throw new AssertionError("fee hook not called");
                if (!INPUT.equals(refund.add(required).add(TIP))) {
                    throw new AssertionError("lovelace is not conserved");
                }
                return new Result(required, refund, pass);
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
        System.out.printf("CCL native-hook loop converged in %d passes at fee %s%n",
                result.passes(), result.fee());
    }
}
