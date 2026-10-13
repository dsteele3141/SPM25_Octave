function nii_view(fname)
% NII_VIEW  SPM-style orthogonal viewer for a NIfTI image (no SPM needed).
%
%   nii_view('brain.nii.gz')
%   nii_view                 % choose a file
%
% Layout as in SPM's Display: coronal top-left, sagittal top-right,
% axial bottom-left, information panel bottom-right.
% Click any view to move the crosshair; type mm coordinates and press Enter
% to jump there.
%
% Neurological convention like SPM: subject's LEFT is on the screen's LEFT.
% The image is shown in world (mm) orientation using the header affine
% (nearest axis-aligned reorientation; oblique rotations are not resampled).

if nargin < 1
  [f, p] = uigetfile({'*.nii;*.nii.gz', 'NIfTI images'}, 'Select image');
  if isequal(f, 0), return; end
  fname = fullfile(p, f);
end

[img, A, hdr] = nii_read(fname);
[img, A] = reorient_to_ras(img, A);
img(~isfinite(img)) = 0;

s.img = img;
s.A   = A;
s.dim = size(img);
s.vs  = sqrt(sum(A(1:3,1:3).^2));          % voxel sizes (mm)

% start at the voxel nearest mm (0,0,0) if it lies inside the image
v0 = round(A \ [0; 0; 0; 1]);
if all(v0(1:3)' >= 1 & v0(1:3)' <= s.dim)
  s.pos = v0(1:3)';
else
  s.pos = round(s.dim / 2);
end

% robust intensity window (1st-99.5th percentile of non-zero voxels)
nz = sort(img(img ~= 0));
if isempty(nz), nz = 0; end
lo = nz(max(1, round(0.01  * numel(nz))));
hi = nz(max(1, round(0.995 * numel(nz))));
if hi <= lo, hi = lo + 1; end
clim = [lo hi];

[~, name, ext] = fileparts(fname);
fig = figure('Name', ['nii_view: ' name ext], 'NumberTitle', 'off', ...
             'Color', 'w', 'Position', [100 100 800 800], 'Colormap', gray(256));

% --- three views: {axes position, horizontal axis, vertical axis, labels}
s.ax(1) = axes('Parent', fig, 'Position', [0.03 0.51 0.46 0.46]);  % coronal  (x by z)
s.ax(2) = axes('Parent', fig, 'Position', [0.51 0.51 0.46 0.46]);  % sagittal (y by z)
s.ax(3) = axes('Parent', fig, 'Position', [0.03 0.03 0.46 0.46]);  % axial    (x by y)
hv = [1 3; 2 3; 1 2];                      % which voxel axes are horizontal/vertical
lab = {'L', 'R'; 'P', 'A'; 'L', 'R'};
for k = 1:3
  ax = s.ax(k);
  s.im(k) = imagesc(slice_of(s, k), 'Parent', ax);
  set(ax, 'YDir', 'normal', 'CLim', clim, 'XTick', [], 'YTick', [], ...
      'Color', 'k', 'NextPlot', 'add');
  daspect(ax, [1/s.vs(hv(k,1)) 1/s.vs(hv(k,2)) 1]);
  axis(ax, 'tight');
  s.hl(k) = line([1 1], [1 1], 'Parent', ax, 'Color', [0 0 1], 'HitTest', 'off');
  s.vl(k) = line([1 1], [1 1], 'Parent', ax, 'Color', [0 0 1], 'HitTest', 'off');
  n1 = s.dim(hv(k,1)); n2 = s.dim(hv(k,2));
  text(1 + 0.02*n1, 0.5 + 0.5*n2, lab{k,1}, 'Parent', ax, 'Color', 'y', 'FontWeight', 'bold', 'HitTest', 'off');
  text(n1 - 0.06*n1, 0.5 + 0.5*n2, lab{k,2}, 'Parent', ax, 'Color', 'y', 'FontWeight', 'bold', 'HitTest', 'off');
  set(s.im(k), 'ButtonDownFcn', {@on_click, k});
end

% --- information panel (bottom right)
info = sprintf(['File: %s%s\nDims: %d x %d x %d   (%d vol)\n' ...
                'Voxel: %.2f x %.2f x %.2f mm\nAffine from: %s\n' ...
                'Window: %.4g to %.4g'], name, ext, hdr.dim(2:4), hdr.nvols, ...
                s.vs, hdr.affine_source, clim);
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.53 0.30 0.44 0.17], 'String', info, ...
          'HorizontalAlignment', 'left', 'BackgroundColor', 'w', 'FontSize', 10);
s.txt = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.53 0.16 0.44 0.12], 'String', '', ...
          'HorizontalAlignment', 'left', 'BackgroundColor', 'w', ...
          'FontSize', 11, 'FontWeight', 'bold');
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.53 0.09 0.12 0.04], 'String', 'Go to mm:', ...
          'HorizontalAlignment', 'left', 'BackgroundColor', 'w');
s.edit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
          'Position', [0.65 0.09 0.20 0.045], 'String', '0 0 0', ...
          'Callback', @on_goto);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
          'Position', [0.86 0.09 0.11 0.045], 'String', 'Origin', ...
          'Callback', @(h, e) goto_mm(fig, [0 0 0]));

guidata(fig, s);
redraw(fig);
end

% ---------------------------------------------------------------------------
function sl = slice_of(s, k)
p = s.pos;
switch k
  case 1, sl = squeeze(s.img(:, p(2), :))';   % coronal:  rows z, cols x
  case 2, sl = squeeze(s.img(p(1), :, :))';   % sagittal: rows z, cols y
  case 3, sl = s.img(:, :, p(3))';            % axial:    rows y, cols x
end
end

function redraw(fig)
s = guidata(fig);
p = s.pos;
hv = [1 3; 2 3; 1 2];
for k = 1:3
  set(s.im(k), 'CData', slice_of(s, k));
  n1 = s.dim(hv(k,1)); n2 = s.dim(hv(k,2));
  set(s.vl(k), 'XData', [p(hv(k,1)) p(hv(k,1))], 'YData', [0.5 n2+0.5]);
  set(s.hl(k), 'XData', [0.5 n1+0.5], 'YData', [p(hv(k,2)) p(hv(k,2))]);
end
mm = s.A * [p(:); 1];
set(s.txt, 'String', sprintf('mm:     %7.1f %7.1f %7.1f\nvoxel:  %4d %4d %4d\nvalue:  %.6g', ...
                             mm(1:3), p, s.img(p(1), p(2), p(3))));
end

function on_click(h, ~, k)
fig = ancestor(h, 'figure');
s = guidata(fig);
cp = get(get(h, 'Parent'), 'CurrentPoint');
hv = [1 3; 2 3; 1 2];
s.pos(hv(k,1)) = min(max(round(cp(1,1)), 1), s.dim(hv(k,1)));
s.pos(hv(k,2)) = min(max(round(cp(1,2)), 1), s.dim(hv(k,2)));
guidata(fig, s);
redraw(fig);
end

function on_goto(h, ~)
mm = sscanf(strrep(get(h, 'String'), ',', ' '), '%f')';
if numel(mm) == 3
  goto_mm(ancestor(h, 'figure'), mm);
end
end

function goto_mm(fig, mm)
s = guidata(fig);
v = round(s.A \ [mm(:); 1]);
s.pos = min(max(v(1:3)', 1), s.dim);
guidata(fig, s);
redraw(fig);
end

function [img, A] = reorient_to_ras(img, A)
% Permute/flip voxel axes so that voxel axes 1,2,3 point (approximately)
% to world +x (Right), +y (Anterior), +z (Superior). A stays 1-based.
M = abs(A(1:3, 1:3));
perm = zeros(1, 3);
for n = 1:3                                % greedy: strongest pairing first
  [~, idx] = max(M(:));
  [r, c] = ind2sub([3 3], idx);
  perm(r) = c;
  M(r, :) = -Inf; M(:, c) = -Inf;
end
img = permute(img, perm);
A = A(:, [perm 4]);
for r = 1:3
  if A(r, r) < 0
    n = size(img, r);
    img = flip(img, r);
    A(:, 4) = A(:, 4) + A(:, r) * (n + 1);
    A(:, r) = -A(:, r);
  end
end
end
