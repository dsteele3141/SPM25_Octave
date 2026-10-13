function [img, A, hdr] = nii_read(fname, vol)
% NII_READ  Minimal NIfTI-1 reader (.nii or .nii.gz) - no SPM needed.
%
%   [img, A, hdr] = nii_read('brain.nii.gz')       % first volume
%   [img, A, hdr] = nii_read('func.nii', 10)       % 10th volume of a 4D file
%
%   img : 3D double array, scaled by scl_slope/scl_inter
%   A   : 4x4 voxel->mm affine for 1-BASED voxel indices,
%         i.e. mm = A * [i; j; k; 1]   (sform if set, else qform, else pixdim)
%   hdr : struct of the header fields used
%
% Works in Octave and MATLAB. Single-file NIfTI-1 only (magic 'n+1').

if nargin < 2, vol = 1; end

% --- decompress .nii.gz into a private temporary folder.
% Octave's gunzip is NOT used: in Octave 6 it deletes the original .gz.
% In Octave the system's `gzip -dc` (read-only on the source) is used;
% MATLAB's gunzip is safe. Only the private temp folder is ever removed.
tmpdir = '';
if numel(fname) > 3 && strcmpi(fname(end-2:end), '.gz')
  if ~exist(fname, 'file'), error('nii_read: %s not found', fname); end
  tmpdir = tempname; mkdir(tmpdir);
  tmpnii = fullfile(tmpdir, 'tmp.nii');
  if exist('OCTAVE_VERSION', 'builtin')
    status = system(sprintf('gzip -dc "%s" > "%s"', fname, tmpnii));
  else
    gunzip(fname, tmpdir);
    d = dir(fullfile(tmpdir, '*.nii'));
    status = numel(d) ~= 1;
    if ~status, tmpnii = fullfile(tmpdir, d(1).name); end
  end
  if status ~= 0 || ~exist(tmpnii, 'file')
    rmdir(tmpdir, 's'); error('nii_read: could not decompress %s', fname);
  end
  fname = tmpnii;
end

% --- detect byte order from sizeof_hdr (must be 348)
endian = 'ieee-le';
fid = fopen(fname, 'r', endian);
if fid < 0, error('nii_read: cannot open %s', fname); end
if fread(fid, 1, 'int32') ~= 348
  fclose(fid); endian = 'ieee-be';
  fid = fopen(fname, 'r', endian);
  if fread(fid, 1, 'int32') ~= 348
    fclose(fid); error('nii_read: %s is not a NIfTI-1 file', fname);
  end
end

fseek(fid, 40, 'bof');   hdr.dim       = fread(fid, 8, 'int16')';
fseek(fid, 70, 'bof');   hdr.datatype  = fread(fid, 1, 'int16');
                         hdr.bitpix    = fread(fid, 1, 'int16');
fseek(fid, 76, 'bof');   hdr.pixdim    = fread(fid, 8, 'float32')';
fseek(fid, 108, 'bof');  hdr.vox_offset = fread(fid, 1, 'float32');
                         hdr.scl_slope = fread(fid, 1, 'float32');
                         hdr.scl_inter = fread(fid, 1, 'float32');
fseek(fid, 252, 'bof');  hdr.qform_code = fread(fid, 1, 'int16');
                         hdr.sform_code = fread(fid, 1, 'int16');
                         q             = fread(fid, 6, 'float32')';   % quatern_b,c,d, qoffset_x,y,z
                         srow          = fread(fid, 12, 'float32');
fseek(fid, 344, 'bof');  hdr.magic     = fread(fid, 4, 'char=>char')';

if ~strcmp(hdr.magic(1:3), 'n+1')
  fclose(fid); error('nii_read: only single-file .nii supported (magic "%s")', hdr.magic(1:3));
end

% --- voxel -> mm affine (0-based, as stored)
if hdr.sform_code > 0
  hdr.affine_source = 'sform';
  A0 = [reshape(srow, 4, 3)'; 0 0 0 1];
elseif hdr.qform_code > 0
  hdr.affine_source = 'qform';
  b = q(1); c = q(2); d = q(3);
  a = sqrt(max(0, 1 - (b^2 + c^2 + d^2)));
  R = [a^2+b^2-c^2-d^2, 2*(b*c-a*d),     2*(b*d+a*c);
       2*(b*c+a*d),     a^2+c^2-b^2-d^2, 2*(c*d-a*b);
       2*(b*d-a*c),     2*(c*d+a*b),     a^2+d^2-b^2-c^2];
  qfac = hdr.pixdim(1); if qfac == 0, qfac = 1; end
  A0 = [R * diag([hdr.pixdim(2) hdr.pixdim(3) qfac*hdr.pixdim(4)]), q(4:6)'; 0 0 0 1];
else
  hdr.affine_source = 'pixdim only (no orientation info)';
  A0 = [diag(hdr.pixdim(2:4)), zeros(3,1); 0 0 0 1];
end
A = A0 * [eye(3), -ones(3,1); 0 0 0 1];          % convert to 1-based indices

% --- read one volume
types = { 2,'uint8';  4,'int16';  8,'int32';  16,'float32'; 64,'float64';
        256,'int8'; 512,'uint16'; 768,'uint32'};
k = find([types{:,1}] == hdr.datatype);
if isempty(k), fclose(fid); error('nii_read: unsupported datatype %d', hdr.datatype); end
dims  = hdr.dim(2:4);
nvox  = prod(dims);
nvols = max(1, prod(hdr.dim(5:max(5, hdr.dim(1)+1))));
if vol > nvols, fclose(fid); error('nii_read: file has %d volumes', nvols); end
fseek(fid, hdr.vox_offset + (vol-1) * nvox * hdr.bitpix/8, 'bof');
img = fread(fid, nvox, [types{k,2} '=>double']);
fclose(fid);
if numel(img) < nvox, error('nii_read: file truncated'); end
img = reshape(img, dims);

if hdr.scl_slope ~= 0 && ~isnan(hdr.scl_slope)
  img = img * hdr.scl_slope + hdr.scl_inter;
end
hdr.nvols = nvols;

if ~isempty(tmpdir), rmdir(tmpdir, 's'); end
end
