set(VCPKG_BUILD_TYPE release)

# By the time this portfile runs, bzip2/zlib have already triggered MSYS2 tool
# download. Patch ALL ar-lib scripts in vcpkg's downloaded tools so that libtool's
# -L/-l dependency flags are stripped before reaching ar.exe, which rejects them.
# We patch both usr/bin/ar-lib (always in PATH) and usr/share/automake-*/ar-lib
# (which vcpkg may prepend to PATH with higher priority).
set(_ar_lib_content
"#!/bin/sh
# ar-lib for MinGW: strip -L/-l linker flags before calling ar.
# libtool passes these as library dependency metadata; GNU ar rejects them.
AR=\$1; shift
ARGS=
for a; do
  case \$a in
    -L*|-l*) ;; # strip linker flags - not valid for ar
    *) ARGS=\"\${ARGS:+\$ARGS }\$a\" ;;
  esac
done
exec \$AR \$ARGS
")

file(GLOB _ar_lib_files
    "${VCPKG_ROOT_DIR}/downloads/tools/msys2/*/usr/bin/ar-lib"
    "${VCPKG_ROOT_DIR}/downloads/tools/msys2/*/usr/share/automake-*/ar-lib")
foreach(_f IN LISTS _ar_lib_files)
    file(WRITE "${_f}" "${_ar_lib_content}")
    message(STATUS "Patched ar-lib: ${_f}")
endforeach()
unset(_ar_lib_files)
unset(_f)
unset(_ar_lib_content)

# Delegate to vcpkg's standard coinutils portfile.
# cmake's include() sets CMAKE_CURRENT_LIST_DIR to the included file's directory
# so patches in that directory are resolved correctly.
include("${VCPKG_ROOT_DIR}/ports/coinutils/portfile.cmake")
