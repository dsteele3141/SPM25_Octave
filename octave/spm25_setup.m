function spm25_setup (spm_dir, varargin)
  ## SPM25_SETUP  Put SPM25 on the Octave path.
  ##
  ##   spm25_setup ('~/opt/spm25')           % path only; then type spm or spm fmri
  ##   spm25_setup ('~/opt/spm25', 'init')   % also load fMRI defaults + batch system
  ##
  ## Removes any other SPM version from the path first (SPM versions share
  ## function names). By default nothing else is run, as in MATLAB after
  ## addpath: "spm" then shows the welcome screen. With 'init' it also runs
  ## spm('defaults','fmri') and spm_jobman('initcfg') (useful in scripts), but
  ## plain "spm" then goes straight to the fMRI windows.
  ##
  ## Also turns off a harmless Octave 11 warning printed when SPM opens
  ## MATLAB-saved .fig files such as the batch editor ("object of class
  ## 'function_handle_workspace' was deleted in MATLAB").

  if (nargin < 1 || isempty (spm_dir))
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
  warning ('off', 'Octave:load:deleted-object');
  if (any (strcmpi (varargin, 'init')))
    spm ('defaults', 'fmri');
    spm_jobman ('initcfg');
  endif
  printf ('%s ready (%s)\n', spm ('Version'), spm_dir);
endfunction
