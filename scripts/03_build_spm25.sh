#!/bin/bash
# Step 3: fetch SPM25, apply the Octave fix, stamp the release version, and
# compile all MEX files for your Octave.
#
#   bash scripts/03_build_spm25.sh
#   SPM_TAG=25.01.02 SPM_DIR=$HOME/opt/spm25 OCTAVE_PREFIX=$HOME/opt/octave-11.3.0 bash scripts/03_build_spm25.sh
#
# Re-run this after every Octave upgrade (MEX files are Octave-version specific).
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
TAG=${SPM_TAG:-25.01.02}
SPM_DIR=${SPM_DIR:-$HOME/opt/spm25}
OCTAVE_PREFIX=${OCTAVE_PREFIX:-$HOME/opt/octave-11.3.0}
MKOCT=$OCTAVE_PREFIX/bin/mkoctfile
[ -x "$MKOCT" ] || { echo "mkoctfile not found at $MKOCT (set OCTAVE_PREFIX)"; exit 1; }

# 1. Source at the release tag
if [ ! -d "$SPM_DIR/.git" ]; then
  git clone -q --depth 1 --branch "$TAG" https://github.com/spm/spm.git "$SPM_DIR"
fi
cd "$SPM_DIR"

# 2. Octave fix: correct SPM window sizes (see patches/)
P=$HERE/patches/spm25_check_version_octave_online.patch
if git apply --check "$P" 2>/dev/null; then git apply "$P"; echo "Applied $(basename "$P")";
else echo "Patch already applied (or not needed)"; fi

# 3. Version stamp: the git tag has a 'Version 00.00' placeholder; the official
#    release zip carries the real one (spm('Version') -> 'SPM25 (25.01.02)').
if grep -q "Version 00.00" Contents.m; then
  T=$(mktemp -d)
  curl -fsSL -o "$T/spm.zip" "https://github.com/spm/spm/releases/download/$TAG/spm_$TAG.zip"
  unzip -p "$T/spm.zip" spm/Contents.m  > Contents.m
  unzip -p "$T/spm.zip" spm/Contents.txt > Contents.txt
  rm -r "$T"
fi
sed -n 2p Contents.m

# 4. Compile MEX files (core + external) with the system compiler, clean environment
E=(env -i HOME="$HOME" USER="$USER" PATH="$OCTAVE_PREFIX/bin:/usr/local/bin:/usr/bin:/bin" LANG=C.UTF-8)
cd src
L=$SPM_DIR/octave_mex_build.log
{ "${E[@]}" make PLATFORM=octave MEXBIN="$MKOCT" distclean
  "${E[@]}" make PLATFORM=octave MEXBIN="$MKOCT"
  "${E[@]}" make PLATFORM=octave MEXBIN="$MKOCT" install
  "${E[@]}" make PLATFORM=octave MEXBIN="$MKOCT" external
  "${E[@]}" make PLATFORM=octave MEXBIN="$MKOCT" external-install
} > "$L" 2>&1 || { echo "MEX build failed: see $L"; exit 1; }

echo "Octave MEX files: $(find "$SPM_DIR" -name '*.mex' | wc -l)   (expected 128 for 25.01.02)"
echo "SPM25 ready at $SPM_DIR.  In Octave:  addpath('$HERE/octave'); spm25_setup('$SPM_DIR')"
