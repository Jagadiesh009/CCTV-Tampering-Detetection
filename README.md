# CCTV Camera Tampering Detection Using Digital Image Processing

An automated, classical Digital Image Processing (DIP) pipeline in MATLAB for detecting surveillance camera tampering (physical obstruction, occlusion, spray paint, blur, and lens tampering) without AI/ML models or dependencies on the MATLAB Image Processing Toolbox.

---

## 1. Project Directory Structure

```text
CCTV_Tampering_Detection/
├── main.m                                  # Main runnable entry point
├── README.md                               # Project documentation & run guide
├── input/                                  # Input test images
│   ├── cctv_reference_normal.png           # Normal CCTV reference frame
│   └── cctv_tampered.png                   # Tampered CCTV frame
├── src/                                    # Modular MATLAB functions (no subfolders)
│   ├── getConfig.m                         # Pipeline configuration & parameter definitions
│   ├── imageProcessing.m                   # Grayscale ingestion, normalisation, and filtering
│   ├── registration.m                      # Sub-pixel alignment & verified-unchanged masks
│   ├── detection.m                         # Physical cue extraction, thresholds, and region detection
│   ├── morphology.m                        # Morphology, connected components, and boundary refinement
│   ├── statistics.m                        # Quantitative evaluation metrics & sensitivity sweeps
│   ├── visualisation.m                     # 6-panel dashboard and 5 analytical evaluation graphs
│   └── exportResults.m                     # High-contrast styling, image/CSV exports & console logging
└── outputs/
    └── cctv_results/                       # Auto-generated visual and tabular results
        ├── cctv_dashboard.png              # 6-panel diagnostic dashboard
        ├── cctv_highlighted.png            # Tampered region overlaid on current frame
        ├── graph1_threshold_sensitivity.png# Threshold sensitivity curve
        ├── graph2_difference_distribution.png # Difference score distribution
        ├── graph3_cue_comparison.png       # Multi-cue coverage comparison
        ├── graph4_intensity_comparison.png # Mean grey-level comparison across regions
        ├── graph5_detected_vs_unchanged.png# Pixel breakdown (Detected/Unchanged/Excluded)
        ├── cctv_summary.csv                # Overall metrics and detection decision
        ├── cctv_thresholds_sensitivity.csv # Sensitivity sweep tabular results
        ├── cctv_cue_comparison.csv         # Individual cue coverage and false alarm rates
        ├── cctv_intensity_comparison.csv   # Regional intensity means and standard deviations
        └── cctv_difference_histogram.csv   # Difference score histogram bins
```

---

## 2. Requirements & Toolbox Compatibility

- **MATLAB Version**: Compatible with MATLAB R2020a and newer (tested and verified on MATLAB R2026b).
- **Toolbox Requirements**: **Zero Image Processing Toolbox dependencies**.
  - All convolution, morphology, connected component labelling, convex hull extraction, and filtering algorithms are implemented natively using core MATLAB matrix operations.
  - Does **not** require `imgaussfilt`, `imopen`, `imclose`, `bwlabel`, `regionprops`, or `imfill`.

---

## 3. How to Run

1. Open MATLAB.
2. In the MATLAB Current Folder toolbar (or command window), navigate to `CCTV_Tampering_Detection`:
   ```matlab
   cd('path/to/CCTV_Tampering_Detection')
   ```
3. Run `main.m`:
   ```matlab
   main
   ```
   Or click the **Run** button (green play icon) in the MATLAB Editor with `main.m` open.

All generated outputs are automatically saved to `outputs/cctv_results/`.

---

## 4. Pipeline Execution Workflow

`main.m` is the single entry point that executes the complete 9-stage pipeline in sequential order:

1. **Configuration and Ingestion (`getConfig.m`, `imageProcessing.m`)**:
   Loads configuration parameters, validates image paths, reads input images, and converts RGB to double-precision grayscale using standard luminance weights:
   $$\text{Gray} = 0.299 R + 0.587 G + 0.114 B$$
2. **Registration and Alignment (`registration.m`)**:
   Extracts Sobel gradient representations, divides images into overlapping tiles, computes phase correlation peaks to measure local displacement, and applies robust linear regression to estimate affine camera shifts and scale. Flags high-correlation blocks as **verified-unchanged** reference regions.
3. **Brightness Normalisation (`imageProcessing.m`)**:
   Fits a linear gain and offset model strictly on verified-unchanged pixels to compensate for global illumination variations without being skewed by large obstructions:
   $$I_{\text{cur}} = \text{gain} \cdot I_{\text{ref}} + \text{offset}$$
4. **Multi-Scale Physical Cues (`detection.m`, `imageProcessing.m`)**:
   Computes three complementary spatial cues over local sliding windows:
   - **Texture Loss**: Gradient energy ratio between current and reference frames.
   - **Structural Decorrelation**: Local Normalised Cross-Correlation (NCC).
   - **Intensity Change**: Absolute difference combined with local smoothness.
5. **Statistical Thresholding & Region Detection (`detection.m`, `morphology.m`)**:
   Derives thresholds empirically from the verified-unchanged distribution at a targeted false-alarm rate $\alpha$. Combines cues via voting, performs connected component labelling, morphological filtering, and convex-hull shape completion to infer dark-on-dark obstructed regions.
6. **Pixel-Level Boundary Refinement (`morphology.m`)**:
   Applies small-window directional cues to evaluate ambiguous transition pixels along the detection perimeter.
7. **Statistical Measurements (`statistics.m`)**:
   Calculates detected percentages, bounding boxes, region counts, false alarm self-checks, and parameter sensitivity sweeps across multiple $\alpha$ levels.
8. **Visualization Generation (`visualisation.m`)**:
   Constructs the 6-panel diagnostic dashboard and five evaluation plots.
9. **Export & Reporting (`exportResults.m`)**:
   Applies high-visibility typography styling, exports publication-ready 150 DPI PNG graphics and tabular CSV summaries, and prints the console detection report.

---

## 5. Summary of Baseline Detection Results

When executed on the bundled test frames (`cctv_reference_normal.png` and `cctv_tampered.png`), the pipeline outputs:

| Metric | Measured Value | Description |
| :--- | :--- | :--- |
| **Detection Decision** | **TAMPERING SUSPECTED** | Alarm triggered (area exceeds alarm fraction) |
| **Detected Changed Area** | **67.83%** | Share of comparable overlapping frame |
| **Connected Regions** | **1** | Cohesive tampering obstruction detected |
| **Camera Registration** | Scale: $(0.9887, 0.9987)$, Shift: $(+8.2, +2.3)\text{ px}$ | 29 inlier blocks out of 232 textured blocks |
| **Brightness Normalisation** | Gain: $0.850$, Offset: $+13.2$ | Fitted on verified-unchanged blocks |
| **Shape Completion Contribution** | **+6.74%** | Recovered via convex hull over smooth background |
| **Edge Refinement Adjustment** | **-0.31%** | Net boundary adjustment from fine-scale cues |
| **Unchanged Pixels Flagged** | **2.74%** | Internal false-alarm self-check |
| **Sensitivity Range** | **67.7% to 70.0%** | Stable across $\alpha \in [0.5\%, 12.0\%]$ |
