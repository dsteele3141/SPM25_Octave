# Validation results

**Test system:** Linux Mint 21.3 (Ubuntu 22.04, glibc 2.35), Intel i7-13700 (8P + 8E cores, 24 threads).
**Software:** GNU Octave 11.3.0 built with `scripts/02_build_octave.sh`, SPM 25.01.02 built with `scripts/03_build_spm25.sh`, compared with MATLAB R2026a running the same SPM25 folder (using SPM's shipped `.mexa64` files).

## 1. Octave's own test suite

```
PASS                            22330
FAIL                                0
XFAIL (reported bug)               33
SKIP (missing feature)             54
SKIP (run-time condition)          44
```

The XFAILs are bugs already reported upstream. The missing-feature skips are mainly audio, because PortAudio isn't built by default.

## 2. SPM25 unified segmentation: Octave vs MATLAB

Input: SPM's `canonical/single_subj_T1.nii`. Settings: SPM defaults (`seg_job.m`, which runs in both Octave and MATLAB).

| Tissue | Octave 11.3 | MATLAB R2026a | Difference | Voxel r | Dice (>0.5) |
|---|---|---|---|---|---|
| Grey matter | 1022.4 ml | 1023.0 ml | −0.05% | 0.99997 | 0.9988 |
| White matter | 544.0 ml | 544.7 ml | −0.12% | 0.99997 | 0.9986 |
| CSF | 361.5 ml | 360.3 ml | +0.33% | 0.99991 | 0.9965 |

- **Deformation field:** mean difference 0.025 mm, 99th percentile 0.09 mm, maximum 0.29 mm.
- **Run time:** Octave 34 s (with the launcher's OpenMP settings) vs MATLAB 44 s.
- **Repeatability:** repeated Octave runs are bit-identical.

The small Octave/MATLAB differences come from different numerical libraries inside an iterative optimisation. They aren't errors, but **don't mix Octave- and MATLAB-processed subjects within one study.**

## 3. Other checks

- `spm_vol` / `spm_read_vols` match nibabel exactly: zero difference in data and affine.
- The MEX routines `spm_slice_vol`, `spm_smooth`, `spm_bsplinc` and `spm_bsplins` were checked against direct computation.
- The batch system ran a smoothing job through `spm_jobman`.
- **GUI** (Octave Qt GUI): `spm fmri` and its buttons, `spm_image`, `spm_check_registration` including coloured overlays, `spm_select`, and `spm_jobman('interactive')` all work, with correct window sizes after the patch in `patches/`.

## Reproduce

```bash
mkdir -p octave matlab
cp ~/opt/spm25/canonical/single_subj_T1.nii octave/
cp ~/opt/spm25/canonical/single_subj_T1.nii matlab/
octave-cli --eval "addpath('../octave'); spm25_setup('~/opt/spm25'); seg_job([pwd '/octave'])"
matlab -batch "addpath('~/opt/spm25'); seg_job([pwd '/matlab'])"
python3 compare_segmentations.py octave matlab
```
