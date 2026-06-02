# PagmoNet4j.ipopt

Optional IPOPT (Interior Point OPTimizer) add-on for [PagmoNet4j](https://github.com/samthegliderpilot/PagmoNet4j).

IPOPT is a gradient-based interior-point solver for large-scale nonlinear constrained optimization. It requires the problem to supply gradients (`has_gradient()` returns `true`).

## Usage

```java
import io.github.samthegliderpilot.pagmonet4j.ipopt;

try (ipopt algo = new ipopt();
     island isl = island.create(algo, myProblem, 1L, 42L)) {
    isl.evolve(1L);
    isl.wait_check();
}
```

## License

Wrapper code: LGPL-2.1-or-later. See [LICENSE](LICENSE).  
IPOPT itself: EPL-2.0. See [NOTICE](NOTICE).

## Related

- [PagmoNet4j](https://github.com/samthegliderpilot/PagmoNet4j) — base Java/Kotlin bindings
- [pagmoNet](https://github.com/samthegliderpilot/pagmoNet) — shared SWIG + native bridge
- [pagmo.NET.ipopt](https://github.com/samthegliderpilot/pagmo.NET.ipopt) — C# equivalent
