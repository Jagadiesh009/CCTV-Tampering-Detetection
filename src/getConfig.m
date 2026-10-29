function cfg = getConfig(projectDir)
% GETCONFIG Returns configuration settings and parameters for CCTV tampering detection.
%
% Syntax:
%   cfg = getConfig()
%   cfg = getConfig(projectDir)
%
% Description:
%   Builds paths relative to the project root directory, defines algorithm
%   parameters for registration, multi-cue analysis, morphological operations,
%   edge refinement, sensitivity analysis, and output generation.

    if nargin < 1 || isempty(projectDir)
        srcDir = fileparts(mfilename('fullpath'));
        projectDir = fileparts(srcDir);
    end

    % Base Paths
    cfg.projectDir  = projectDir;
    cfg.inputDir    = fullfile(projectDir, 'input');
    cfg.outDir      = fullfile(projectDir, 'outputs', 'cctv_results');
    cfg.refFile     = fullfile(cfg.inputDir, 'cctv_reference_normal.png');
    cfg.curFile     = fullfile(cfg.inputDir, 'cctv_tampered.png');
    cfg.showFigures = true;      % false = save figures without showing

    % Camera Registration Parameters
    cfg.regBlock     = 96;
    cfg.regStep      = 48;
    cfg.regMinTex    = 25;
    cfg.regMinPeak   = 0.20;
    cfg.regRelPeak   = 0.40;
    cfg.regTolPx     = 2.0;
    cfg.regMinInlier = 6;

    % Local Cue Analysis Parameters
    cfg.smoothWin    = 3;
    cfg.localWin     = 21;
    cfg.texturePct   = 25;
    cfg.alphaPct     = 1;
    cfg.smoothPct    = 25;
    cfg.seedVotes    = 2;

    % Morphology and Region Logic
    cfg.coarse          = 4;
    cfg.closeCells      = 3;
    cfg.openCells       = 3;
    cfg.minRegionFrac   = 0.01;
    cfg.alarmFraction   = 0.10;
    cfg.edgeSmoothCells = 7;
    cfg.padCells        = 30;

    % Edge and Corner Handling
    cfg.hullSmoothPct   = 60;
    cfg.notchCells      = 9;
    cfg.borderSnapCells = 6;
    cfg.refineGrow      = 14;
    cfg.refineWin       = 7;
    cfg.refineAlphaPct  = 5;
    cfg.refineSmoothPx  = 9;

    % Sensitivity Sweep and Histogram Bins
    cfg.sweepAlphaPct = [0.5 1 2 3 5 8 12];
    cfg.histEdges     = 0:5:260;

    % Ensure output directory exists safely
    if ~exist(cfg.outDir, 'dir')
        [ok, msg] = mkdir(cfg.outDir);
        if ~ok
            error('Failed to create output folder "%s": %s', cfg.outDir, msg);
        end
    end
end
