function spm25_setup (spm_dir)
  ## SPM25_SETUP  Put SPM25 on the Octave path and initialise it.
  ##
  ##   spm25_setup ('~/opt/spm25')
  ##
  ## Removes any other SPM version from the path first (SPM versions share
  ## function names), then sets fMRI defaults and initialises the batch system.

  if (nargin < 1)
    spm_dir = fullfile (getenv ('HOME'), 'opt', 'spm25');
  endif
  spm_dir = make_absolute_filename (tilde_expand (spm_dir));
  if (! exist (fullfile (spm_dir, 'spm.m'), 'file'))
    error ('spm25_setup: no spm.m in %s', spm_dir);
  endif

  ## remove other SPM installations (folders containing spm.m) and their
  ## subfolders from the path
  p = strsplit (path (), pathsep ());
  roots = p(cellfun (@(d) exist (fullfile (d, 'spm.m'), 'file') == 2, p));
  roots = roots(! strcmp (roots, spm_dir));
  old = {};
  for r = roots
    old = [old, p(strncmp (p, r{1}, numel (r{1})))];
  endfor
  old = unique (old);
  if (! isempty (old))
    rmpath (old{:});
    clear -f;
  endif

  addpath (spm_dir);
  spm ('defaults', 'fmri');
  spm_jobman ('initcfg');
  printf ('%s ready (%s)\n', spm ('Version'), spm_dir);
endfunction
