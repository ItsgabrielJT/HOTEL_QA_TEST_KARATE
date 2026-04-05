package reservations;

import com.intuit.karate.junit5.Karate;

class ReservationsRunner {

    @Karate.Test
    Karate runReservations() {
        return Karate.run("reservation-lifecycle").relativeTo(getClass());
    }
}
