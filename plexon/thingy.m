clear;

d{1} = load('current_thresholds-1.mat');
d{2} = load('current_thresholds.mat');




plotpos = 0;
most = 3; % what is the largest number of experiment dimensions in any file?

for i = 1:length(d)
    
    [~, sort_indices] = sort(squeeze(d{i}.current_thresholds(1, 1, 1:length(d{i}.polarities))));
    %[~, sort_indices] = sort(squeeze(d{i}.current_threshold_voltages(1, 1, 1:length(d{i}.polarities))));
    %sort_indices = 1:30;

    plotpos = 0;
        
    polarities_sorted = d{i}.polarities(sort_indices);
    
    for frequency = 1:length(d{i}.frequencies)
        
        for dur = 1:length(d{i}.durations)
            
            ctf = squeeze(d{i}.current_thresholds(frequency, dur, :));
            ctvf = squeeze(d{i}.current_threshold_voltages(frequency, dur, :));
            cy = sort_indices;
            cy = cy(find(~isinf(ctf)));
            if ~iscolumn(cy)
                cy = cy';
            end
            
            ff = fit(cy, squeeze(d{i}.current_thresholds(frequency, dur, sort_indices)), ...
                'poly1');
            fy = ff([1 30]');
            
            plotpos = plotpos + 1;
            
            figure(1);
            subplot(length(d), most, plotpos + most * (i-1));
            %squeeze(d{i}.current_thresholds(frequency, dur, sort_indices))
            plot([1:30], squeeze(d{i}.current_thresholds(frequency, dur, sort_indices)), '*', ...
                [1 30], fy, 'g');
            title(sprintf('Freq %s, Half-dur %s', ...
                sigfig(d{i}.frequencies(frequency), 3), ...
                sigfig(d{i}.durations(dur), 3)));
            
            for p = 1:length(d{i}.polarities)
                labels{p} = dec2bin(polarities_sorted(p), log2(max(polarities_sorted)));
            end
            xticklabel_rotate(1:length(polarities_sorted), 90, labels, 'Fontsize', 6);
            ylabel('Min current');
            
            if false
                figure(2);
                subplot(length(d), most, plotpos + most * (i-1));
                plot(squeeze(d{i}.current_threshold_voltages(frequency, dur, sort_indices)), '*');
                title(sprintf('Voltage: Freq %s, Half-dur %s', ...
                    sigfig(d{i}.frequencies(frequency), 3), ...
                    sigfig(d{i}.durations(dur), 3)));
                for p = 1:length(d{i}.polarities)
                    labels{p} = dec2bin(polarities_sorted(p), log2(max(polarities_sorted)));
                end
                xticklabel_rotate(1:length(polarities_sorted), 90, labels, 'Fontsize', 6);
                ylabel('Min voltage');
            end
        end
    end
end
