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

# VCPKG_TARGET_IS_MINGW must be checked before VCPKG_TARGET_IS_WINDOWS because
# both are true on MinGW/Windows. MinGW is required for IPOPT+MUMPS on Windows:
# MSYS2's MUMPS static archives (.a) cannot be linked by MSVC's link.exe.
if(VCPKG_TARGET_IS_MINGW)
    # Windows/MinGW: GCC build. MSYS2's MUMPS (mingw-w64-x86_64-mumps) is
    # compatible with GCC's ld. The MUMPS package also installs openblas,
    # so we use it for LAPACK rather than vcpkg's lapack (which is not
    # installed for the mingw triplet).
    set(_mumps_cflags "-I/c/msys64/mingw64/include")
    set(_mumps_libs "-L/c/msys64/mingw64/lib -ldmumps -lmumps_common -lpord -lgfortran -lopenblas")
    set(LAPACK_OPTION "--with-lapack=-L/c/msys64/mingw64/lib -lopenblas")
    set(CXXLIBS_OPTION "")

elseif(VCPKG_TARGET_IS_OSX)
    # macOS: MUMPS from conda-forge (micromamba create -c conda-forge mumps-seq).
    # Set MUMPS_PREFIX env var in CI or fall back to ~/mumps-env.
    set(_mumps_prefix "$ENV{MUMPS_PREFIX}")
    if(NOT _mumps_prefix OR NOT EXISTS "${_mumps_prefix}")
        set(_mumps_prefix "$ENV{HOME}/mumps-env")
    endif()
    set(_mumps_cflags "-I${_mumps_prefix}/include")
    # conda-forge mumps-seq on ARM macOS installs libdmumps_seq.dylib (with _seq suffix).
    # Detect which name is actually present so the configure link test succeeds.
    find_library(_dmumps_mac_lib NAMES dmumps_seq dmumps
        HINTS "${_mumps_prefix}/lib"
        NO_DEFAULT_PATH)
    if(_dmumps_mac_lib MATCHES "_seq")
        set(_mumps_sfx "_seq")
    else()
        set(_mumps_sfx "")
    endif()
    unset(_dmumps_mac_lib)
    set(_mumps_libs "-L${_mumps_prefix}/lib -ldmumps${_mumps_sfx} -lmumps_common${_mumps_sfx}")
    # vcpkg's lapack on macOS wraps Accelerate (pure C); no gfortran needed.
    set(LAPACK_OPTION "--with-lapack=-L${CURRENT_INSTALLED_DIR}/lib -llapack -lopenblas")
    set(CXXLIBS_OPTION "")

elseif(VCPKG_TARGET_IS_LINUX)
    # Linux: system libmumps-seq-dev. Try the _seq-suffixed name first (sequential
    # build without MPI runtime dependency), then the plain name.
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
    set(CXXLIBS_OPTION "")

else()
    # MSVC Windows: MSYS2's MUMPS .a archives cannot be linked by MSVC's link.exe.
    # Build IPOPT+MUMPS using the x64-mingw-static triplet instead.
    message(FATAL_ERROR
        "coin-or-ipopt: IPOPT+MUMPS on MSVC Windows is not supported. "
        "Use the x64-mingw-static triplet (build-native.ps1 selects it automatically when IPOPT is enabled).")
endif()

set(ENV{MUMPS_CFLAGS} "${_mumps_cflags}")
set(ENV{MUMPS_LIBS} "${_mumps_libs}")
set(ENV{COINMUMPS_CFLAGS} "${_mumps_cflags}")
set(ENV{COINMUMPS_LIBS} "${_mumps_libs}")
set(_mumps_option "--with-mumps")

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

if(VCPKG_TARGET_IS_OSX)
    # On macOS, -lm is part of libSystem.B.dylib and needs no explicit -lm flag.
    # Xcode 16+ no longer ships a separate libm.tbd; cmake resolves -lm to that
    # missing path and fails. Strip -lm from all installed ipopt pkg-config files.
    file(GLOB _ipopt_pc_files "${CURRENT_PACKAGES_DIR}/**/pkgconfig/ipopt.pc")
    foreach(_f IN LISTS _ipopt_pc_files)
        file(READ "${_f}" _content)
        string(REGEX REPLACE " +-lm\\b" "" _content "${_content}")
        file(WRITE "${_f}" "${_content}")
    endforeach()
    unset(_ipopt_pc_files)
    unset(_f)
    unset(_content)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
