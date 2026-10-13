#!/bin/bash
# Step 1: install the Ubuntu packages needed to build GNU Octave from source.
# Tested on Ubuntu 22.04 / Linux Mint 21.3. Needs sudo.
#
#   bash scripts/01_install_build_deps.sh
#   WITH_PORTAUDIO=1 bash scripts/01_install_build_deps.sh   # also audioplayer/audiorecorder
#
# Safety:
#  * Nothing already installed is removed: a dry run lists any conflicting
#    packages and the script stops unless ALLOW_REMOVE=1 is set.
#  * The system BLAS/LAPACK and HDF5 defaults (update-alternatives) are recorded
#    first and restored afterwards, so other software (e.g. R) is unaffected.
#    Installing libsundials-dev pulls in MPI-HDF5 and would otherwise switch the
#    system HDF5 default to the MPI variant.
#  * portaudio19-dev is optional because on many desktops it pulls libjack-dev,
#    which replaces the JACK library used by media players.
set -euo pipefail

alts="libblas.so.3-x86_64-linux-gnu liblapack.so.3-x86_64-linux-gnu libopenblas.so.0-x86_64-linux-gnu hdf5.pc"
declare -A before
for a in $alts; do
  before[$a]=$(update-alternatives --query "$a" 2>/dev/null | awk '/^Value:/{print $2}' || true)
done

pkgs=(
  build-essential gfortran gperf flex bison texinfo rapidjson-dev
  libopenblas-dev libopenblas0-openmp libopenblas-openmp-dev
  libarpack2-dev libqrupdate-dev libsuitesparse-dev libfftw3-dev libglpk-dev
  libhdf5-dev libcurl4-openssl-dev libgraphicsmagick++1-dev libgl2ps-dev
  libfltk1.3-dev libfontconfig1-dev libfreetype-dev libgl-dev libglu1-mesa-dev
  libosmesa6-dev libpcre2-dev libreadline-dev libsndfile1-dev libqhull-dev
  libsundials-dev libxft-dev zlib1g-dev libbz2-dev
  qtbase5-dev qttools5-dev qttools5-dev-tools libqt5opengl5-dev libqscintilla2-qt5-dev
  default-jdk-headless git curl gpg unzip
)
command -v pkg-config >/dev/null || pkgs+=(pkgconf)
[ "${WITH_PORTAUDIO:-0}" = 1 ] && pkgs+=(portaudio19-dev)

sudo apt-get update

# Dry run first: report any package apt would have to REMOVE (conflicts), and
# stop unless the user explicitly allows it. Example seen in testing: an old
# manually installed libjpeg62-dev conflicts with libjpeg-dev (needed by HDF5).
removals=$(apt-get install -s "${pkgs[@]}" 2>/dev/null | awk '/^Remv/{print $2}')
if [ -n "$removals" ]; then
  echo
  echo "Installing the build dependencies would REMOVE these installed packages:"
  printf '   %s\n' $removals
  echo "Check nothing you need depends on them:  apt-cache rdepends --installed <package>"
  if [ "${ALLOW_REMOVE:-0}" != 1 ]; then
    echo "Nothing has been changed. To proceed anyway, re-run with:  ALLOW_REMOVE=1 bash $0"
    exit 1
  fi
  echo "ALLOW_REMOVE=1 set: proceeding."
  sudo apt-get install -y "${pkgs[@]}"
else
  sudo apt-get install -y --no-remove "${pkgs[@]}"
fi

# Restore previous defaults (only where one existed before)
for a in $alts; do
  [ -n "${before[$a]}" ] && sudo update-alternatives --set "$a" "${before[$a]}" >/dev/null
done
# Fresh systems with no previous HDF5 default: prefer the serial build
if [ -z "${before[hdf5.pc]}" ] && [ -e /usr/lib/x86_64-linux-gnu/pkgconfig/hdf5-serial.pc ]; then
  sudo update-alternatives --set hdf5.pc /usr/lib/x86_64-linux-gnu/pkgconfig/hdf5-serial.pc >/dev/null || true
fi

# Octave links the serial HDF5 libraries: protect them from 'apt autoremove'
sudo apt-mark manual libhdf5-dev 'libhdf5-103*' 'libhdf5-cpp-103*' 'libhdf5-hl-100*' > /dev/null 2>&1 || true

echo "Build dependencies installed. Next: bash scripts/02_build_octave.sh"
