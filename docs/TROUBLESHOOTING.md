# Troubleshooting and background

These problems were all hit while setting this up on Ubuntu 22.04 / Linux Mint 21.3. The scripts handle each one, and this page explains why.

## Octave crashes (segmentation fault) in `eigs` or other linear algebra

**Symptom:** Octave dies with a segfault, typically in `eigs`, but only after Java has started in the session (any `javaObject`, some file readers, the full test suite).

**Cause:** Ubuntu's default OpenBLAS is the *pthreads* build. Octave is built with OpenMP. Running a multithreaded pthreads OpenBLAS in a process where Java has started crashes. The OpenBLAS project advises using the OpenMP build in OpenMP programs.

**Fix (in `02_build_octave.sh`):** link Octave to `/usr/lib/x86_64-linux-gnu/openblas-openmp` using `DT_RPATH` (`-Wl,--disable-new-dtags -Wl,-rpath,...`). An ordinary `RUNPATH` isn't enough, because ARPACK and SuiteSparse load `libblas.so.3` themselves; `DT_RPATH` makes those lookups resolve to the OpenMP build too. The system-wide default BLAS (used by R and others) is unchanged.

**Check:** `version -blas` in Octave must mention `USE_OPENMP`.

## Some operations are 10–20× slower than expected

**Symptom:** `eig`, `eigs` and sparse solves take far longer than they should, and `top` shows Octave using many cores while getting little done.

**Cause:** OpenMP's default wait policy makes idle threads *spin*. On a desktop CPU with many cores this wastes most of the time on small and medium problems. Measured examples:
- `eig` of a 2000×2000 matrix: 104 s, against 6 s with the fix
- the `eigs` tests: 15 s, against 0.4 s
- SPM25 segmentation: 58 s, against 34 s

**Fix (in `04_install_launchers.sh`):** start Octave with `OMP_WAIT_POLICY=PASSIVE` and `OMP_NUM_THREADS` = the number of physical cores. Both must be set **before** Octave starts; setting them inside Octave is too late.

## SPM windows are small and stuck in the bottom-left corner

**Cause:** a bug in SPM25 under Octave. `spm_check_version('matlab','online')` returns true because of an Octave shortcut in the same function, so SPM thinks it's running in *MATLAB Online* and halves the screen size when placing its windows.

**Fix:** `patches/spm25_check_version_octave_online.patch`, which `03_build_spm25.sh` applies. SPM's main branch (26.10) already includes the same fix.

## `spm('Version')` says "SPM25 (00.00)"

**Cause:** the git tag contains a placeholder. The real version line is only written into the official release zip.

**Fix:** `03_build_spm25.sh` copies `Contents.m`/`Contents.txt` from the release zip, so SPM reports `SPM25 (25.01.02)` and writes the right version into logs and `SPM.mat` files.

## Package-manager Octave builds that didn't work (why build from source)

- **Homebrew Octave on Ubuntu 22.04:**
  - It was built without X11 support (Wayland only), so it has no GUI or interactive figures on an X11 desktop.
  - Its `mkoctfile` expects `g++-12`.
  - Current Homebrew packages need glibc ≥ 2.38, and a Homebrew that hasn't been updated can install packages that won't start.
- **Ubuntu's Octave package:** 6.4, too old. Its `gunzip` also **deletes the original `.gz` file**, so never use it on data. (`tools/nii_read.m` uses `gzip -dc` instead.)
- **Flatpak Octave** works and has a GUI, but it can't easily compile MEX files against system libraries (you need the matching SDK) and it's isolated from the host.

## Installing the build dependencies changed my system HDF5

Installing `libsundials-dev` pulls in MPI-enabled HDF5, and Ubuntu then makes the MPI variant the default. `01_install_build_deps.sh` records the defaults beforehand and restores them afterwards, and `02_build_octave.sh` points Octave at the serial HDF5 explicitly. The serial HDF5 libraries are marked as manually installed: **don't let `apt autoremove` remove them**, because Octave links against them.

## No `audioplayer` / `audiorecorder`

PortAudio is optional (`WITH_PORTAUDIO=1`). On many desktops `portaudio19-dev` pulls in `libjack-dev`, which *replaces* the JACK library that VLC/mpv/GStreamer depend on. `audioread`/`audiowrite` work regardless.

## GCC 15 errors when compiling SPM ("too many arguments to function")

This only happens if you compile with a non-system GCC 15 (for example from Homebrew), because its default C23 standard rejects SPM's older C. Use the system GCC (as the scripts do), or add `CFLAGS="-std=gnu17"`.

## Step 1 stops: "would REMOVE these installed packages"

`01_install_build_deps.sh` does a dry run first and never removes anything unless you allow it. One case seen in testing: an old, manually installed **`libjpeg62-dev`** conflicts with `libjpeg-dev`, which HDF5, GraphicsMagick and SUNDIALS need.
- Removing a `-dev` package doesn't affect installed programs; their runtime libraries stay. It only matters if you later compile something that needs those specific headers.
- Check with `apt-cache rdepends --installed <package>`, then re-run with `ALLOW_REMOVE=1`.
