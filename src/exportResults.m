function exportResults(figDashboard, figGraphs, highlight, stats, cue, det, thr, reg, gain, offset, cfg)
% EXPORTRESULTS Exports all visual assets, styled figures, and CSV files,
% and displays the terminal detection summary.
%
% Syntax:
%   exportResults(figDashboard, figGraphs, highlight, stats, cue, det, thr, reg, gain, offset, cfg)
%
% Description:
%   1. Writes the highlighted output composite image (PNG).
%   2. Applies high-visibility white/black typography and contrast styling across all figures.
%   3. Exports the 6-panel dashboard and all five analytical graphs at 150 DPI.
%   4. Exports 5 structured CSV tables for evaluation and automated ingestion.
%   5. Prints the formatted detection report to the MATLAB console.

    % Ensure output directory exists
    if ~exist(cfg.outDir, 'dir')
        [ok, msg] = mkdir(cfg.outDir);
        if ~ok
            error('Failed to create output folder "%s": %s', cfg.outDir, msg);
        end
    end

    % 1. Save highlighted output image
    highlightPath = fullfile(cfg.outDir, 'cctv_highlighted.png');
    try
        imwrite(highlight, highlightPath);
    catch ME
        error('Failed to write highlighted image to "%s": %s', highlightPath, ME.message);
    end

    % 2. Apply typography and contrast styling to all figures
    allFigures = [figDashboard, figGraphs];
    visualisation.applyStyling(allFigures);

    % 3. Export figure PNGs
    saveFigurePng(figDashboard, fullfile(cfg.outDir, 'cctv_dashboard.png'));
    saveFigurePng(figGraphs(1),  fullfile(cfg.outDir, 'graph1_threshold_sensitivity.png'));
    saveFigurePng(figGraphs(2),  fullfile(cfg.outDir, 'graph2_difference_distribution.png'));
    saveFigurePng(figGraphs(3),  fullfile(cfg.outDir, 'graph3_cue_comparison.png'));
    saveFigurePng(figGraphs(4),  fullfile(cfg.outDir, 'graph4_intensity_comparison.png'));
    saveFigurePng(figGraphs(5),  fullfile(cfg.outDir, 'graph5_detected_vs_unchanged.png'));

    % 4. Export CSV result files
    writeCsv(fullfile(cfg.outDir, 'cctv_summary.csv'), {'metric', 'value', 'note'}, { ...
        'detected_changed_pct_of_comparable_frame', stats.detectedPct, 'detected changed area, not ground truth'; ...
        'detected_pixels', stats.nDetected, 'pixels inside final mask'; ...
        'comparable_pixels', stats.nValid, 'pixels present in both frames after registration'; ...
        'excluded_pixels', stats.nInvalid, 'border / non-overlapping pixels'; ...
        'connected_regions', stats.numRegions, 'regions >= minimum size'; ...
        'shape_completion_pct_of_comparable_frame', 100 * det.addedFrac, 'added by convex-hull completion (inferred from shape)'; ...
        'edge_refinement_net_pct_of_comparable_frame', 100 * det.refineFrac, 'net change from pixel-level edge refinement (+ grew, - trimmed)'; ...
        'bbox_x_min', stats.bbox(1), 'detected region bounding box (reference frame)'; ...
        'bbox_y_min', stats.bbox(2), ''; ...
        'bbox_x_max', stats.bbox(3), ''; ...
        'bbox_y_max', stats.bbox(4), ''; ...
        'unchanged_pixels_flagged_pct', stats.falseAlarmTrusted, 'self-check on verified-unchanged blocks, not accuracy'; ...
        'alarm_raised', double(stats.alarmRaised), '1 if detected area >= alarm fraction'; ...
        'alarm_fraction', cfg.alarmFraction, 'application parameter'; ...
        'registration_scale_x', reg.ax, 'current_x = scale_x * ref_x + shift_x'; ...
        'registration_shift_x', reg.bx, 'pixels'; ...
        'registration_scale_y', reg.ay, ''; ...
        'registration_shift_y', reg.by, 'pixels'; ...
        'registration_inlier_blocks', reg.numInliers, ['of ' num2str(reg.numBlocks) ' textured blocks']; ...
        'brightness_gain', gain, 'current = gain * reference + offset'; ...
        'brightness_offset', offset, ''; ...
        'alpha_false_alarm_pct', cfg.alphaPct, 'percentile setting for thresholds'});

    writeCsv(fullfile(cfg.outDir, 'cctv_thresholds_sensitivity.csv'), ...
        {'alpha_pct', 'ratio_threshold', 'ncc_threshold', 'diff_threshold', ...
         'detected_pct_of_comparable_frame', 'unchanged_pixels_flagged_pct'}, ...
        num2cell([cfg.sweepAlphaPct(:) stats.sweepThr stats.sweepDetectedPct(:) stats.sweepFalseAlarm(:)]));

    cueRows = cell(5, 4);
    for c = 1:5
        cueRows(c, :) = {stats.cueNames{c}, stats.cuePctValid(c), stats.cuePctInMask(c), stats.cueFalseTrusted(c)};
    end

    writeCsv(fullfile(cfg.outDir, 'cctv_cue_comparison.csv'), ...
        {'cue', 'pct_of_comparable_frame', 'pct_of_final_region_covered', ...
         'pct_of_unchanged_blocks_flagged'}, cueRows);

    writeCsv(fullfile(cfg.outDir, 'cctv_intensity_comparison.csv'), ...
        {'region', 'pixels', 'ref_mean', 'ref_std', 'current_mean', 'current_std'}, { ...
        'comparable_frame', stats.statAll.n, stats.statAll.refMean, stats.statAll.refStd, stats.statAll.curMean, stats.statAll.curStd; ...
        'detected_region', stats.statDetected.n, stats.statDetected.refMean, stats.statDetected.refStd, stats.statDetected.curMean, stats.statDetected.curStd; ...
        'unchanged_region', stats.statUnchanged.n, stats.statUnchanged.refMean, stats.statUnchanged.refStd, stats.statUnchanged.curMean, stats.statUnchanged.curStd});

    writeCsv(fullfile(cfg.outDir, 'cctv_difference_histogram.csv'), ...
        {'bin_start', 'bin_end', 'pct_outside_region', 'pct_inside_region'}, ...
        num2cell([cfg.histEdges(1:end-1)' cfg.histEdges(2:end)' stats.pctOut(:) stats.pctIn(:)]));

    % 5. Print console detection report
    fprintf('\n=========== CCTV TAMPERING DETECTION REPORT ===========\n');
    fprintf('Reference : %s\nCurrent   : %s\n', cfg.refFile, cfg.curFile);
    fprintf('Registration : scale x %.4f / y %.4f, shift x %+.1f / y %+.1f px (%d of %d blocks)\n', ...
            reg.ax, reg.ay, reg.bx, reg.by, reg.numInliers, reg.numBlocks);
    fprintf('Brightness   : current = %.3f * reference %+.1f (verified-unchanged blocks)\n', gain, offset);
    fprintf('Thresholds   : ratio < %.3f | NCC < %.3f | diff > %.1f (alpha = %.1f %%)\n', ...
            thr.ratio, thr.ncc, thr.diff, cfg.alphaPct);
    fprintf('Cue coverage : texture %.1f %% | structure %.1f %% | intensity %.1f %% of comparable frame\n', ...
            stats.cuePctValid(1), stats.cuePctValid(2), stats.cuePctValid(3));
    fprintf('Detected changed area : %.2f %% of comparable frame (%d regions)\n', stats.detectedPct, stats.numRegions);
    fprintf('Shape completion adds : %.2f %% of comparable frame (inferred from shape)\n', 100 * det.addedFrac);
    fprintf('Edge refinement       : %+.2f %% of comparable frame (pixel-level edge, net)\n', 100 * det.refineFrac);
    fprintf('Sensitivity range     : %.1f %% to %.1f %% for alpha %.1f-%.1f %%\n', ...
            min(stats.sweepDetectedPct), max(stats.sweepDetectedPct), min(cfg.sweepAlphaPct), max(cfg.sweepAlphaPct));
    fprintf('Self-check            : %.2f %% of verified-unchanged pixels flagged\n', stats.falseAlarmTrusted);

    if stats.alarmRaised
        fprintf('Decision : TAMPERING SUSPECTED\n');
    else
        fprintf('Decision : no alarm\n');
    end

    fprintf('NOTE: this is the detected CHANGED area, not ground truth. Obstructed parts that\n');
    fprintf('      are dark/smooth in BOTH frames cannot be proven changed; they are only\n');
    fprintf('      recovered where the shape of the detected region implies them.\n');
    fprintf('Results saved in folder: %s\n', cfg.outDir);
    fprintf('=======================================================\n');
end

%% ==================== LOCAL HELPER FUNCTIONS ====================

function saveFigurePng(fig, file)
% Save a figure after styling, using an absolute path and PNG export.
    drawnow;
    folder = fileparts(file);
    if ~exist(folder, 'dir')
        [ok, msg] = mkdir(folder);
        if ~ok
            error('Cannot create output folder "%s": %s', folder, msg);
        end
    end
    try
        exportgraphics(fig, file, 'Resolution', 150);
    catch ME
        error('Failed to save figure to "%s": %s', file, ME.message);
    end
end

function writeCsv(file, header, rows)
% Write a cell array of rows (numbers or text) to a CSV file.
    fid = fopen(file, 'w');
    if fid < 0
        error('Cannot write file "%s". Check directory permissions.', file);
    end
    fprintf(fid, '%s\n', strjoin(header, ','));

    for r = 1:size(rows, 1)
        parts = cell(1, size(rows, 2));
        for c = 1:size(rows, 2)
            v = rows{r, c};
            if ischar(v)
                parts{c} = ['"' strrep(v, '"', '""') '"'];
            elseif isnan(v)
                parts{c} = 'NaN';
            else
                parts{c} = sprintf('%.6g', v);
            end
        end
        fprintf(fid, '%s\n', strjoin(parts, ','));
    end
    fclose(fid);
end
