#!/usr/bin/env python3
"""Compare SPM unified-segmentation outputs from two runs (e.g. Octave vs MATLAB).

Usage:  python3 compare_segmentations.py <dirA> <dirB> [basename]
        (default basename: single_subj_T1)
Needs: numpy, nibabel
"""
import sys
import numpy as np
import nibabel as nib

a_dir, b_dir = sys.argv[1], sys.argv[2]
base = sys.argv[3] if len(sys.argv) > 3 else "single_subj_T1"

for c, name in [(1, "grey matter"), (2, "white matter"), (3, "CSF")]:
    ia = nib.load(f"{a_dir}/c{c}{base}.nii")
    a = ia.get_fdata()
    b = nib.load(f"{b_dir}/c{c}{base}.nii").get_fdata()
    ml = abs(np.linalg.det(ia.affine[:3, :3])) / 1000
    ma, mb = a > 0.5, b > 0.5
    print(f"{name:12s}  A {a.sum()*ml:7.1f} ml  B {b.sum()*ml:7.1f} ml  "
          f"({100*(a.sum()-b.sum())/b.sum():+.3f}%)  "
          f"r = {np.corrcoef(a.ravel(), b.ravel())[0, 1]:.6f}  "
          f"Dice(>0.5) = {2*(ma & mb).sum()/(ma.sum()+mb.sum()):.5f}")

ya = nib.load(f"{a_dir}/y_{base}.nii").get_fdata()
yb = nib.load(f"{b_dir}/y_{base}.nii").get_fdata()
d = np.sqrt(((ya - yb) ** 2).sum(axis=-1)).squeeze()
print(f"deformation field: mean difference {d.mean():.4f} mm, "
      f"99th percentile {np.percentile(d, 99):.4f} mm, max {d.max():.4f} mm")
