classdef visualisation
% VISUALISATION Diagnostic dashboard generation, graph plotting, and visual styling.

    methods (Static)
        function [fig, highlight] = createDashboard(refGray, normCur, cue, mask, stats, cfg)
        % Generates the 6-panel CCTV Tampering Detection Dashboard figure.
            figVisible = 'on';
            if isfield(cfg, 'showFigures') && ~cfg.showFigures
                figVisible = 'off';
            end

            refRGB = repmat(uint8(round(refGray)), [1 1 3]);
            curRGB = repmat(uint8(round(normCur)), [1 1 3]);
            edgeBand = mask & ~morphology.erodeBox(mask, 5);

            highlight = double(curRGB);
            for ch = 1:3
                layer = highlight(:, :, ch);
                redTint = [255 0 0];
                outlineColour = [255 255 0];
                layer(mask) = 0.55 * layer(mask) + 0.45 * redTint(ch);
                layer(edgeBand) = outlineColour(ch);
                highlight(:, :, ch) = layer;
            end
            highlight = uint8(highlight);

            fig = figure('Name', 'CCTV Tampering Dashboard', 'Color', 'w', ...
                'Position', [40 40 1500 850], 'Visible', figVisible);

            subplot(2, 3, 1);
            image(refRGB);
            axis image off;
            title('1. Reference image', 'Color', 'k');

            subplot(2, 3, 2);
            image(curRGB);
            axis image off;
            title('2. Normalised current image (registered)', 'Color', 'k');

            subplot(2, 3, 3);
            imagesc(cue.diffMap, [0 255]);
            axis image off;
            title('3. Difference heatmap (local mean |diff|)', 'Color', 'k');
            colormap(jet(256));
            colorbar;

            subplot(2, 3, 4);
            image(repmat(uint8(255 * mask), [1 1 3]));
            axis image off;
            title('4. Detection mask', 'Color', 'k');

            subplot(2, 3, 5);
            image(highlight);
            axis image off;
            title('5. Suspected tampering (red)', 'Color', 'k');

            subplot(2, 3, 6);
            axSummary = gca;
            cla(axSummary);
            axis(axSummary, [0 1 0 1]);
            axis(axSummary, 'off');
            hold(axSummary, 'on');

            text(axSummary, 0.04, 0.91, '6. Detection Summary', ...
                'Units', 'normalized', 'FontName', 'Arial', 'FontSize', 13, ...
                'FontWeight', 'bold', 'Color', 'k', ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

            if stats.alarmRaised
                statusText = 'STATUS: TAMPERING SUSPECTED';
            else
                statusText = 'STATUS: NO ALARM';
            end

            text(axSummary, 0.04, 0.77, statusText, ...
                'Units', 'normalized', 'FontName', 'Arial', 'FontSize', 10, ...
                'Color', 'k', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

            summaryLines = {
                sprintf('Changed area       : %.2f%%', stats.detectedPct)
                sprintf('Pixels detected    : %d / %d', stats.nDetected, stats.nValid)
                sprintf('Connected regions  : %d', stats.numRegions)
                sprintf('Unchanged flagged  : %.2f%%', stats.falseAlarmTrusted)
                ''
            };

            text(axSummary, 0.04, 0.67, summaryLines, ...
                'Units', 'normalized', ...
                'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'left', ...
                'FontName', 'Arial', ...
                'FontSize', 10, ...
                'Color', 'k', ...
                'Interpreter', 'none');
        end

        function figs = createGraphs(stats, thr, cue, valid, cfg)
        % Generates the five analytical evaluation figures.
            figVisible = 'on';
            if isfield(cfg, 'showFigures') && ~cfg.showFigures
                figVisible = 'off';
            end

            [H, W] = size(cue.valid);

            % Graph 1: threshold sensitivity
            fig2 = figure('Name', 'Threshold sensitivity', 'Color', 'w', 'Visible', figVisible);
            plot(cfg.sweepAlphaPct, stats.sweepDetectedPct, '-o', 'LineWidth', 1.8, 'MarkerFaceColor', 'b');
            hold on; grid on;
            plot(cfg.alphaPct, stats.detectedPct, 'rs', 'MarkerSize', 11, 'LineWidth', 2);
            xlabel('Allowed false-alarm rate on verified-unchanged pixels (%)');
            ylabel('Detected changed area (% of comparable frame)');
            title('Threshold sensitivity');
            legend('Sweep', 'Chosen setting', 'Location', 'best');
            drawnow;

            % Graph 2: difference-score distribution
            fig3 = figure('Name', 'Difference-score distribution', 'Color', 'w', 'Visible', figVisible);
            bar(stats.binCentres, [stats.pctOut(:) stats.pctIn(:)], 1);
            hold on; grid on;
            yl = get(gca, 'YLim');
            plot([thr.diff thr.diff], yl, 'k--', 'LineWidth', 1.5);
            xlabel('Difference score (local mean |reference - normalised current|, 0-255)');
            ylabel('Share of pixels in group (%)');
            title('Difference-score distribution');
            legend('Outside detected region', 'Inside detected region', 'Intensity-cue threshold');

            % Graph 3: comparison of detection cues
            fig4 = figure('Name', 'Comparison of detection cues', 'Color', 'w', 'Visible', figVisible);
            bar(stats.cuePctValid, 0.6);
            hold on; grid on;
            set(gca, 'XTick', 1:5, 'XTickLabel', {sprintf('Texture\nloss'), sprintf('Structure\ndecorrel.'), ...
                sprintf('Intensity\n+ smooth'), sprintf('>= 2 cues\nagree'), sprintf('Final\nregion')});
            for c = 1:5
                text(c, stats.cuePctValid(c), sprintf('%.1f%%', stats.cuePctValid(c)), ...
                     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end
            ylabel('Pixels flagged (% of comparable frame)');
            title('Comparison of detection cues');
            set(gca, 'YLim', [0 max(stats.cuePctValid) * 1.15 + 1]);

            % Graph 4: image intensity comparison
            fig5 = figure('Name', 'Image intensity comparison', 'Color', 'w', 'Visible', figVisible);
            meansPlot = [stats.statAll.refMean stats.statAll.curMean; ...
                         stats.statDetected.refMean stats.statDetected.curMean; ...
                         stats.statUnchanged.refMean stats.statUnchanged.curMean];
            stdsPlot  = [stats.statAll.refStd stats.statAll.curStd; ...
                         stats.statDetected.refStd stats.statDetected.curStd; ...
                         stats.statUnchanged.refStd stats.statUnchanged.curStd];
            bar(meansPlot, 1);
            hold on; grid on;
            set(gca, 'XTick', 1:3, 'XTickLabel', {'Whole comparable frame', 'Detected region', 'Unchanged region'});
            offsets = [-0.15 0.15];
            for g = 1:3
                for k = 1:2
                    text(g + offsets(k), meansPlot(g, k), sprintf('%.0f\n(sd %.0f)', ...
                        meansPlot(g, k), stdsPlot(g, k)), ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 8);
                end
            end
            ylabel('Mean grey level (0-255)');
            title('Image intensity comparison');
            legend('Reference', 'Normalised current', 'Location', 'northoutside', 'Orientation', 'horizontal');
            set(gca, 'YLim', [0 max(meansPlot(:)) * 1.2 + 5]);
            drawnow;

            % Graph 5: detected vs unchanged pixels
            fig6 = figure('Name', 'Detected versus unchanged pixels', 'Color', 'w', 'Visible', figVisible);
            counts3 = [stats.nDetected stats.nUnchanged stats.nInvalid];
            bar(100 * counts3 / (H * W), 0.6);
            hold on; grid on;
            set(gca, 'XTick', 1:3, 'XTickLabel', {'Detected changed', 'Unchanged', 'Excluded (no overlap)'});
            for c = 1:3
                text(c, 100 * counts3(c) / (H * W), sprintf('%d px\n%.1f%%', ...
                    counts3(c), 100 * counts3(c) / (H * W)), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end
            ylabel('Share of full frame (%)');
            title('Detected versus unchanged pixels');
            set(gca, 'YLim', [0 100 * max(counts3) / (H * W) * 1.2 + 2]);

            figs = [fig2, fig3, fig4, fig5, fig6];
        end

        function applyStyling(allFigures)
        % Applies high-contrast typography, white backgrounds, and clear legends across figures.
            for f = 1:numel(allFigures)
                fig = allFigures(f);
                set(fig, 'Color', 'w');

                axesObjects = findall(fig, 'Type', 'axes');
                for a = 1:numel(axesObjects)
                    set(axesObjects(a), 'Color', 'w', ...
                        'XColor', 'k', 'YColor', 'k', 'ZColor', 'k', ...
                        'FontName', 'Arial');

                    textObjects = findall(axesObjects(a), 'Type', 'text');
                    for t = 1:numel(textObjects)
                        set(textObjects(t), 'Color', 'k');
                    end
                end

                legendObjects = findall(fig, 'Type', 'legend');
                for l = 1:numel(legendObjects)
                    set(legendObjects(l), 'TextColor', 'k', 'Color', 'w');
                end

                colorbarObjects = findall(fig, 'Type', 'ColorBar');
                for c = 1:numel(colorbarObjects)
                    set(colorbarObjects(c), 'Color', 'k');
                end
            end
        end
    end
end
