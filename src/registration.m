function [warpedCur, valid, trusted, reg] = registration(refGray, curGray, cfg)
% REGISTRATION Registers the current frame to the reference frame.
%
% Syntax:
%   [warpedCur, valid, trusted, reg] = registration(refGray, curGray, cfg)
%
% Description:
%   Performs block-wise phase correlation on Sobel gradient representations,
%   filters for textured blocks, fits robust linear affine scale and shift models,
%   and determines the valid comparable field of view along with verified-unchanged
%   evidence blocks.
%
% Outputs:
%   warpedCur - Current image bilinearly warped to reference coordinates
%   valid     - Logical mask of overlapping valid pixels excluding white borders
%   trusted   - Logical mask of verified-unchanged pixels from registration inliers
%   reg       - Struct containing registration parameters (ax, bx, ay, by, etc.)

    [H, W] = size(refGray);

    % Detect white margins / borders
    refMargins = detectWhiteMargins(refGray);
    curMargins = detectWhiteMargins(curGray);

    % Estimate registration parameters via phase correlation & robust fitting
    reg = estimateRegistration(refGray, curGray, refMargins, curMargins, cfg);

    % Generate coordinate grids
    [xRef, yRef] = meshgrid(1:W, 1:H);
    xCur = reg.ax * xRef + reg.bx;
    yCur = reg.ay * yRef + reg.by;

    xLo = curMargins(3) + 1;
    xHi = W - curMargins(4);
    yLo = curMargins(1) + 1;
    yHi = H - curMargins(2);

    % Compute valid comparable mask
    valid = xCur >= xLo & xCur <= xHi & yCur >= yLo & yCur <= yHi & ...
            xRef > refMargins(3) & xRef <= W - refMargins(4) & ...
            yRef > refMargins(1) & yRef <= H - refMargins(2);

    % Bilinear warp of current frame to reference frame
    warpedCur = interp2(curGray, min(max(xCur, xLo), xHi), ...
                                 min(max(yCur, yLo), yHi), 'linear');

    % Verified-unchanged pixels = union of blocks that registered with high correlation
    trusted = false(H, W);
    for b = 1:size(reg.inlierBox, 1)
        box = reg.inlierBox(b, :);
        trusted(box(2):box(4), box(1):box(3)) = true;
    end
    trusted = trusted & valid;
end

%% ==================== LOCAL HELPER FUNCTIONS ====================

function m = detectWhiteMargins(img)
% Detect bright uniform borders [top bottom left right].
    colMean = mean(img, 1);
    rowMean = mean(img, 2)';
    m = [whiteRun(rowMean), whiteRun(fliplr(rowMean)), ...
         whiteRun(colMean), whiteRun(fliplr(colMean))];
    m(m > 0) = m(m > 0) + 2;
end

function n = whiteRun(v)
    idx = find(v < 200, 1, 'first');
    if isempty(idx)
        n = 0;
    else
        n = idx - 1;
    end
    n = min(n, round(0.1 * numel(v)));
end

function reg = estimateRegistration(refGray, curGray, refMargins, curMargins, cfg)
% Estimate scale and shift from block-wise phase correlation on gradient images.
    [H, W] = size(refGray);
    B = cfg.regBlock;
    hann = 0.5 - 0.5 * cos(2 * pi * (0:B - 1)' / (B - 1));
    win = hann * hann';
    gradRef = imageProcessing.sobelMagnitude(refGray);
    gradCur = imageProcessing.sobelMagnitude(curGray);
    marginLo = max(refMargins(3), curMargins(3)) + 3;
    marginTop = max(refMargins(1), curMargins(1)) + 3;

    blocks = zeros(0, 5);
    boxes = zeros(0, 4);

    for y0 = max(21, marginTop):cfg.regStep:(H - B - 20)
        for x0 = max(21, marginLo):cfg.regStep:(W - B - 20)
            ga = gradRef(y0:y0 + B - 1, x0:x0 + B - 1);
            if mean(ga(:)) < cfg.regMinTex, continue; end
            gb = gradCur(y0:y0 + B - 1, x0:x0 + B - 1);

            ga = ga .* win;
            ga = ga - mean(ga(:));
            gb = gb .* win;
            gb = gb - mean(gb(:));

            F = fft2(gb) .* conj(fft2(ga));
            c = real(ifft2(F ./ (abs(F) + 1e-9)));
            [pk, id] = max(c(:));
            [iy, ix] = ind2sub([B B], id);

            dy = iy - 1;
            if dy >= B / 2, dy = dy - B; end
            dx = ix - 1;
            if dx >= B / 2, dx = dx - B; end

            blocks(end + 1, :) = [x0 + (B - 1) / 2, ...
                y0 + (B - 1) / 2, dx, dy, pk]; %#ok<AGROW>
            boxes(end + 1, :) = [x0, y0, x0 + B - 1, y0 + B - 1]; %#ok<AGROW>
        end
    end

    reg = struct('ax', 1, 'bx', 0, 'ay', 1, 'by', 0, ...
        'numInliers', 0, 'numBlocks', size(blocks, 1), ...
        'inlierBox', zeros(0, 4));

    if size(blocks, 1) < cfg.regMinInlier
        warning('Too few textured blocks; using identity registration.');
        return;
    end

    pk = blocks(:, 5);
    sel = pk >= max(cfg.regMinPeak, cfg.regRelPeak * max(pk));
    fitX = [1 0];
    fitY = [1 0];

    for it = 1:5
        if nnz(sel) < cfg.regMinInlier
            warning('Registration unreliable; using identity registration.');
            return;
        end

        fitX = polyfit(blocks(sel, 1), blocks(sel, 1) + blocks(sel, 3), 1);
        fitY = polyfit(blocks(sel, 2), blocks(sel, 2) + blocks(sel, 4), 1);

        resX = blocks(:, 1) + blocks(:, 3) - polyval(fitX, blocks(:, 1));
        resY = blocks(:, 2) + blocks(:, 4) - polyval(fitY, blocks(:, 2));
        sel = sqrt(resX .^ 2 + resY .^ 2) <= cfg.regTolPx & pk >= cfg.regMinPeak;
    end

    if nnz(sel) < cfg.regMinInlier
        warning('Registration unreliable; using identity registration.');
        return;
    end

    reg.ax = fitX(1);
    reg.bx = fitX(2);
    reg.ay = fitY(1);
    reg.by = fitY(2);
    reg.numInliers = nnz(sel);
    reg.inlierBox = boxes(sel, :);
end
