clear;

scriptdir = fileparts(mfilename('fullpath'));
path(sprintf('%s/../lib', scriptdir), path);


load response_thresholds;

[nfrequencies ndurations npolarities] = size(response_thresholds);


for f = 1:nfrequencies
    for d = 1:ndurations
        for p = 1:npolarities
            v(f,d,p,:) = response_thresholds{f,d,p}.voltages;
        end
    end
end

i=1;
%[~, sort_indices] = sort(respmean(:,2));
%polarities_sorted = d{1}.polarities(sort_indices);
for p = 1:npolarities
    labels{p} = dec2bin(polarities(p), log2(max(polarities)));
end



% Probably want max per channel, actually...
channel_voltage_means = squeeze(mean(mean(max(v, [], 4), 1), 2));
channel_voltage_stds = squeeze(std(max(v(:, 1, :, :), [], 4), 0, 1));

[~, sortorder] = sort(channel_voltage_means);

clf;
barwitherr(channel_voltage_stds(sortorder), channel_voltage_means(sortorder));
set(gca, 'XLim', [0 npolarities+1]);
xticklabel_rotate((1:npolarities), 90, labels(sortorder), 'Fontsize', 8);
ylabel('Volts');
title('Maximum absolute voltage of any electrode vs. Current Steering Configuration');
saveas(gcf, 'Voltage_vs_CurrentSteering.png');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
allthethings = [];
for f = 1:nfrequencies
    for d = 1:ndurations
        for p = npolarities:-1:1
            
            for r = 1:length(response_thresholds{f,d,p}.all_resp_filenames)
                load(response_thresholds{f,d,p}.all_resp_filenames{r});
                [ nstims nsamples nchannels ] = size(data.tdt.response_detrended);
                allthethings(p,end+1:end+nstims,:,:) ...
                    = data.tdt.response_detrended;
            end
        end
    end
end

v = find(data.tdt.times_aligned > data.detrend_param.range(1) ...
    & data.tdt.times_aligned < data.detrend_param.range(2));
v = find(data.tdt.times_aligned > data.detrend_param.response_roi(1) ...
    & data.tdt.times_aligned < data.detrend_param.response_roi(2));
timeaxis = data.tdt.times_aligned(v);

foo = mean(allthethings, 2);
foostd = std(allthethings, 0, 2);
%plot(timeaxis, squeeze(foo(5,:,v,:)));
for i = 1:npolarities
    cla;
    if true
        hold on;
        shadedErrorBar(timeaxis, squeeze(foo(i, :, v, 2)), squeeze(foostd(i, :, v, 2)));
        shadedErrorBar(timeaxis, squeeze(foo(i, :, v, 1))+1e-5, squeeze(foostd(i, :, v, 1)));
        hold off;
        title(sprintf('Polarity %d', i));
        xlabel('milliseconds post-pulse');
        ylabel('volts');
    else
        plot(timeaxis, squeeze(foo(1,:,v,:)));
    end
    pause
    
end

