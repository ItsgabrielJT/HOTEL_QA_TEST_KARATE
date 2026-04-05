package payments;

import com.intuit.karate.junit5.Karate;

class PaymentsRunner {

    @Karate.Test
    Karate runPayments() {
        return Karate.run("payment-idempotency").relativeTo(getClass());
    }
}
