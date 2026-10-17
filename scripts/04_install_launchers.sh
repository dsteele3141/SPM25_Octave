#!/bin/bash
# Step 4: install 'octave' / 'octave-cli' launchers that set OpenMP options
# before Octave starts, plus a desktop menu entry for the GUI.
#
#   bash scripts/04_install_launchers.sh
#   OCTAVE_PREFIX=$HOME/opt/octave-11.3.0 BIN_DIR=$HOME/.local/bin bash scripts/04_install_launchers.sh
#
# Why: with OpenMP's default spin-waiting, idle BLAS threads burn CPU and some
# operations become 10-20x slower (e.g. eig of a 2000x2000 matrix: 104 s vs 6 s).
# OMP_WAIT_POLICY=PASSIVE fixes this; one thread per physical core avoids
# hyper-thread contention. Both must be set before Octave starts.
# The launchers also clear QT_XCB_GL_INTEGRATION (set by conda; see
# docs/TROUBLESHOOTING.md), which otherwise gives blank/black figure windows.
set -euo pipefail

OCTAVE_PREFIX=${OCTAVE_PREFIX:-$HOME/opt/octave-11.3.0}
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}
mkdir -p "$BIN_DIR"

for b in octave octave-cli; do
  cat > "$BIN_DIR/$b" <<EOF
#!/bin/bash
# Launcher for $OCTAVE_PREFIX/bin/$b (installed by SPM25_Octave/scripts/04_install_launchers.sh)
# OpenMP settings must be set before start-up; override per run, e.g. OMP_NUM_THREADS=1 $b
cores=\$(lscpu -p=core,socket 2>/dev/null | grep -v '^#' | sort -u | wc -l)
[ "\${cores:-0}" -gt 0 ] || cores=\$(nproc)
export OMP_WAIT_POLICY=\${OMP_WAIT_POLICY:-PASSIVE}
export OMP_NUM_THREADS=\${OMP_NUM_THREADS:-\$cores}
# A conda environment active in the desktop session (e.g. base activated from
# /etc/profile.d) sets QT_XCB_GL_INTEGRATION=none, which leaves figure windows
# blank or black. Octave's own Qt needs OpenGL, so clear it.
unset QT_XCB_GL_INTEGRATION
exec "$OCTAVE_PREFIX/bin/$b" "\$@"
EOF
  chmod +x "$BIN_DIR/$b"
done

# Desktop menu entry (overrides any system "GNU Octave" entry for this user)
APPS=$HOME/.local/share/applications; mkdir -p "$APPS"
sed -e "s#^Exec=.*#Exec=$BIN_DIR/octave --gui %f#" -e "s#^TryExec=.*#TryExec=$BIN_DIR/octave#" \
    -e "s#^Icon=octave#Icon=$OCTAVE_PREFIX/share/icons/hicolor/scalable/apps/octave.svg#" \
    "$OCTAVE_PREFIX/share/applications/org.octave.Octave.desktop" > "$APPS/org.octave.Octave.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true

echo "Launchers installed in $BIN_DIR. Make sure it comes first on PATH, e.g. add to ~/.bashrc:"
echo "  export PATH=$BIN_DIR:$OCTAVE_PREFIX/bin:\$PATH"
