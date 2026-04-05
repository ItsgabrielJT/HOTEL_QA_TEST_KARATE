package availability;

import com.intuit.karate.junit5.Karate;

class AvailabilityRunner {

    @Karate.Test
    Karate runAvailability() {
        return Karate.run("rooms-availability").relativeTo(getClass());
    }
}
