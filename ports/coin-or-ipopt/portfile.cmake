# Skip the debug build: we only need release IPOPT for our native library.
# This also avoids the debug-configure-only failures (debug LDFLAGS omit the
# release lib dir, causing openblas/lapack link tests to fail before the
# release configure even runs).
set(VCPKG_BUILD_TYPE release)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO coin-or/Ipopt
    REF ec43e37a06054246764fb116e50e3e30c9ada089
    SHA512 f5b30e81b4a1a178e9a0e2b51b4832f07441b2c3e9a2aa61a6f07807f94185998e985fcf3c34d96fbfde78f07b69f2e0a0675e1e478a4e668da6da60521e0fd6
    HEAD_REF master
)

file(COPY "${CURRENT_INSTALLED_DIR}/share/coin-or-buildtools/" DESTINATION "${SOURCE_PATH}")

# IpMumpsSolverInterface.cpp and dmumps_c.h include "mpi.h" even when building
# against sequential (non-MPI) MUMPS.  The system mpi.h is in an MPI-specific
# directory not in the compiler's default path, and COIN-OR's autotools build
# does NOT propagate CPPFLAGS into the per-library compile rules.
#
# Solution: write a minimal type-only stub into ${SOURCE_PATH}/src, which IS
# in every compile command as -I.././../src/<hash>/src.  No function
# declarations — so configure's MPI_Initialized link test still fails and IPOPT
# stays in sequential mode with no MPI runtime dependency.
file(WRITE "${SOURCE_PATH}/src/mpi.h"
"/* Sequential MUMPS MPI type stub — types only, no function declarations.
   configure's MPI_Initialized link test will still fail so IPOPT stays
   in sequential (no-MPI) mode with no MPI runtime dependency. */
#ifndef IPOPT_MUMPS_SEQ_MPI_STUB_H
#define IPOPT_MUMPS_SEQ_MPI_STUB_H
typedef int MPI_Comm;
typedef int MPI_Datatype;
typedef int MPI_Op;
typedef int MPI_Status;
typedef int MPI_Request;
typedef int MPI_Info;
typedef int MPI_Group;
typedef int MPI_Errhandler;
typedef long MPI_Aint;
typedef long MPI_Offset;
#define MPI_COMM_WORLD   ((MPI_Comm)0)
#define MPI_COMM_SELF    ((MPI_Comm)1)
#define MPI_SUCCESS      0
#define MPI_UNDEFINED    (-1)
#define MPI_DOUBLE       ((MPI_Datatype)0)
#define MPI_INT          ((MPI_Datatype)0)
#define MPI_SUM          ((MPI_Op)0)
#define MPI_STATUS_IGNORE ((MPI_Status*)0)
#endif
")

set(ENV{ACLOCAL} "aclocal -I \"${SOURCE_PATH}/BuildTools\"")

if(VCPKG_TARGET_IS_WINDOWS)
    # MUMPS provided by coin-or-mumps bridge port (system MSYS2/MinGW64).
    # Use POSIX /c/msys64/... paths since configure runs inside MSYS2 bash.
    set(_mumps_cflags "-I/c/msys64/mingw64/include")
    set(_mumps_libs "-L/c/msys64/mingw64/lib -ldmumps -lmumps_common -lpord -lgfortran -lopenblas")
    set(ENV{MUMPS_CFLAGS} "${_mumps_cflags}")
    set(ENV{MUMPS_LIBS} "${_mumps_libs}")
    set(ENV{COINMUMPS_CFLAGS} "${_mumps_cflags}")
    set(ENV{COINMUMPS_LIBS} "${_mumps_libs}")
    set(_mumps_option "--with-mumps")
    # Use vcpkg-installed lapack/openblas (MSVC-compatible) for the LAPACK check.
    # MSYS2's MinGW libopenblas.a cannot be linked by MSVC's link.exe.
    set(LAPACK_OPTION "--with-lapack=-L${CURRENT_INSTALLED_DIR}/lib -llapack -lopenblas")
    set(CXXLIBS_OPTION "CXXLIBS=")
else()
    # Linux/macOS: MUMPS is provided by the coin-or-mumps bridge port, which
    # writes coinmumps.pc into ${CURRENT_INSTALLED_DIR}/lib/pkgconfig.
    # vcpkg_configure_make automatically adds that dir to PKG_CONFIG_PATH.
    # Belt-and-suspenders: also set the env vars that AC_COIN_CHK_PKG reads
    # when pkg-config fails (both naming conventions).
    if(VCPKG_TARGET_IS_OSX)
        set(_mumps_prefix "$ENV{MUMPS_PREFIX}")
        if(NOT _mumps_prefix OR NOT EXISTS "${_mumps_prefix}")
            set(_mumps_prefix "$ENV{HOME}/mumps-env")
        endif()
        set(_mumps_cflags "-I${_mumps_prefix}/include")
        set(_mumps_libs "-L${_mumps_prefix}/lib -ldmumps -lmumps_common")
        # vcpkg's lapack on macOS wraps Accelerate (pure C); no gfortran needed.
        set(LAPACK_OPTION "--with-lapack=-L${CURRENT_INSTALLED_DIR}/lib -llapack -lopenblas")
    else()
        find_library(_dmumps_lib NAMES dmumps_seq dmumps
            HINTS
                /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
                /usr/lib/x86_64-linux-gnu
                /usr/lib/aarch64-linux-gnu
                /usr/lib
            NO_DEFAULT_PATH)
        if(_dmumps_lib)
            get_filename_component(_mumps_lib_dir "${_dmumps_lib}" DIRECTORY)
        else()
            set(_mumps_lib_dir "/usr/lib/x86_64-linux-gnu")
        endif()
        if(_dmumps_lib MATCHES "_seq")
            set(_mumps_sfx "_seq")
        else()
            set(_mumps_sfx "")
        endif()
        set(_mumps_cflags "-I/usr/include")
        set(_mumps_libs "-L${_mumps_lib_dir} -ldmumps${_mumps_sfx} -lmumps_common${_mumps_sfx}")
        # vcpkg's lapack-reference is compiled from Fortran; liblapack.a needs
        # the gfortran runtime (_gfortran_*) and libm (sqrt, logf, etc.).
        set(LAPACK_OPTION "--with-lapack=-L${CURRENT_INSTALLED_DIR}/lib -llapack -lopenblas -lgfortran -lm")
    endif()

    set(ENV{MUMPS_CFLAGS} "${_mumps_cflags}")
    set(ENV{MUMPS_LIBS} "${_mumps_libs}")
    set(ENV{COINMUMPS_CFLAGS} "${_mumps_cflags}")
    set(ENV{COINMUMPS_LIBS} "${_mumps_libs}")

    set(_mumps_option "--with-mumps")
    set(CXXLIBS_OPTION "")
endif()

vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTOCONFIG
    OPTIONS
      --without-spral
      --without-hsl
      --without-asl
      ${LAPACK_OPTION}
      ${_mumps_option}
      --enable-relocatable
      --disable-f77
      --disable-java
    OPTIONS_RELEASE
      ${CXXLIBS_OPTION}
    OPTIONS_DEBUG
      ${CXXLIBS_OPTION}
)

vcpkg_install_make()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
