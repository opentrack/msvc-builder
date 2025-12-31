#!busybox sh

set -euo pipefail

is_path_absolute() {
    case "$1" in
        \\\\*) return 0 ;; # UNC path: \\server\share
        [A-Za-z]:[\\/]*) return 0 ;; # Drive letter absolute: C:\ or C:/
        [\\/]*) return 0 ;; # POSIX absolute: /something
        *) return 1 ;; # Everything else is relative
    esac
}

self=$(basename -- "$0")
selfdir=$(dirname -- "$0")

is_path_absolute "$selfdir" || selfdir="$PWD/$selfdir"

which git cmake ninja patch realpath >/dev/null /dev/null

usage() {
    echo "$self [options] DIRECTORY

Usage:
 $self c:/work
 $self -T D:/dev/my-gcc.cmake -U D:/dev/my-full-build.cmake ./work
 $self -T d:/dev/opentrack/cmake/msvc.cmake -U userconfig.cmake d:/build

Build opentrack on win32 with all available dependencies.

Options:
 -T, --toolchain-file   toolchain file for cmake
 -u, --userconfig       cmake userconfig file for opentrack
 -h, --help             this screen

For more information please read the script."
}

usage_line() {
    echo "Try '$self --help' for usage information."
}

parsed=$(getopt -n "$self" -o T:u:h -l toolchain-file:,userconfig:,help -- "$@")
eval set -- "$parsed"

_got_tc=0
_got_uc=0
tc=
uc=

while :; do
    case "$1" in
        -T|--toolchain-file) tc="$2"; _got_tc=1; shift 2 ;;
        -u|--userconfig) uc="$2"; _got_uc=1; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) echo "$self: unknown option '$1'" >&2; usage_line >&2; exit 2 ;;
    esac
done

if test $# -ne 1; then
    echo "$self: expecting destination argument but $# arguments were given." >&2
    usage_line >&2
    exit 2
fi

basedir="$1"; shift
basedir=${basedir//\\/\/}
basedir=${basedir//\/\//\/}

case "$basedir" in
'')   echo "fatal: directory name is empty" >&2; false ;;
-*)   echo "fatal: directory name '$basedir' begins with a hyphen" >&2; false ;;
#*\ *) echo "fatal: directory name '$basedir' contains spaces" >&2; false ;;
*\;*) echo "fatal: directory name '$basedir' contains a semicolon" >&2; false ;;
esac

is_path_absolute "$basedir" || basedir="$PWD/$basedir"
test -d "$basedir" || mkdir "$basedir"
(cd "$basedir"; mkdir -p src build)
src="$basedir/src"
build="$basedir/build"

{ test $_got_tc -eq 0 && tc="$src/opentrack/cmake/msvc.cmake"; } || true
{ test $_got_uc -eq 0 && uc="$selfdir/userconfig.cmake"; } || true
#test $_got_tc -ne 0 || { echo 'fatal: toolchain file not given' >&2; usage_line >&2; exit 2; }
#test $_got_uc -ne 0 || { echo 'fatal: userconfig file not given' >&2; usage_line >&2; exit 2; }

mypatch() {
    local i dir="$1" type="$2"; test $# -eq 2
    for i in "$selfdir/$dir-$type"*".patch"; do
        if test "$i" = "$selfdir/$dir-$type*.patch" && ! test -f "$i"; then
            continue
        fi
        local stamp=".patch.done.$(basename "$i" .patch)"
        if ! test -e "$stamp"; then
            (patch -p0 --dry-run -i "$i") </dev/null >/dev/null
            (set -x; patch -p0 -i "$i") </dev/null
            touch "$stamp"
        fi
    done
}

gc() {
    local dir="$1"; shift
    local url="$1"; shift
    local branch="$1"; shift
    test $# -eq 0
    if ! test -e "$dir/.git"; then
        (set -x; git clone --recurse-submodules -b "$branch" "$@" "$url" "$dir")
    fi
}

cm1() {
    local s="$1" b="$2"; shift; shift;
    mkdir -p "$build/$b"
    local src_root="$src/$s"
    case "$src/$s" in
        */cmake|*/cmake/) local src_root="$(dirname "$src_root")" ;; # hack
    esac
    (name="$(basename "$src_root")"
     (cd "$src_root"; mypatch "$name" src)
     (S="$(realpath "$src/$s")"
      B="$(realpath "$build/$b")"
      I="$(realpath "$build/$b/install")"
      set -x
      cmake -Wno-dev -GNinja -S "$S" -B "$B" "$@" \
         -DCMAKE_TOOLCHAIN_FILE="$tc" -DCMAKE_INSTALL_PREFIX="$I")
     (cd "$build/$b"; mypatch "$name" build))
}

cm2() {
    local s="$1"; shift
    cm1 "$s" "$s" "$@"
}

build()  {
    local n="$1"; shift
    (cd "$(realpath "$build/$n")";
     if test $# -eq 0; then
        (set -x; ninja install)
     else
        (set -x; ninja "$@")
     fi)
}

(cd "$src"
 gc qt          git://code.qt.io/qt/qt5.git                     6.10.1
 gc onnxruntime https://github.com/microsoft/onnxruntime        v1.23.2
 gc opencv      https://github.com/opencv/opencv                4.x
 gc deps        https://github.com/opentrack/opentrack-depends  master
 gc libusb      https://github.com/libusb/libusb.git            master
 gc opentrack   https://github.com/opentrack/opentrack          wip-2026.1.0
)

(exec 99< "$tc") || { usage_line >&2; exit 3; }
(exec 99< "$uc") || { usage_line >&2; exit 3; }

is_path_absolute "$tc" || tc="$PWD/$tc"
is_path_absolute "$uc" || uc="$PWD/$uc"

test -d "$src/deps/nonfree"\
|| git clone https://github.com/opentrack/depends-nonfree "$src/deps/nonfree"\
|| mkdir "$src/deps/nonfree"

cm2 qt
build qt

#cm1 onnxruntime/cmake onnxruntime-avx \
#   -DFLAGS_C_RELEASE=-arch:AVX -DFLAGS_CXX_RELEASE=-arch:AVX
#build onnxruntime-avx

cm1 onnxruntime/cmake onnxruntime-noavx
build onnxruntime-noavx

cm2 opencv 
build opencv

cm1 deps/aruco aruco -DOpenCV_DIR="$build/opencv/install"
build aruco all

cm1 deps/oscpack oscpack
(cd "$build/oscpack"; test -h include || ln -Ts "$src/deps/oscpack" include)
build oscpack all

(cd "$src/libusb/msvc"
 test -f libusb.sln
 config=Release-MT
 if which msbuild >/dev/null 2>&1; then
    msbuild libusb.sln -t:libusb_dll -p:Configuration=Release -p:Platform=x64
    config=Release
 fi
 mkdir -p "$build/libusb"
 (cd "$src/libusb/build/v"[1-9]*"/x64/$config/dll"
  cp -fu libusb-1.0.dll libusb-1.0.exp  libusb-1.0.lib  libusb-1.0.pdb "$build/libusb/")
  cp -fu "$src/libusb/libusb/libusb.h" "$build/libusb/")

cm2 opentrack -Wdev -DSDK_ROOT="$basedir" -DOPENTRACK_USERCONFIG="$uc"
rm -rf "$build/opentrack/debug"
build opentrack
mv -fT "$build/opentrack/install/debug" "$build/opentrack/debug"

# eof
