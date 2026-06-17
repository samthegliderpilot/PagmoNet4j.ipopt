vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO coin-or/Ipopt
    REF ec43e37a06054246764fb116e50e3e30c9ada089
    SHA512 f5b30e81b4a1a178e9a0e2b51b4832f07441b2c3e9a2aa61a6f07807f94185998e985fcf3c34d96fbfde78f07b69f2e0a0675e1e478a4e668da6da60521e0fd6
    HEAD_REF master
)

file(COPY "${CURRENT_INSTALLED_DIR}/share/coin-or-buildtools/" DESTINATION "${SOURCE_PATH}")

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
    set(LAPACK_OPTION "--with-lapack=-L/c/msys64/mingw64/lib -lopenblas")
    set(CXXLIBS_OPTION "CXXLIBS=")
else()
    # Linux/macOS: MUMPS is provided by the coin-or-mumps bridge port, which
    # writes coinmumps.pc into ${CURRENT_INSTALLED_DIR}/lib/pkgconfig.
    # vcpkg_configure_make automatically adds that dir to PKG_CONFIG_PATH.
    # Belt-and-suspenders: also set the env vars that AC_COIN_CHK_PKG reads
    # when pkg-config fails (both naming conventions).
    if(VCPKG_TARGET_IS_OSX)
        find_program(_brew NAMES brew HINTS /opt/homebrew/bin /usr/local/bin)
        execute_process(
            COMMAND "${_brew}" --prefix mumps
            OUTPUT_VARIABLE _mumps_prefix
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        execute_process(
            COMMAND "${_brew}" --prefix gcc
            OUTPUT_VARIABLE _gcc_prefix
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        set(_gfortran_ldflags "")
        file(GLOB _gfortran_dirs "${_gcc_prefix}/lib/gcc/*")
        foreach(_d IN LISTS _gfortran_dirs)
            if(IS_DIRECTORY "${_d}" AND EXISTS "${_d}/libgfortran.a")
                set(_gfortran_ldflags " -L${_d}")
                break()
            endif()
        endforeach()
        set(_mumps_cflags "-I${_mumps_prefix}/include")
        set(_mumps_libs "-L${_mumps_prefix}/lib -ldmumps -lmumps_common${_gfortran_ldflags} -lgfortran -lopenblas")
    else()
        find_library(_dmumps_lib NAMES dmumps
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
        set(_mumps_cflags "-I/usr/include")
        set(_mumps_libs "-L${_mumps_lib_dir} -ldmumps -lmumps_common -lopenblas -lgfortran")
    endif()

    set(ENV{MUMPS_CFLAGS} "${_mumps_cflags}")
    set(ENV{MUMPS_LIBS} "${_mumps_libs}")
    set(ENV{COINMUMPS_CFLAGS} "${_mumps_cflags}")
    set(ENV{COINMUMPS_LIBS} "${_mumps_libs}")

    set(_mumps_option "--with-mumps")
    set(LAPACK_OPTION "--with-lapack=-lopenblas")
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
