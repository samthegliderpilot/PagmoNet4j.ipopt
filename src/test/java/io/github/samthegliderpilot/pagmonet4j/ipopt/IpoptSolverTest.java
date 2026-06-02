package io.github.samthegliderpilot.pagmonet4j.ipopt;

import io.github.samthegliderpilot.pagmonet4j.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Verifies that the IPOPT solver is present and functional in this add-on build.
 * All tests here are expected to pass — IPOPT availability is a hard requirement
 * for this module, not an optional feature.
 */
class IpoptSolverTest {

    // Minimise x² + (y-3)² — optimum at (0,3), f*=0, gradient provided.
    private static class QuadraticProblem extends ManagedProblemBase {
        @Override
        public DoubleVector fitness(DoubleVector x) {
            return vec(x.get(0) * x.get(0) + Math.pow(x.get(1) - 3.0, 2));
        }
        @Override
        public PairOfDoubleVectors get_bounds() {
            return bounds(new double[]{-10, -10}, new double[]{10, 10});
        }
        @Override public boolean has_gradient() { return true; }
        @Override
        public DoubleVector gradient(DoubleVector x) {
            return vec(2.0 * x.get(0), 2.0 * (x.get(1) - 3.0));
        }
    }

    @Test
    void ipoptIsAvailable() {
        assertTrue(OptionalSolverAvailability.isIpoptAvailable(),
            "PagmoNet4j.ipopt must be built against a native library that includes IPOPT");
    }

    @Test
    void ipoptCanBeInstantiated() {
        try (ipopt algo = new ipopt()) {
            assertNotNull(algo);
            assertFalse(algo.get_name().isEmpty());
        }
    }

    @Test
    void ipoptSolvesQuadraticProblem() {
        try (QuadraticProblem prob = new QuadraticProblem();
             ipopt algo = new ipopt();
             population pop = new population(prob, 1L, 42L);
             population evolved = algo.evolve(pop)) {

            assertNotNull(evolved);
            DoubleVector f = evolved.champion_f();
            double fBest = f.get(0);
            assertTrue(fBest < 1e-6,
                "IPOPT should converge near f*=0 on a simple quadratic; got f=" + fBest);
        }
    }

    @Test
    void ipoptOptionsAccepted() {
        try (ipopt algo = new ipopt()) {
            assertDoesNotThrow(() -> algo.set_integer_option("print_level", 0L));
            assertDoesNotThrow(() -> algo.set_string_option("linear_solver", "mumps"));
            assertDoesNotThrow(() -> algo.set_numeric_option("tol", 1e-8));
        }
    }

    @Test
    void ipoptNameIsCorrect() {
        try (ipopt algo = new ipopt()) {
            assertEquals("IPOPT", algo.get_name());
        }
    }
}
