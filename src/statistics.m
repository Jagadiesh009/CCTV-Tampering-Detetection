function stats = statistics(cue, det, thr, refGray, normCur, valid, trusted, reg, gain, offset, cfg)
% STATISTICS Calculates quantitative evaluation statistics, region metrics,
% grey-level properties, cue coverage, difference distributions, and sensitivity sweep.
%
% Syntax:
%   stats = statistics(cue, det, thr, refGray, normCur, valid, trusted, reg, gain, offset, cfg)
%
% Outputs:
%   stats - Struct containing all calculated evaluation metrics, tables, and distribution data.

    mask = det.finalMask;
    [H, W] = size(refGray);

    nValid      = nnz(valid);
    nDetected   = nnz(mask);
    nUnchanged  = nValid - nDetected;
    nInvalid    = H * W - nValid;
    detectedPct = 100 * nDetected / nValid;

    [~, regionSizes] = morphology.labelComponents(mask(1:cfg.coarse:end, 1:cfg.coarse:end));
    numRegions = nnz(regionSizes * cfg.coarse^2 >= cfg.minRegionFrac * nValid);

    [rowIdx, colIdx] = find(mask);
    if isempty(rowIdx)
        bbox = [NaN NaN NaN NaN];
    else
        bbox = [min(colIdx) min(rowIdx) max(colIdx) max(rowIdx)];
    end

    falseAlarmTrusted = 100 * mean(mask(cue.trustStat));
    alarmRaised = (nDetected / nValid) >= cfg.alarmFraction;

    cueNames = {'Texture loss', 'Structure decorrelation', ...
        'Intensity change + smooth', '>= 2 cues agree', 'Final region'};

    cueMasks = {det.cueLoss, det.cueNcc, det.cueInt, ...
        det.vote >= cfg.seedVotes, mask};

    cuePctValid     = zeros(1, 5);
    cuePctInMask    = zeros(1, 5);
    cueFalseTrusted = zeros(1, 5);

    for c = 1:5
        cuePctValid(c)     = 100 * nnz(cueMasks{c} & valid) / nValid;
        cuePctInMask(c)    = 100 * nnz(cueMasks{c} & mask) / max(nDetected, 1);
        cueFalseTrusted(c) = 100 * mean(cueMasks{c}(cue.trustStat));
    end

    unchangedMask = valid & ~mask;
    statAll       = regionStats(refGray, normCur, valid);
    statDetected  = regionStats(refGray, normCur, mask);
    statUnchanged = regionStats(refGray, normCur, unchangedMask);

    diffInside  = cue.diffMap(mask);
    diffOutside = cue.diffMap(unchangedMask);

    countsIn  = histc(diffInside(:), cfg.histEdges);
    countsOut = histc(diffOutside(:), cfg.histEdges);
    countsIn  = countsIn(1:end-1);
    countsOut = countsOut(1:end-1);

    pctIn      = 100 * countsIn / max(sum(countsIn), 1);
    pctOut     = 100 * countsOut / max(sum(countsOut), 1);
    binCentres = cfg.histEdges(1:end-1) + diff(cfg.histEdges) / 2;

    % Threshold sensitivity sweep
    nSweep = numel(cfg.sweepAlphaPct);
    sweepDetectedPct = zeros(1, nSweep);
    sweepFalseAlarm  = zeros(1, nSweep);
    sweepThr         = zeros(nSweep, 3);

    for s = 1:nSweep
        thrS = detection.computeThresholds(cue, cfg.sweepAlphaPct(s), cfg);
        detS = detection.detectRegion(cue, thrS, cfg);
        sweepDetectedPct(s) = 100 * nnz(detS.finalMask) / nnz(valid);
        sweepFalseAlarm(s)  = 100 * mean(detS.finalMask(cue.trustStat));
        sweepThr(s, :)      = [thrS.ratio thrS.ncc thrS.diff];
    end

    % Package outputs
    stats.nValid            = nValid;
    stats.nDetected         = nDetected;
    stats.nUnchanged        = nUnchanged;
    stats.nInvalid          = nInvalid;
    stats.detectedPct       = detectedPct;
    stats.numRegions        = numRegions;
    stats.bbox              = bbox;
    stats.falseAlarmTrusted = falseAlarmTrusted;
    stats.alarmRaised       = alarmRaised;
    stats.cueNames          = cueNames;
    stats.cuePctValid       = cuePctValid;
    stats.cuePctInMask      = cuePctInMask;
    stats.cueFalseTrusted   = cueFalseTrusted;
    stats.statAll           = statAll;
    stats.statDetected      = statDetected;
    stats.statUnchanged     = statUnchanged;
    stats.pctIn             = pctIn;
    stats.pctOut            = pctOut;
    stats.binCentres        = binCentres;
    stats.sweepDetectedPct  = sweepDetectedPct;
    stats.sweepFalseAlarm   = sweepFalseAlarm;
    stats.sweepThr          = sweepThr;
    stats.gain              = gain;
    stats.offset            = offset;
    stats.reg               = reg;
end

%% ==================== LOCAL HELPER FUNCTIONS ====================

function s = regionStats(refImg, curImg, mask)
% Mean and standard deviation of grey levels inside a mask.
    s.n = nnz(mask);
    if s.n == 0
        s.refMean = NaN;
        s.refStd  = NaN;
        s.curMean = NaN;
        s.curStd  = NaN;
        return;
    end
    s.refMean = mean(refImg(mask));
    s.refStd  = std(refImg(mask));
    s.curMean = mean(curImg(mask));
    s.curStd  = std(curImg(mask));
end
