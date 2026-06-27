set(VCPKG_BUILD_TYPE release)

# Patch vcpkg's downloaded autotools ar-lib wrappers so libtool's -L/-l dependency
# flags are converted to --record-libdeps instead of being passed raw to ar.exe.
# GNU ar rejects -L/-l flags directly; --record-libdeps is the correct mechanism.
# By the time this portfile runs, bzip2/zlib have already triggered MSYS2 tool
# download, so the ar-lib files exist under downloads/tools/msys2/.
set(_ar_lib_content
"#!/bin/sh
AR=\$1; shift
libdeps=
ARGS=
for a; do
  case \$a in
    -L*|-l*) libdeps=\"\${libdeps:+\$libdeps }\$a\" ;;
    *) ARGS=\"\${ARGS:+\$ARGS }\$a\" ;;
  esac
done
if test -n \"\$libdeps\"; then
  exec \$AR \"--record-libdeps=\$libdeps\" \$ARGS
else
  exec \$AR \$ARGS
fi
")

file(GLOB _ar_lib_files
    "${VCPKG_ROOT}/downloads/tools/msys2/*/usr/bin/ar-lib"
    "${VCPKG_ROOT}/downloads/tools/msys2/*/usr/share/automake-*/ar-lib")
foreach(_f IN LISTS _ar_lib_files)
    file(WRITE "${_f}" "${_ar_lib_content}")
    message(STATUS "Patched ar-lib: ${_f}")
endforeach()
unset(_ar_lib_files _f _ar_lib_content)

# Delegate to vcpkg's standard coinutils portfile.
# cmake's include() sets CMAKE_CURRENT_LIST_DIR to the included file's directory,
# so patches referenced therein are resolved relative to the standard port.
include("${VCPKG_ROOT}/ports/coinutils/portfile.cmake")
