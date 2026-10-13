#!/bin/bash
# Step 2: build and install GNU Octave natively from verified source.
#
#   bash scripts/02_build_octave.sh
#   OCTAVE_VERSION=11.3.0 PREFIX=$HOME/opt/octave-11.3.0 bash scripts/02_build_octave.sh
#
# Key choices (see docs/TROUBLESHOOTING.md for why):
#  * Clean environment (env -i): system gcc and libraries only; no Homebrew,
#    conda or FSL tools on PATH.
#  * Qt5 GUI: Ubuntu 22.04 has QScintilla only for Qt5.
#  * OpenMP OpenBLAS, linked via DT_RPATH so that ARPACK/SuiteSparse's own
#    libblas.so.3 lookups resolve to it as well. The default pthreads OpenBLAS
#    crashes Octave (eigs after Java has started). The system default BLAS is
#    not changed.
#  * Serial HDF5 explicitly (not the MPI variant).
set -euo pipefail

V=${OCTAVE_VERSION:-11.3.0}
PREFIX=${PREFIX:-$HOME/opt/octave-$V}
WORK=${WORK:-$HOME/opt/octave-build}
JOBS=${JOBS:-$(nproc)}
A=/usr/lib/x86_64-linux-gnu
JAVA_HOME_DIR=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")

[ -e "$A/openblas-openmp/libopenblas.so.0" ] || { echo "OpenMP OpenBLAS missing: run scripts/01_install_build_deps.sh"; exit 1; }

mkdir -p "$WORK" && cd "$WORK"
if [ ! -f "octave-$V.tar.xz" ]; then
  curl -fsSLO "https://ftp.gnu.org/gnu/octave/octave-$V.tar.xz"
  curl -fsSLO "https://ftp.gnu.org/gnu/octave/octave-$V.tar.xz.sig"
fi
# Verify the release signature (Octave maintainer key, John W. Eaton)
gpg --list-keys 5D36644B >/dev/null 2>&1 || gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 5D36644B
gpg --verify "octave-$V.tar.xz.sig" "octave-$V.tar.xz"

[ -d "octave-$V" ] || tar -xJf "octave-$V.tar.xz"
mkdir -p "build-$V" && cd "build-$V"

E=(env -i HOME="$HOME" USER="$USER" PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 JAVA_HOME="$JAVA_HOME_DIR")

echo "Configuring Octave $V -> $PREFIX"
"${E[@]}" "../octave-$V/configure" --prefix="$PREFIX" --with-qt=5 --disable-docs \
  --with-blas="-L$A/openblas-openmp -lopenblas" --with-hdf5="-lhdf5" \
  --with-hdf5-includedir=/usr/include/hdf5/serial --with-hdf5-libdir="$A/hdf5/serial" \
  CFLAGS="-O2 -march=native" CXXFLAGS="-O2 -march=native" FFLAGS="-O2 -march=native" \
  LDFLAGS="-Wl,--disable-new-dtags -Wl,-rpath,$A/openblas-openmp" > configure.log 2>&1 \
  || { echo "configure failed: see $PWD/configure.log"; exit 1; }
grep -E "Build Octave Qt GUI|BLAS libraries|HDF5 libraries" configure.log

echo "Compiling with $JOBS jobs (a few minutes on a modern desktop)..."
"${E[@]}" make -j"$JOBS" > make.log 2>&1 || { echo "make failed: see $PWD/make.log"; exit 1; }
"${E[@]}" make install > install.log 2>&1

"$PREFIX/bin/octave-cli" --no-init-file --eval 'disp(version); disp(version("-blas"))'
echo
echo "Installed to $PREFIX"
echo "Next: bash scripts/03_build_spm25.sh   and   bash scripts/04_install_launchers.sh"
echo "Optional full self-test (about 5 minutes):  OMP_WAIT_POLICY=PASSIVE $PREFIX/bin/octave-cli --eval __run_test_suite__"
