clear; clc; close all;

% Automatically add src folder to MATLAB path
projectDir = fileparts(mfilename('fullpath'));
if isempty(projectDir)
    projectDir = pwd;
end
addpath(fullfile(projectDir, 'src'));

fprintf('Starting CCTV Camera Tampering Detection Pipeline...\n');

%% 1. LOAD CONFIGURATION AND INPUT IMAGES
fprintf('[1/9] Loading configuration and input images...\n');
cfg = getConfig(projectDir);

refGray = imageProcessing.loadGray(cfg.refFile);
curGray = imageProcessing.loadGray(cfg.curFile);
[H, W]  = size(refGray);

if ~isequal(size(curGray), [H, W])
    warning('Image sizes differ; resampling current frame to reference size.');
    curGray = imageProcessing.resampleToSize(curGray, H, W);
end

%% 2. REGISTER THE IMAGES
fprintf('[2/9] Registering current frame to reference frame...\n');
[warpedCur, valid, trusted, reg] = registration(refGray, curGray, cfg);

%% 3. NORMALISE BRIGHTNESS
fprintf('[3/9] Normalising brightness on verified-unchanged pixels...\n');
[normCur, gain, offset] = imageProcessing.normalizeBrightness(refGray, warpedCur, trusted);

%% 4. CALCULATE INTENSITY, STRUCTURAL, AND TEXTURE CUES
fprintf('[4/9] Calculating multi-scale physical cue maps...\n');
cue = detection.computeCues(refGray, normCur, valid, trusted, cfg);

%% 5. CALCULATE THRESHOLDS AND DETECT SUSPICIOUS CHANGES
fprintf('[5/9] Calculating statistical thresholds and detecting regions...\n');
thr = detection.computeThresholds(cue, cfg.alphaPct, cfg);
det = detection.detectRegion(cue, thr, cfg);

%% 6. REFINE THE MASK
fprintf('[6/9] Refining detection mask boundaries...\n');
det.finalMask = morphology.refineMask(det.coarseMask, cue, thr, cfg);
det.refineFrac = (nnz(det.finalMask) - nnz(det.coarseMask)) / max(nnz(cue.valid), 1);
mask = det.finalMask;

%% 7. CALCULATE STATISTICS
fprintf('[7/9] Computing quantitative evaluation statistics...\n');
stats = statistics(cue, det, thr, refGray, normCur, valid, trusted, reg, gain, offset, cfg);

%% 8. GENERATE THE DASHBOARD AND FIVE GRAPHS
fprintf('[8/9] Generating 6-panel dashboard and analytical graphs...\n');
[figDashboard, highlight] = visualisation.createDashboard(refGray, normCur, cue, mask, stats, cfg);
figGraphs = visualisation.createGraphs(stats, thr, cue, valid, cfg);

%% 9. EXPORT ALL IMAGES, CSV FILES, AND SUMMARY RESULTS
fprintf('[9/9] Exporting figures, CSV tables, and summary report...\n');
exportResults(figDashboard, figGraphs, highlight, stats, cue, det, thr, reg, gain, offset, cfg);

fprintf('Pipeline execution completed successfully.\n');
