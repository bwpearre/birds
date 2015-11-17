clear;

scriptpath = fileparts(mfilename('fullpath'));
path(sprintf('%s/../lib', scriptpath), path);

d = {};

%d{1} = load('current_thresholds-1.mat');
d{end+1} = load('current_thresholds.mat');




plotpos = 0;

most = 0; % what is the largest number of experiment dimensions in any file?
for i = 1:length(d)
    foo = size(d{i}.current_thresholds);
    foo = prod(foo(1:2));
    most = max(most, foo);
end


for i = 1:length(d)
    
    [nfreqs ndurs npolarities] = size(d{i}.current_thresholds);
    polarity_indices = [1:npolarities];

    [~, sort_indices] = sort(squeeze(d{i}.current_thresholds(1, 1, :)));
    %[~, sort_indices] = sort(squeeze(d{i}.current_threshold_voltages(1, 1, :)));
    %sort_indices = 1:npolarities;
    

    plotpos = 0;
        
    polarities_sorted = d{i}.polarities(sort_indices);
    
    for freq = 1:nfreqs
        
        for dur = 1:ndurs
            
            plotpos = plotpos + 1;
            
            current_thresholds_sorted = squeeze(d{i}.current_thresholds(freq, dur, sort_indices));
                        
            % FIT() requires no NANs, but doesn't care about order.
            found = find(~isinf(current_thresholds_sorted));
            
            ff = fit(found, ...
                     current_thresholds_sorted(found), ...
                     'poly1');
            fy = ff([1 npolarities]');
            cor = corr(current_thresholds_sorted(found), ...
                       ff(found), 'rows', 'complete');
            ci = confint(ff);
            figure(1);
            subplot(length(d), most, plotpos + most * (i-1));
            %squeeze(d{i}.current_thresholds(frequency, dur, sort_indices))
            plot(found, current_thresholds_sorted(found), '*', ...
                [1 npolarities], fy, 'g');
            title(sprintf('Freq %s, Half-dur %s, corr %s', ...
                sigfig(d{i}.frequencies(freq), 3), ...
                sigfig(d{i}.durations(dur), 3), ...
                sigfig(cor, 3)));
            
            
            for p = 1:length(d{i}.polarities)
                labels{p} = dec2bin(polarities_sorted(p), log2(max(polarities_sorted)));
            end
            xticklabel_rotate(1:length(polarities_sorted), 90, labels, 'Fontsize', 6);
            ylabel('Min current');
            
            if true
                
                current_threshold_voltages_sorted = squeeze(d{i}.current_threshold_voltages(freq, dur, sort_indices));
                
                ff = fit(found, ...
                    current_threshold_voltages_sorted(found), ...
                    'poly1');
                fy = ff([1 npolarities]');
                cor = corr(current_threshold_voltages_sorted(found), ...
                           ff(found));

                
                figure(2);
                
                subplot(length(d), most, plotpos + most * (i-1));
                plot(found, current_threshold_voltages_sorted(found), '*', ...
                    [1 npolarities], fy, 'g');

                title(sprintf('Voltage: Freq %s, Half-dur %s, corr %s', ...
                    sigfig(d{i}.frequencies(freq), 3), ...
                    sigfig(d{i}.durations(dur), 3), ...
                    sigfig(cor, 3)));
                
                for p = 1:length(d{i}.polarities)
                    labels{p} = dec2bin(polarities_sorted(p), log2(max(polarities_sorted)));
                end
                xticklabel_rotate(1:length(polarities_sorted), 90, labels, 'Fontsize', 6);
                ylabel('Min voltage');
            end
        end
    end
end
