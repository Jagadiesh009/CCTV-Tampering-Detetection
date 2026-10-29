# CCTV Camera Tampering Detection Using Digital Image Processing

![MATLAB](https://img.shields.io/badge/MATLAB-Digital%20Image%20Processing-blue)
![Domain](https://img.shields.io/badge/Domain-Computer%20Vision-purple)
![Method](https://img.shields.io/badge/Method-Classical%20DIP-green)
![Status](https://img.shields.io/badge/Status-Academic%20Project-success)

A modular MATLAB-based Digital Image Processing (DIP) project for detecting potential CCTV camera tampering by comparing a normal reference frame with a current surveillance image. The system uses image registration, brightness normalisation, texture analysis, structural correlation, intensity differences, statistical thresholding, and morphological region refinement to identify suspicious changes and visualise affected areas.

The implementation is designed to operate without AI/ML models or dependence on MATLAB's Image Processing Toolbox.

## 👥 Authors and Academic Affiliation

**Project Contributors**

- [JAGADIESH009](https://github.com/JAGADIESH009) — GitHub Profile
- [Bhagyaashreee](https://github.com/Bhagyaashreee) — GitHub Profile

**Institution:** VIT-AP University  
**Location:** Amaravati, Andhra Pradesh, India  
**Domain:** Digital Image Processing  
**Implementation Language:** MATLAB

## 📖 Project Overview

CCTV surveillance systems can be affected by physical obstruction, lens occlusion, spray paint, blurring, camera movement, illumination changes, and other modifications to the camera's field of view. Such changes can reduce the usefulness of surveillance footage and may indicate potential tampering.

This project implements a classical image-processing pipeline that compares a reference CCTV image against a current image to identify significant visual changes.

### Project Objectives

- Compare a normal reference image with a potentially tampered image.
- Align image frames to compensate for small camera shifts and scale differences.
- Normalise brightness variations to reduce the influence of illumination changes.
- Extract complementary texture, structural-correlation, and intensity-difference cues.
- Segment suspicious regions using statistically derived thresholds.
- Refine detected boundaries using morphological processing and connected-component analysis.
- Estimate the percentage of the comparable image area flagged as changed.
- Generate a diagnostic dashboard, analytical graphs, heatmaps, overlays, and CSV reports.

### Key Features

- Classical Digital Image Processing without trained AI/ML models.
- Modular MATLAB implementation.
- Image registration and brightness normalisation.
- Multi-cue suspicious-region detection.
- Statistical threshold selection and sensitivity analysis.
- Morphological region refinement and connected-component analysis.
- Six-panel diagnostic dashboard.
- Five analytical evaluation graphs.
- Automatic image and CSV exports.

## 🏗️ System Architecture

The system follows a sequential processing architecture, with each module responsible for a distinct stage of the detection pipeline.

```text
┌─────────────────────────────────────────────┐
│               Input Images                  │
│  Reference Frame + Current CCTV Frame       │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│        Configuration and Image Loading      │
│        Validation, Grayscale Conversion      │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│          Image Registration and Alignment    │
│       Local Displacement and Scale Estimation│
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│       Brightness and Illumination Correction │
│       Gain/Offset Normalisation              │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│             Multi-Cue Extraction             │
│   Texture Loss │ Structural NCC │ Intensity  │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│        Statistical Thresholding and Voting   │
│        Suspicious Pixel and Region Detection │
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│           Region and Boundary Refinement     │
│       Morphology, Components, Shape Completion│
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│        Quantitative Analysis and Validation  │
│    Area Percentage, Region Counts, Sensitivity│
└──────────────────────┬──────────────────────┘
                       ▼
┌─────────────────────────────────────────────┐
│         Visualisation and Result Export      │
│ Dashboard │ Graphs │ Overlays │ CSV Reports  │
└─────────────────────────────────────────────┘
```

## ⚙️ Processing Workflow

The main entry point is `main.m`. It executes the pipeline in nine sequential stages.

### 1. Configuration and Image Ingestion

**Modules:** `getConfig.m`, `imageProcessing.m`

The configuration module defines pipeline parameters and input/output paths. The image-processing module loads the reference and current frames, validates the inputs, and converts RGB images into grayscale representations when required.

The standard luminance-weighted grayscale conversion is:

$$
I_{\text{gray}} = 0.299R + 0.587G + 0.114B
$$

Where $R$, $G$, and $B$ represent the red, green, and blue channel intensities.

### 2. Image Registration and Alignment

**Module:** `registration.m`

Small camera movements can cause differences between otherwise similar images. The registration stage uses Sobel gradient representations, overlapping image tiles, phase-correlation peaks, and robust regression to estimate local displacement and camera scale.

The estimated transformation is used to align the images before comparison. High-correlation blocks help identify reference regions considered likely to be unchanged.

### 3. Brightness Normalisation

**Module:** `imageProcessing.m`

Differences in lighting can produce intensity changes even when the scene itself remains similar. A linear gain-and-offset model is fitted using verified-unchanged pixels:

$$
I_{\text{cur,norm}} = aI_{\text{ref}} + b
$$

Where:

- $I_{\text{ref}}$ is the reference intensity.
- $I_{\text{cur,norm}}$ is the normalised current intensity.
- $a$ is the estimated brightness gain.
- $b$ is the estimated intensity offset.

This step reduces some global illumination differences before suspicious-region detection.

### 4. Multi-Cue Feature Extraction

**Modules:** `detection.m`, `imageProcessing.m`

The detector combines three complementary cues.

**Texture Loss:** Compares local gradient energy between the reference and current frames. A decrease in local texture may indicate blur or obstruction.

**Structural Decorrelation:** Uses local Normalised Cross-Correlation (NCC) to identify reductions in local structural similarity.

**Intensity Change:** Examines absolute intensity differences alongside local smoothness to identify suspicious changes that may not be captured by the other cues.

Using multiple cues helps the system analyse different types of changes rather than relying entirely on a single pixel-difference measurement.

### 5. Statistical Thresholding and Region Detection

**Modules:** `detection.m`, `morphology.m`

Detection thresholds are derived from the estimated distribution of verified-unchanged regions using a target false-alarm parameter, $\alpha$.

The pipeline combines the available detection cues through voting and identifies candidate suspicious pixels and regions.

### 6. Morphological Refinement and Shape Completion

**Module:** `morphology.m`

The candidate mask undergoes region refinement using morphological operations, connected-component labelling, and convex-hull shape completion. Fine-scale directional cues are also used to refine ambiguous pixels along candidate region boundaries.

The objective is to produce more coherent regions and improve the representation of suspicious areas, including smooth regions where conventional texture-based cues may be weak.

### 7. Statistical Measurements and Sensitivity Analysis

**Module:** `statistics.m`

The pipeline calculates detection statistics, including:

- Estimated changed-area percentage.
- Connected-region count and region measurements.
- Bounding-box information.
- An internal false-alarm self-check.
- Threshold sensitivity across multiple values of $\alpha$.

These measurements help explain how the selected thresholds influence the detection output.

### 8. Visualisation

**Module:** `visualisation.m`

The visualisation stage creates a six-panel diagnostic dashboard and five analytical graphs. The outputs allow users to inspect the input frames, detected regions, score distributions, threshold sensitivity, cue comparisons, and pixel classifications.

### 9. Export and Reporting

**Module:** `exportResults.m`

The final stage saves visualisations and tabular results under `outputs/cctv_results/`. It also prints a detection summary in the MATLAB console.

## 📁 Repository Directory Structure

```text
CCTV-Tampering-Detetection/
│
├── README.md
├── main.m
│
├── input/
│   ├── cctv_reference_normal.png
│   └── cctv_tampered.png
│
├── src/
│   ├── getConfig.m
│   ├── imageProcessing.m
│   ├── registration.m
│   ├── detection.m
│   ├── morphology.m
│   ├── statistics.m
│   ├── visualisation.m
│   └── exportResults.m
│
└── outputs/
    └── cctv_results/
        ├── cctv_dashboard.png
        ├── cctv_highlighted.png
        ├── graph1_threshold_sensitivity.png
        ├── graph2_difference_distribution.png
        ├── graph3_cue_comparison.png
        ├── graph4_intensity_comparison.png
        ├── graph5_detected_vs_unchanged.png
        ├── cctv_summary.csv
        ├── cctv_thresholds_sensitivity.csv
        ├── cctv_cue_comparison.csv
        ├── cctv_intensity_comparison.csv
        └── cctv_difference_histogram.csv
```

## 🛠️ Technologies and Requirements

| Component | Technology |
|---|---|
| Programming language | MATLAB |
| Application domain | Digital Image Processing |
| Image representation | Grayscale and image intensity matrices |
| Image alignment | Gradient analysis and phase correlation |
| Feature analysis | Texture energy, local NCC, intensity differences |
| Segmentation | Statistical thresholds and cue voting |
| Region refinement | Morphology and connected components |
| Visualisation | MATLAB figures and PNG exports |
| Data export | CSV files |
| Additional toolbox | Image Processing Toolbox not required by the implementation |

The functions are designed around MATLAB matrix operations and custom image-processing routines, avoiding dependencies on toolbox-specific functions such as `imgaussfilt`, `imopen`, `imclose`, `bwlabel`, `regionprops`, and `imfill`.

## 🚀 How to Run the Project

### Option 1: MATLAB

**Step 1 — Clone the repository**

```bash
git clone https://github.com/JAGADIESH009/CCTV-Tampering-Detetection.git
```

**Step 2 — Open the project folder**

Open MATLAB and navigate to the downloaded repository directory.

```matlab
cd('path/to/CCTV-Tampering-Detetection')
```

Replace the example path with the actual location on your computer.

**Step 3 — Verify input images**

Ensure that the following files exist in the `input` folder:

```text
cctv_reference_normal.png
cctv_tampered.png
```

**Step 4 — Run the main pipeline**

```matlab
main
```

Alternatively, open `main.m` in the MATLAB Editor and click **Run**.

**Step 5 — Inspect the generated results**

After successful execution, check:

```text
outputs/cctv_results/
```

The folder contains the generated dashboard, highlighted image, evaluation graphs, and CSV reports.

## 📐 Mathematical Models and Formulae

The following equations explain the principal image-processing concepts used by the project.

### 1. Grayscale Conversion

For an RGB image, the approximate luminance-based grayscale intensity is:

$$
I = 0.299R + 0.587G + 0.114B
$$

### 2. Absolute Intensity Difference

A basic pixel-wise difference between aligned images is:

$$
D(x, y) = \left| I_{\text{ref}}(x, y) - I_{\text{cur}}(x, y) \right|
$$

A larger $D(x, y)$ indicates a larger intensity change at the corresponding pixel. The complete pipeline also considers texture and structural cues.

### 3. Brightness Normalisation

The current image is normalised through a linear model:

$$
I_{\text{cur,norm}}(x, y) = aI_{\text{ref}}(x, y) + b
$$

Here, $a$ and $b$ are the estimated gain and offset parameters.

### 4. Gradient Energy and Texture Loss

For image intensity $I$, gradient magnitude can be represented as:

$$
G(x, y) = \sqrt{G_x(x, y)^2 + G_y(x, y)^2}
$$

Where $G_x$ and $G_y$ are horizontal and vertical gradients, respectively. Local gradient-energy comparisons help identify changes in texture.

A conceptual local texture-loss measure is:

$$
L_T = 1 - \frac{E_{\text{cur}} + \epsilon}{E_{\text{ref}} + \epsilon}
$$

Where $E_{\text{ref}}$ and $E_{\text{cur}}$ represent local gradient energies and $\epsilon$ is a small stabilising constant. This equation illustrates the concept; the precise implementation depends on the function's configured calculation.

### 5. Normalised Cross-Correlation (NCC)

For reference and current local image windows $A$ and $B$, the normalised cross-correlation is:

$$
\operatorname{NCC}(A, B) = \frac{\sum_i (A_i - \bar{A})(B_i - \bar{B})}{\sqrt{\sum_i (A_i - \bar{A})^2} \sqrt{\sum_i (B_i - \bar{B})^2}}
$$

Where $\bar{A}$ and $\bar{B}$ are the mean intensities of the windows. Lower correlation can indicate reduced structural similarity, though it may also arise from legitimate scene changes.

### 6. Changed-Area Percentage

Let $M(x, y)$ be a binary mask where 1 indicates a pixel classified as suspicious and 0 indicates a pixel not classified as suspicious. Let $\Omega$ represent the comparable analysis region.

$$
P_{\text{changed}} = \frac{\sum_{(x, y) \in \Omega} M(x, y)}{|\Omega|} \times 100
$$

This percentage represents the fraction of the analysed image area flagged by the algorithm. It is not necessarily the actual physical area obstructed in the real scene.

### 7. False-Alarm Rate

An empirical false-alarm rate on verified-unchanged pixels can be expressed as:

$$
FAR = \frac{N_{\text{unchanged flagged}}}{N_{\text{verified unchanged}}} \times 100
$$

This is an internal diagnostic estimate based on the pipeline's verified-unchanged mask, not a substitute for validation against independently labelled ground-truth images.

### 8. Threshold Sensitivity

For a threshold parameter $\alpha$, sensitivity analysis compares the resulting detected area across several parameter settings:

$$
P_{\text{changed}}(\alpha) = \frac{N_{\text{flagged}}(\alpha)}{N_{\text{analysed}}} \times 100
$$

The threshold-sensitivity graph illustrates how the estimated changed area varies as $\alpha$ changes.

## 📊 Baseline Experimental Results

The repository README records the following results for its bundled test images.

| Evaluation metric | Recorded result |
|---|---|
| Detection decision | TAMPERING SUSPECTED |
| Detected changed image area | 67.83% |
| Connected suspicious regions | 1 |
| Estimated camera scale | $(0.9887, 0.9987)$ |
| Estimated image shift | $(+8.2, +2.3)$ pixels |
| Registration inlier blocks | 29 of 232 textured blocks |
| Brightness gain | 0.850 |
| Brightness offset | +13.2 |
| Shape-completion contribution | +6.74 percentage points |
| Edge-refinement adjustment | -0.31 percentage points |
| Unchanged pixels flagged in internal self-check | 2.74% |
| Reported sensitivity range | 67.7%–70.0% |

These values describe a recorded execution of the bundled test images. They should be treated as baseline outputs rather than universal performance guarantees.

### Understanding the Results

**Detected changed area — 67.83%**

The system classified approximately 67.83% of the comparable analysed frame as changed. This is the algorithm's estimated mask coverage, not proof that 67.83% of the physical camera view was obstructed.

**Connected regions — 1**

The detected mask contained one connected region under the pipeline's region-labelling procedure.

**Camera registration**

The estimated scale and translation compensate for some differences in framing before image comparison.

**Brightness normalisation**

The gain and offset compensate for estimated global illumination differences using regions classified as likely unchanged.

**Sensitivity analysis**

The reported range shows that the detected-area estimate remained within the listed interval across the tested threshold settings. It does not, by itself, establish detection accuracy or generalisation to other CCTV scenes.

## 📈 Generated Graphs and Dashboard

The pipeline generates five analytical plots and a diagnostic dashboard.

| Output file | Purpose |
|---|---|
| `cctv_dashboard.png` | Six-panel overview of the detection pipeline |
| `cctv_highlighted.png` | Current CCTV frame with detected regions highlighted |
| `graph1_threshold_sensitivity.png` | Shows how detections vary with threshold settings |
| `graph2_difference_distribution.png` | Visualises the distribution of difference scores |
| `graph3_cue_comparison.png` | Compares outputs from the individual detection cues |
| `graph4_intensity_comparison.png` | Compares regional grayscale intensity statistics |
| `graph5_detected_vs_unchanged.png` | Displays detected, unchanged, and excluded pixel categories |

### CSV Reports

The exported CSV files provide tabular records for quantitative inspection and further analysis.

- `cctv_summary.csv` — Main detection decision and overall measurements.
- `cctv_thresholds_sensitivity.csv` — Results from threshold sensitivity sweeps.
- `cctv_cue_comparison.csv` — Cue coverage and internal false-alarm measurements.
- `cctv_intensity_comparison.csv` — Regional intensity means and standard deviations.
- `cctv_difference_histogram.csv` — Histogram bins for difference scores.

## 🎯 Applications

Potential applications include:

- CCTV scene-change monitoring.
- Identification of possible camera-view obstruction.
- Surveillance image comparison.
- Visual investigation of lens contamination or changes in image quality.
- Research and academic demonstrations of classical image processing.
- Offline evaluation of image-change detection techniques.

## ⚠️ Limitations

- The pipeline compares images; it is not a guarantee of real-time camera monitoring.
- Legitimate changes in lighting, objects, weather, or scene activity can trigger detections.
- Registration may be less reliable when images contain little texture or substantial scene changes.
- Threshold selection influences the size and shape of detected regions.
- Convex-hull shape completion can expand detected regions beyond the pixels supported by individual cues.
- The recorded changed-area percentage is not equivalent to ground-truth physical obstruction coverage.
- Accuracy and robustness should be evaluated on a labelled collection of varied scenes before operational use.

## 🔮 Future Enhancements

Potential future work includes:

- Evaluate the detector on a larger collection of independently labelled CCTV image pairs.
- Report precision, recall, F1-score, and false-positive rates against ground truth.
- Extend the comparison pipeline to sequential video frames.
- Add automated folder-based batch evaluation.
- Improve robustness to major camera movement, shadows, and dynamic scenes.
- Develop a live monitoring interface with configurable alerts.
- Compare performance against additional classical image-processing baselines.

## 📚 References and Technical Background

The project uses established concepts from digital image processing, including:

- Grayscale image representation and intensity transformations.
- Sobel gradient operators and edge analysis.
- Phase correlation for image alignment.
- Local Normalised Cross-Correlation.
- Statistical thresholding and sensitivity analysis.
- Morphological image processing.
- Connected-component analysis and convex-hull geometry.

The repository's implementation and exported outputs are the primary references for its exact pipeline configuration and reported results.


## 📄 Project Disclaimer

This project is an academic Digital Image Processing prototype intended for experimentation, demonstration, and research. Its output indicates suspicious image changes based on the implemented algorithms; it does not independently establish intentional tampering or guarantee reliable detection in every real-world surveillance environment.
