package worker;

import com.intuit.karate.junit5.Karate;

class WorkerRunner {

    @Karate.Test
    Karate runWorker() {
        return Karate.run("hold-expiration-worker").relativeTo(getClass());
    }
}
