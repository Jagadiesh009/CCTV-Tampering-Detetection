classdef detection
% DETECTION Multi-scale cue extraction, statistical thresholding, and region detection.

    methods (Static)
        function cue = computeCues(refGray, normCur, valid, trusted, cfg)
        % Extracts multi-scale physical cues: texture loss, NCC, and intensity differencing.
            K     = cfg.localWin;
            refSm = imageProcessing.boxMean(refGray, cfg.smoothWin);
            curSm = imageProcessing.boxMean(normCur, cfg.smoothWin);

            cue.valid    = valid;
            cue.refGrad  = imageProcessing.boxMean(imageProcessing.sobelMagnitude(refSm) / 8, K);
            cue.curGrad  = imageProcessing.boxMean(imageProcessing.sobelMagnitude(curSm) / 8, K);
            cue.ratioMap = (cue.curGrad + 1) ./ (cue.refGrad + 1);

            meanRef = imageProcessing.boxMean(refSm, K);
            meanCur = imageProcessing.boxMean(curSm, K);
            varRef  = max(imageProcessing.boxMean(refSm .^ 2, K) - meanRef .^ 2, 0);
            varCur  = max(imageProcessing.boxMean(curSm .^ 2, K) - meanCur .^ 2, 0);
            covRC   = imageProcessing.boxMean(refSm .* curSm, K) - meanRef .* meanCur;

            cue.nccMap  = covRC ./ sqrt(varRef .* varCur + 1e-6);
            cue.diffMap = imageProcessing.boxMean(abs(refSm - curSm), K);
            cue.validStat = morphology.erodeValid(valid, K);
            cue.trustStat = morphology.erodeValid(trusted, K);

            % Fine-scale (small-window) cues for pixel-level edge refinement
            KS = cfg.refineWin;
            cue.refGradS   = imageProcessing.boxMean(imageProcessing.sobelMagnitude(refSm) / 8, KS);
            cue.curGradS   = imageProcessing.boxMean(imageProcessing.sobelMagnitude(curSm) / 8, KS);
            cue.ratioS     = (cue.curGradS + 1) ./ (cue.refGradS + 1);
            cue.diffS      = imageProcessing.boxMean(abs(refSm - curSm), KS);
            cue.validStatS = morphology.erodeValid(valid, KS);
            cue.trustStatS = morphology.erodeValid(trusted, KS);
        end

        function thr = computeThresholds(cue, alphaPct, cfg)
        % Calculates statistical cue thresholds derived from verified-unchanged pixels
        % to control the false-alarm rate at alphaPct.
            thr.textureFloor = detection.percentileOf(cue.refGrad(cue.validStat), cfg.texturePct);
            textured = cue.trustStat & cue.refGrad > thr.textureFloor;
            thr.ratio = detection.percentileOf(cue.ratioMap(textured), alphaPct);
            thr.ncc = detection.percentileOf(cue.nccMap(textured), alphaPct);
            thr.diff = detection.percentileOf(cue.diffMap(cue.trustStat), 100 - alphaPct);
            thr.smooth = detection.percentileOf(cue.curGrad(cue.trustStat), cfg.smoothPct);
            thr.smoothHull = detection.percentileOf(cue.curGrad(cue.trustStat), cfg.hullSmoothPct);

            % Small-window thresholds
            thr.texFloorS = detection.percentileOf(cue.refGradS(cue.validStatS), cfg.texturePct);
            texturedS = cue.trustStatS & cue.refGradS > thr.texFloorS;
            thr.ratioS = detection.percentileOf(cue.ratioS(texturedS), cfg.refineAlphaPct);
            thr.diffS = detection.percentileOf(cue.diffS(cue.trustStatS), 100 - cfg.refineAlphaPct);
            thr.smoothS = detection.percentileOf(cue.curGradS(cue.trustStatS), cfg.hullSmoothPct);
        end

        function det = detectRegion(cue, thr, cfg)
        % Multi-cue voting, coarse block spatial grouping, morphology, and shape completion.
            hasTexture = cue.refGrad > thr.textureFloor;
            det.cueLoss = cue.valid & hasTexture & (cue.ratioMap < thr.ratio);
            det.cueNcc  = cue.valid & hasTexture & (cue.nccMap < thr.ncc);
            det.cueInt  = cue.valid & (cue.diffMap > thr.diff) & (cue.curGrad < thr.smooth);
            det.vote    = double(det.cueLoss) + double(det.cueNcc) + double(det.cueInt);

            candidate = det.cueLoss | det.cueInt;
            seeds     = det.vote >= cfg.seedVotes;

            f = cfg.coarse;
            candC  = morphology.blockFraction(candidate, f) >= 0.5;
            seedC  = morphology.blockFraction(seeds, f) >= 0.5;
            validC = morphology.blockFraction(cue.valid, f) >= 0.5;

            labels = morphology.labelComponents(candC);
            keep   = unique(labels(seedC & candC));
            keep   = keep(keep > 0);
            regionC = ismember(labels, keep) & labels > 0;

            regionC = morphology.closeBox(regionC, cfg.closeCells);
            regionC = morphology.fillHoles(regionC);
            regionC = morphology.openBox(regionC, cfg.openCells);

            [labels2, sizes] = morphology.labelComponents(regionC);
            bigEnough = find(sizes >= cfg.minRegionFrac * nnz(validC));
            regionC   = ismember(labels2, bigEnough) & labels2 > 0;

            smoothC = morphology.blockFraction(cue.valid & (cue.curGrad < thr.smoothHull), f) >= 0.5;
            beforeC = regionC;
            regionC = morphology.completeByHull(regionC, smoothC, cfg.padCells) & validC;
            regionC = morphology.closeBox(regionC, cfg.notchCells) & validC;

            s = cfg.borderSnapCells;
            nearBorder = validC & ~morphology.erodeValid(validC, 2 * s + 1);
            regionC    = regionC | (morphology.dilateBox(regionC, 2 * s + 1) & nearBorder);

            regionC = (imageProcessing.boxMean(double(regionC), cfg.edgeSmoothCells) > 0.5) & validC;
            det.addedFrac = nnz(regionC & ~beforeC) * f * f / max(nnz(cue.valid), 1);

            [H, W] = size(cue.valid);
            rowIdx = min(ceil((1:H) / f), size(regionC, 1));
            colIdx = min(ceil((1:W) / f), size(regionC, 2));
            coarseMask = regionC(rowIdx, colIdx) & cue.valid;

            det.coarseMask = coarseMask;
            det.finalMask  = morphology.refineMask(coarseMask, cue, thr, cfg);
            det.refineFrac = (nnz(det.finalMask) - nnz(coarseMask)) / max(nnz(cue.valid), 1);
        end

        function v = percentileOf(x, p)
        % Linear-interpolated percentile calculation without Statistics Toolbox.
            x = sort(x(:));
            x = x(isfinite(x));
            n = numel(x);
            if n == 0, v = NaN; return; end
            pos = 1 + (n - 1) * p / 100;
            lo = floor(pos);
            hi = ceil(pos);
            v = x(lo) + (pos - lo) * (x(hi) - x(lo));
        end
    end
end
