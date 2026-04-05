package holds;

import com.intuit.karate.junit5.Karate;

class HoldsRunner {

    @Karate.Test
    Karate runHolds() {
        return Karate.run("room-hold").relativeTo(getClass());
    }
}
