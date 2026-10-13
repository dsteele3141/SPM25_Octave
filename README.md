# SPM25_Octave

Run **SPM25** (Statistical Parametric Mapping) in **GNU Octave 11** on Linux. This covers the graphical interface as well as scripts and batches, and results have been checked against MATLAB.

SPM's own documentation still covers Octave only for SPM12. This repository provides tested scripts to:

1. build a fast, stable Octave natively from verified source,
2. fetch SPM25, apply a small Octave fix, stamp the correct release version, and compile all MEX files,
3. launch Octave with the right threading settings,
4. validate the result against MATLAB.

SPM itself isn't included: the scripts download it from the official [spm/spm](https://github.com/spm/spm) repository.

## Status

- **Tested on:** Ubuntu 22.04 / Linux Mint 21.3, with Octave 11.3.0 and SPM 25.01.02. Tested on two computers (Intel i7-13700 and AMD Ryzen 7 3700X); the second was a fresh install using only these scripts.
- **Octave test suite:** 22,330 passed, 0 failed (22,329 / 0 on the AMD computer).
- **Same results on both computers:** the segmentation tissue maps are byte-for-byte identical.
- **SPM25 segmentation vs MATLAB R2026a:** grey/white matter/CSF volumes within 0.05/0.12/0.33%, r > 0.9999. Octave took 34 s, MATLAB 44 s. Details are in [validation/RESULTS.md](validation/RESULTS.md).
- **GUI:** `spm fmri`, Display, Check Reg, overlays, file selector and the batch editor all work.

## Quick start

```bash
git clone https://github.com/dsteele3141/SPM25_Octave.git
cd SPM25_Octave
bash scripts/01_install_build_deps.sh   # Ubuntu packages (sudo); changes no system defaults
bash scripts/02_build_octave.sh         # Octave 11.3.0 -> ~/opt/octave-11.3.0 (a few minutes)
bash scripts/03_build_spm25.sh          # SPM 25.01.02  -> ~/opt/spm25
bash scripts/04_install_launchers.sh    # 'octave' launchers + menu entry -> ~/.local/bin
```

Put the launchers first on your PATH (for example in `~/.bashrc`):

```bash
export PATH=$HOME/.local/bin:$HOME/opt/octave-11.3.0/bin:$PATH
```

Then, in Octave (GUI from the menu, or `octave` in a terminal):

```octave
addpath('/path/to/SPM25_Octave/octave')
spm25_setup('~/opt/spm25')      % -> "SPM25 (25.01.02) ready"
spm fmri
```

All locations can be changed with environment variables (`PREFIX`, `OCTAVE_VERSION`, `SPM_DIR`, `SPM_TAG`, `OCTAVE_PREFIX`, `BIN_DIR`); see the top of each script.

## Contents

| Path | What it is |
|---|---|
| `scripts/01_install_build_deps.sh` | Build dependencies. Uses `--no-remove`, and keeps the system BLAS/HDF5 defaults unchanged |
| `scripts/02_build_octave.sh` | Signature-verified Octave source build: Qt5 GUI, OpenMP OpenBLAS via RPATH, serial HDF5 |
| `scripts/03_build_spm25.sh` | SPM25 clone, the Octave patch, the release version stamp, and all 128 MEX files |
| `scripts/04_install_launchers.sh` | `octave`/`octave-cli` launchers (`OMP_WAIT_POLICY=PASSIVE`, one thread per physical core) and the desktop entry |
| `patches/` | Fix for small/misplaced SPM windows under Octave (already in SPM main) |
| `octave/spm25_setup.m` | Puts SPM25 on the path after removing any other SPM version |
| `tools/nii_view.m`, `tools/nii_read.m` | A small SPM-style orthogonal NIfTI viewer and reader that don't need SPM (`.nii`/`.nii.gz`) |
| `validation/` | Octave-vs-MATLAB segmentation test, comparison script and results |
| `docs/TROUBLESHOOTING.md` | Why each step is needed: crashes, slowdowns and package-manager pitfalls |

## Notes

- Results from Octave and MATLAB agree closely but aren't bit-identical, because they use different numerical libraries. Process all subjects of a study with the same software.
- Re-run `03_build_spm25.sh` after any Octave upgrade, because MEX files are specific to the Octave version.
- Other distributions should work with equivalent packages. The build options and the reasons for them are in the scripts and in `docs/TROUBLESHOOTING.md`.

## Acknowledgements

SPM is developed by the SPM team at the Department of Imaging Neuroscience (formerly the Wellcome Centre for Human Neuroimaging), UCL Queen Square Institute of Neurology. Their Octave support in the SPM code and build system made this possible, and the Octave fix used here is already in SPM's main branch. GNU Octave is developed by John W. Eaton and the Octave community. This repository only packages, patches and validates their work for a native Octave 11 installation.

## Licence

The scripts and tools in this repository are under the MIT Licence (see `LICENSE`). SPM is © the SPM developers under GPL-2.0-or-later and isn't redistributed here. The patch in `patches/` modifies SPM and is provided under SPM's licence.

## Citation

If this helps your work, please cite SPM itself and, optionally, this repository (see `CITATION.cff`).
