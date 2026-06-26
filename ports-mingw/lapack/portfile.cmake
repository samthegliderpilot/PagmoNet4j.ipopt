# MinGW bridge: LAPACK is provided by MSYS2 OpenBLAS, which is already
# installed as a transitive dependency of mingw-w64-x86_64-mumps.
# This stub satisfies vcpkg's lapack dependency without building CLAPACK
# (which fails to compile with MinGW's GCC).
set(VCPKG_BUILD_TYPE release)

set(_msys2_lib "/c/msys64/mingw64/lib")
set(_msys2_inc "/c/msys64/mingw64/include")

# pkg-config for autotools consumers (coinutils configure, ipopt configure)
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/lapack.pc"
"Name: lapack
Version: 3.11.0
Description: LAPACK via MSYS2 OpenBLAS (MinGW bridge)
Cflags: -I${_msys2_inc}
Libs: -L${_msys2_lib} -lopenblas
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
