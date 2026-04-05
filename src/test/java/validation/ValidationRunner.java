package validation;

import com.intuit.karate.junit5.Karate;

class ValidationRunner {

    @Karate.Test
    Karate runValidation() {
        return Karate.run("date-validation").relativeTo(getClass());
    }
}
