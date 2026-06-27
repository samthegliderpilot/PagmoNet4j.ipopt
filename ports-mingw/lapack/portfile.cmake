# MinGW bridge: LAPACK is provided by MSYS2 OpenBLAS, which is already
# installed as a transitive dependency of mingw-w64-x86_64-mumps.
# This stub satisfies vcpkg's lapack dependency without building CLAPACK
# (which fails to compile with MinGW's GCC).
set(VCPKG_BUILD_TYPE release)

set(_msys2_lib "/c/msys64/mingw64/lib")
set(_msys2_inc "/c/msys64/mingw64/include")

# pkg-config for autotools consumers.
# Libs is intentionally EMPTY so that coinutils's configure detects lapack
# as "available" (pkg-config succeeds) but records no -L/-l library flags.
# When libtool creates libCoinUtils.la, it passes dependency flags to ar; with
# an empty Libs the coinutils link-test fails and coinutils skips lapack,
# preventing ar from receiving unknown -L flags. IPOPT gets the real lapack
# path from its own portfile's --with-lapack flag — coinutils doesn't need it.
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/lapack.pc"
"Name: lapack
Version: 3.11.0
Description: LAPACK bridge for MinGW (empty Libs to avoid libtool ar-lib issues)
Cflags: -I${_msys2_inc}
Libs:
")

# cmake config for cmake consumers (coinutils, pagmo2 cmake)
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/lapack")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/lapack/LapackConfig.cmake"
"set(LAPACK_FOUND TRUE)
set(LAPACK_LIBRARIES \"-lopenblas\")
set(LAPACK_LINKER_FLAGS \"-L/c/msys64/mingw64/lib\")
if(NOT TARGET LAPACK::LAPACK)
    add_library(LAPACK::LAPACK INTERFACE IMPORTED)
    target_link_options(LAPACK::LAPACK INTERFACE -L/c/msys64/mingw64/lib -lopenblas)
endif()
")

file(WRITE "${CURRENT_PACKAGES_DIR}/share/lapack/copyright"
    "Bridge port — MSYS2 OpenBLAS provides LAPACK on MinGW. See MSYS2 for license.")
