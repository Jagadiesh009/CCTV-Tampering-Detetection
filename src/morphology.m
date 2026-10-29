classdef morphology
% MORPHOLOGY Morphological filtering, connected components, and boundary refinement.
% Implemented without the MATLAB Image Processing Toolbox.

    methods (Static)
        function out = dilateBox(mask, k)
        % Morphological dilation with a k x k square structuring element.
            out = imageProcessing.boxMean(double(mask), k) > 1e-9;
        end

        function out = erodeBox(mask, k)
        % Morphological erosion with a k x k square structuring element.
            out = imageProcessing.boxMean(double(mask), k) > 1 - 1e-9;
        end

        function out = closeBox(mask, k)
        % Morphological closing: dilation followed by erosion.
            out = morphology.erodeBox(morphology.dilateBox(mask, k), k);
        end

        function out = openBox(mask, k)
        % Morphological opening: erosion followed by dilation.
            out = morphology.dilateBox(morphology.erodeBox(mask, k), k);
        end

        function out = erodeValid(mask, k)
        % Keep pixels whose complete k x k window lies entirely inside the mask.
            u = ones(k, 1) / k;
            out = conv2(u, u', double(mask), 'same') > 0.9999;
        end

        function frac = blockFraction(mask, f)
        % Fraction of true pixels in each f x f spatial block.
            [m, n] = size(mask);
            mc = floor(m / f);
            nc = floor(n / f);
            a = double(mask(1:mc * f, 1:nc * f));
            a = reshape(a, f, mc, f, nc);
            frac = reshape(sum(sum(a, 1), 3), mc, nc) / (f * f);
        end

        function [labels, sizes] = labelComponents(mask)
        % 4-connected component labelling using stack-based flood fill (replaces bwlabel).
            [m, n] = size(mask);
            labels = zeros(m, n);
            sizes  = zeros(0, 1);
            stack  = zeros(m * n, 1);
            count  = 0;
            seeds  = find(mask(:))';

            for idx = seeds
                if labels(idx) ~= 0, continue; end
                count = count + 1;
                sp = 1;
                stack(1) = idx;
                labels(idx) = count;
                sz = 0;

                while sp > 0
                    cur = stack(sp);
                    sp = sp - 1;
                    sz = sz + 1;
                    r = mod(cur - 1, m) + 1;
                    c = (cur - r) / m + 1;

                    if r > 1
                        nb = cur - 1;
                        if mask(nb) && labels(nb) == 0
                            labels(nb) = count;
                            sp = sp + 1;
                            stack(sp) = nb;
                        end
                    end

                    if r < m
                        nb = cur + 1;
                        if mask(nb) && labels(nb) == 0
                            labels(nb) = count;
                            sp = sp + 1;
                            stack(sp) = nb;
                        end
                    end

                    if c > 1
                        nb = cur - m;
                        if mask(nb) && labels(nb) == 0
                            labels(nb) = count;
                            sp = sp + 1;
                            stack(sp) = nb;
                        end
                    end

                    if c < n
                        nb = cur + m;
                        if mask(nb) && labels(nb) == 0
                            labels(nb) = count;
                            sp = sp + 1;
                            stack(sp) = nb;
                        end
                    end
                end
                sizes(count, 1) = sz;
            end
        end

        function filled = fillHoles(mask)
        % Fill enclosed background cavities that do not connect to frame borders (replaces imfill).
            background = ~mask;
            labels = morphology.labelComponents(background);
            borderLabels = unique([labels(1, :), labels(end, :), ...
                                   labels(:, 1)', labels(:, end)']);
            holes = background & labels > 0 & ~ismember(labels, borderLabels);
            filled = mask | holes;
        end

        function out = completeByHull(regionC, allowC, P)
        % Convex-hull geometric completion of detected regions on smooth background areas.
            [m, n] = size(regionC);
            out = regionC;
            ri = [ones(1, P) 1:m m * ones(1, P)];
            ci = [ones(1, P) 1:n n * ones(1, P)];
            padded = regionC(ri, ci);
            [lab, sz] = morphology.labelComponents(padded);
            [X, Y] = meshgrid(1:size(padded, 2), 1:size(padded, 1));

            for k = 1:numel(sz)
                [r, c] = find(lab == k);
                if numel(r) < 3, continue; end
                try
                    h = convhull(c, r);
                catch
                    continue;
                end
                inside = inpolygon(X, Y, c(h), r(h));
                out = out | (inside(P + 1:P + m, P + 1:P + n) & allowC);
            end
        end

        function out = refineMask(mask, cue, thr, cfg)
        % Fine-scale boundary refinement using small-window cues.
            g = cfg.refineGrow;
            k = 2 * g + 1;
            ring  = morphology.dilateBox(mask, k) & ~mask & cue.valid;
            inner = mask & ~morphology.erodeBox(mask, k);

            smoothCur = cue.curGradS < thr.smoothS;
            changedEv = (cue.ratioS < thr.ratioS & cue.refGradS > thr.texFloorS) | ...
                        (cue.diffS > thr.diffS);
            sameEv = cue.validStatS & ~smoothCur & (cue.diffS <= thr.diffS);

            out = mask;
            out(ring)  = smoothCur(ring) & changedEv(ring);
            out(inner) = ~sameEv(inner);

            r = cfg.refineSmoothPx;
            if mod(r, 2) == 0
                r = r + 1;
            end
            out = (imageProcessing.boxMean(double(out), r) > 0.5) & cue.valid;
        end
    end
end
