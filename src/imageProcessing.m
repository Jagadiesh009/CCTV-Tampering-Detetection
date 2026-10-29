classdef imageProcessing
% IMAGEPROCESSING Core low-level digital image processing and spatial filtering.
% Implemented entirely with native MATLAB matrix operations without toolbox dependencies.

    methods (Static)
        function [g, raw] = loadGray(file)
        % Read an image and return a double-precision grayscale matrix in [0, 255].
        % Converts RGB using standard ITU-R BT.601 luminance weights: 0.299*R + 0.587*G + 0.114*B.
            if ~exist(file, 'file')
                error('File not found: "%s". Please ensure the input image exists in the input directory.', file);
            end

            try
                raw = imread(file);
            catch ME
                error('Failed to read image "%s": %s', file, ME.message);
            end

            if size(raw, 3) >= 3
                raw = raw(:, :, 1:3);
            end
            raw = double(raw);

            if max(raw(:)) > 255
                raw = raw * 255 / 65535;
            end

            if size(raw, 3) == 3
                g = 0.299 * raw(:, :, 1) + 0.587 * raw(:, :, 2) + 0.114 * raw(:, :, 3);
            else
                g = raw(:, :, 1);
            end
        end

        function [normCur, gain, offset] = normalizeBrightness(refGray, warpedCur, trusted)
        % Fits brightness gain and offset strictly over verified-unchanged pixels
        % to compensate for global illumination changes without obstruction bias.
            if nnz(trusted) > 1000
                coef = polyfit(refGray(trusted), warpedCur(trusted), 1);
                gain = coef(1);
                offset = coef(2);
            else
                gain = 1;
                offset = 0;
            end

            if ~isfinite(gain) || gain < 0.05
                gain = 1;
                offset = 0;
            end

            normCur = min(max((warpedCur - offset) / gain, 0), 255);
        end

        function M = boxMean(A, k)
        % Fast 2D separable moving-average filter over a k x k window with border replication.
            r = (k - 1) / 2;
            u = ones(k, 1) / k;
            M = conv2(u, u', imageProcessing.padReplicate(A, r), 'valid');
        end

        function mag = sobelMagnitude(A)
        % Sobel gradient spatial magnitude using 3x3 convolution kernels.
            P = imageProcessing.padReplicate(A, 1);
            gx = conv2(P, [-1  0  1; -2  0  2; -1  0  1], 'valid');
            gy = conv2(P, [-1 -2 -1;  0  0  0;  1  2  1], 'valid');
            mag = sqrt(gx .^ 2 + gy .^ 2);
        end

        function P = padReplicate(A, r)
        % Pad a 2D matrix by r pixels on all borders, repeating edge values.
            [m, n] = size(A);
            P = A([ones(1, r) 1:m m * ones(1, r)], ...
                  [ones(1, r) 1:n n * ones(1, r)]);
        end

        function out = resampleToSize(img, H, W)
        % Bilinear resampling replacement for imresize using interp2.
            [h0, w0] = size(img);
            [xq, yq] = meshgrid(linspace(1, w0, W), linspace(1, h0, H));
            out = interp2(img, xq, yq, 'linear');
        end
    end
end
