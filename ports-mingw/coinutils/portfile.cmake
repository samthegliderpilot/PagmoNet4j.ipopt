set(VCPKG_BUILD_TYPE release)

set(_ar_lib_content "#!/bin/sh\nAR=\$1\nshift\nARGS=\nfor a; do\n  case \$a in\n    -L*|-l*) ;;\n    *) ARGS=\"\${ARGS:+\$ARGS }\$a\" ;;\n  esac\ndone\nexec \$AR \$ARGS\n")
file(GLOB _ar_lib_files
    "${VCPKG_ROOT_DIR}/downloads/tools/msys2/*/usr/bin/ar-lib"
    "${VCPKG_ROOT_DIR}/downloads/tools/msys2/*/usr/share/automake-*/ar-lib")
foreach(_f IN LISTS _ar_lib_files)
    file(WRITE "${_f}" "${_ar_lib_content}")
    message(STATUS "[coinutils-mingw] Patched ar-lib: ${_f}")
endforeach()
unset(_ar_lib_files)
unset(_f)
unset(_ar_lib_content)

# vcpkg resolves PATCHES arguments relative to the REGISTERED port directory
# (our overlay), not CMAKE_CURRENT_LIST_DIR of the included file. Copy all
# patch files from the standard coinutils port into our overlay so that when
# the included standard portfile calls vcpkg_from_github(...PATCHES...), vcpkg
# can find them here.
file(GLOB _std_patches "${VCPKG_ROOT_DIR}/ports/coinutils/*.patch")
foreach(_p IN LISTS _std_patches)
    get_filename_component(_pname "${_p}" NAME)
    configure_file("${_p}" "${CMAKE_CURRENT_LIST_DIR}/${_pname}" COPYONLY)
endforeach()
unset(_std_patches)
unset(_p)
unset(_pname)

# Delegate to vcpkg's standard coinutils portfile.
include("${VCPKG_ROOT_DIR}/ports/coinutils/portfile.cmake")
