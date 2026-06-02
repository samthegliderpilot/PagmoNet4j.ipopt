package io.github.samthegliderpilot.pagmonet4j.addon;

import io.github.samthegliderpilot.pagmonet4j.*;
import io.github.samthegliderpilot.pagmonet4j.problems.*;
import org.junit.jupiter.api.Test;
import java.math.BigInteger;
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
        @Override public boolean has_gradient_sparsity() { return true; }
        @Override
        public SparsityPattern gradient_sparsity() {
            return sparsity(new long[]{0, 0}, new long[]{0, 1});
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
    void ipoptOptionsAccepted() {
        try (ipopt algo = new ipopt()) {
            assertDoesNotThrow(() -> algo.set_integer_option_u64("max_iter", BigInteger.valueOf(100)));
            assertDoesNotThrow(() -> algo.set_string_option("linear_solver", "ma27"));
            assertDoesNotThrow(() -> algo.set_numeric_option("tol", 1e-8));
        }
    }

    @Test
    void ipoptEvolvesAndImproves() {
        try (QuadraticProblem prob = new QuadraticProblem();
             ipopt algo = new ipopt()) {

            try (population pop = new population(prob, 1L, 42L)) {
                double fInitial = pop.champion_f().get(0);

                population evolved = assertDoesNotThrow(() -> algo.evolve(pop),
                    "ipopt.evolve() must not throw");

                try {
                    assertNotNull(evolved, "evolve() must return a non-null population");
                    double fBest = evolved.champion_f().get(0);
                    assertTrue(fBest < fInitial,
                        String.format("IPOPT must improve on the starting point " +
                            "(initial f=%.4f, final f=%.4f)", fInitial, fBest));
                } finally {
                    if (evolved != null) evolved.close();
                }
            }
        }
    }

    @Test
    void ipoptHasNonEmptyName() {
        try (ipopt algo = new ipopt()) {
            String name = algo.get_name();
            assertFalse(name.isEmpty(), "ipopt.get_name() must return a non-empty string");
            assertTrue(name.toLowerCase().contains("ipopt"),
                "ipopt.get_name() should contain 'ipopt', got: " + name);
        }
    }
}
