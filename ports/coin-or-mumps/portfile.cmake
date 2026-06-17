# Bridge port: does not build MUMPS from source.
# Creates a coinmumps.pc pointing to the system/MSYS2-installed MUMPS so that
# IPOPT's AC_COIN_CHK_PKG([MUMPS],...,[coinmumps]) succeeds via pkg-config.
#
# Prerequisites (installed before vcpkg runs):
#   Linux:   apt-get install libmumps-dev
#   macOS:   brew install mumps
#   Windows: C:\msys64\usr\bin\pacman.exe -S --noconfirm mingw-w64-x86_64-mumps

set(VCPKG_BUILD_TYPE release)

if(VCPKG_TARGET_IS_OSX)
    find_program(_brew NAMES brew HINTS /opt/homebrew/bin /usr/local/bin)
    if(NOT _brew)
        message(FATAL_ERROR "Homebrew not found. Install Homebrew, then: brew install mumps")
    endif()
    execute_process(
        COMMAND "${_brew}" --prefix mumps
        OUTPUT_VARIABLE _mumps_prefix
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _brew_rc
        ERROR_QUIET)
    if(_brew_rc OR NOT _mumps_prefix OR NOT EXISTS "${_mumps_prefix}")
        message(FATAL_ERROR "MUMPS not found via Homebrew. Run: brew install mumps")
    endif()

    execute_process(
        COMMAND "${_brew}" --prefix gcc
        OUTPUT_VARIABLE _gcc_prefix
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET)
    file(GLOB _gfortran_dirs "${_gcc_prefix}/lib/gcc/*")
    set(_gfortran_ldflags "")
    foreach(_d IN LISTS _gfortran_dirs)
        if(IS_DIRECTORY "${_d}" AND EXISTS "${_d}/libgfortran.a")
            string(APPEND _gfortran_ldflags " -L${_d}")
            break()
        endif()
    endforeach()

    set(_mumps_inc "${_mumps_prefix}/include")
    set(_mumps_libs
        "-L${_mumps_prefix}/lib -ldmumps -lmumps_common${_gfortran_ldflags} -lgfortran -lopenblas")

elseif(VCPKG_TARGET_IS_LINUX)
    set(_mumps_inc "/usr/include")
    find_library(_dmumps_lib NAMES dmumps
        HINTS
            /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
            /usr/lib/x86_64-linux-gnu
            /usr/lib/aarch64-linux-gnu
            /usr/lib
        NO_DEFAULT_PATH)
    if(NOT _dmumps_lib)
        message(FATAL_ERROR
            "libdmumps not found. Install it first: apt-get install libmumps-dev")
    endif()
    get_filename_component(_mumps_lib_dir "${_dmumps_lib}" DIRECTORY)
    set(_mumps_libs
        "-L${_mumps_lib_dir} -ldmumps -lmumps_common -lopenblas -lgfortran")

elseif(VCPKG_TARGET_IS_WINDOWS)
    # Use pre-built MUMPS from the system MSYS2/MinGW64 installation.
    # Install it before running the build:
    #   C:\msys64\usr\bin\pacman.exe -S --noconfirm mingw-w64-x86_64-mumps
    set(_msys2_root "C:/msys64/mingw64")
    if(NOT EXISTS "${_msys2_root}/include/dmumps_c.h")
        message(FATAL_ERROR
            "MUMPS not found at ${_msys2_root}/include. "
            "Install via: C:\\msys64\\usr\\bin\\pacman.exe -S --noconfirm mingw-w64-x86_64-mumps")
    endif()
    # Use MSYS2 POSIX paths (/c/msys64/...) because coinmumps.pc is consumed
    # inside vcpkg's MSYS2 autotools build environment.
    set(_mumps_inc "/c/msys64/mingw64/include")
    set(_mumps_libs "-L/c/msys64/mingw64/lib -ldmumps -lmumps_common -lpord -lgfortran -lopenblas")

else()
    message(FATAL_ERROR "coin-or-mumps bridge port: unsupported platform.")
endif()

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/coinmumps.pc"
"Name: coinmumps
Description: MUMPS sparse direct solver (system bridge for COIN-OR IPOPT)
Version: 1.0
Cflags: -I${_mumps_inc}
Libs: ${_mumps_libs}
")

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/include/coin-or")

file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright"
    "Bridge port — system MUMPS is used. See your system package manager for license details.")
