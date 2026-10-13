function seg_job(d)
% SPM25 unified segmentation with default settings, same in MATLAB and Octave
spm('defaults', 'fmri'); spm_jobman('initcfg');
tpm = fullfile(spm('dir'), 'tpm', 'TPM.nii');
matlabbatch{1}.spm.spatial.preproc.channel.vols = {fullfile(d, 'single_subj_T1.nii,1')};
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 0];
ngaus = [1 1 2 3 4 2];
for k = 1:6
  matlabbatch{1}.spm.spatial.preproc.tissue(k).tpm = {sprintf('%s,%d', tpm, k)};
  matlabbatch{1}.spm.spatial.preproc.tissue(k).ngaus = ngaus(k);
  matlabbatch{1}.spm.spatial.preproc.tissue(k).native = [k <= 3, 0];
  matlabbatch{1}.spm.spatial.preproc.tissue(k).warped = [0 0];
end
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1];
tic; spm_jobman('run', matlabbatch); fprintf('SEGMENT_DONE %.0f s\n', toc);
end
