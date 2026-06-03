# Changelog

## v1.0.0-beta.6

### Highlights

- Initial release as a standalone repository, split from `pagmoNet.ipopt`.
- Windows x64, Linux x64, and macOS (arm64 + x86_64) are all supported via CI.
- JUnit 5 test suite covering availability, instantiation, option setting, evolve improvement, and name verification.
- CI checks out PagmoNet4j, builds the native JNI library with IPOPT enabled, publishes `pagmonet4j` to `mavenLocal`, then runs the add-on tests.

### Known limitations

- The MA27 linear solver in this build uses IPOPT's HSL runtime-load model. The internal result code may not reflect full convergence status.
- MUMPS and SPRAL linear solvers are not included in this build.
