clear;

scriptpath = fileparts(mfilename('fullpath'));
path(sprintf('%s/../lib', scriptpath), path);

d = {};

d{1} = load('current_thresholds.mat');
%d{end+1} = load('current_thresholds_8.mat');
%d{end+1} = load('current_thresholds_3.5-7.mat');
% Adding another breaks single-figure plotting!

%% Find out how many complete runs were done. Not foolproof!
nvalid = length(d{1}.frequencies);
for i = 1:length(d{1}.frequencies)
    complete_run = true;
    for j = 1:length(d{1}.polarities)
        if isempty(d{1}.all_resp{i, 1, j})
            complete_run = false;
            break;
        end
    end
    if complete_run
        nvalid = i;
    end
end
    
d{1}.current_thresholds = d{1}.current_thresholds(1:nvalid,:,:);
d{1}.current_threshold_voltages = d{1}.current_threshold_voltages(1:nvalid,:,:);
d{1}.frequencies = d{1}.frequencies(1:nvalid);
% I fucked up the recording by changing an Inf to a NaN for
% lw95rhp-2015-11-19

[nfreqs ndurs npolarities] = size(d{1}.current_thresholds);
allresp = cell(ndurs, npolarities);

for freq = 1:nfreqs
    for dur = 1:ndurs
        for pol = 1:npolarities
            [val, pos] = min(d{1}.all_resp{freq, dur, pol}(1,:));
            
            d{1}.current_thresholds(freq, dur, pol) = val;
            d{1}.current_threshold_voltages(freq, dur, pol) = d{1}.all_resp{freq, dur, pol}(2,pos);
            allresp{dur, pol} = [ allresp{dur, pol} d{1}.all_resp{freq, dur, pol} ];
        end
    end
end
for pol = 1:npolarities
    respmean(pol, :) = mean(allresp{1,pol}, 2);
    respstd(pol, :) = std(allresp{1, pol}, 0, 2);
end



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
    
    [~, sort_indices] = sort(squeeze(d{i}.current_threshold_voltages(1, 1, :)));
    
    % Need polarity_indices here for the buggy dataset lw85ry-2015-11-12:
    %[~, sort_indices] = sort(squeeze(d{i}.current_threshold_voltages(1, 1, polarity_indices)));
    load sort_indices-2015-11-19.mat;
    %sort_indices = 1:npolarities;
    
    sort_indices
    
    plotpos = 0;
    
    polarities_sorted = d{i}.polarities(sort_indices);
    
    for freq = 1:nfreqs
        
        for dur = 1:ndurs
            
            plotpos = plotpos + 1;
            
            current_thresholds_sorted = squeeze(d{i}.current_thresholds(freq, dur, sort_indices));
                        
            % FIT() requires no NANs, but doesn't care about order.
            found = find(~isnan(current_thresholds_sorted) & ~isinf(current_thresholds_sorted));
            
            ff = fit(found, ...
                     current_thresholds_sorted(found), ...
                     'poly1')
            fy = ff([1 npolarities]');
            cor = corr(current_thresholds_sorted(found), ...
                       ff(found), 'rows', 'complete');
            ci = confint(ff);
            figure(1);
            subplot(2, most+1, plotpos);
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
                    'poly1')
                fy = ff([1 npolarities]');
                cor = corr(current_threshold_voltages_sorted(found), ...
                           ff(found));

                
                
                subplot(2, most+1, plotpos + (most+1));
                plot(found, current_threshold_voltages_sorted(found), '*', ...
                    [1 npolarities], fy, 'g');

                title(sprintf('Freq %s, Half-dur %s, corr %s', ...
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
    subplot(2, most+1, most+1);
    errorbar(1:30, respmean(sort_indices, 1), respstd(sort_indices, 1));
    title('Mean response current');
    xticklabel_rotate(1:length(polarities_sorted), 90, labels, 'Fontsize', 6);
    ylabel('i');

    subplot(2, most+1, 2*(most+1));
    errorbar(1:30, respmean(sort_indices, 2), respstd(sort_indices, 2));
    title('Mean response voltage');
    xticklabel_rotate(1:length(polarities_sorted), 90, labels, 'Fontsize', 6);
    ylabel('V');    
    
end
