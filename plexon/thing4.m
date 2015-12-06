load response_thresholds;

[nfrequencies ndurations npolarities] = size(response_thresholds);

v=[];
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
saveas(gcf, 'current_steering_voltages.png');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('allthethings', 'var') | true
    allthethings = [];
    for f = 1:nfrequencies
        for d = 1:ndurations
            for p = npolarities:-1:1
                for r = 1:length(response_thresholds{f,d,p}.all_resp_filenames)
                    load(response_thresholds{f,d,p}.all_resp_filenames{r});
                    [ nstims nsamples nchannels ] = size(data.tdt.response_detrended);
                    allthethings(p,r*10-9:r*10,:,:) ...
                        = data.tdt.response_detrended;
                    %fprintf('%s: nonzero ratio %s, atnzr %s\n', ...
                    %    response_thresholds{f,d,p}.all_resp_filenames{r}, ...
                    %    sigfig(sum(sum(sum(data.tdt.response_detrended~=0)))/prod(size(data.tdt.response_detrended))), ...
                    %    sigfig();

                end
            end
        end
    end
end

allthethings(find(allthethings==0)) = NaN;

%v = find(data.tdt.times_aligned > data.detrend_param.range(1) ...
%    & data.tdt.times_aligned < data.detrend_param.range(2));
v = find(data.tdt.times_aligned > data.detrend_param.range(1) ...
    & data.tdt.times_aligned < data.detrend_param.response_roi(2));
v = find(data.tdt.times_aligned > 2.2e-3 ...
    & data.tdt.times_aligned < data.detrend_param.response_roi(2));
timeaxis = data.tdt.times_aligned(v)*1e3;

foo = nanmean(allthethings, 2);
foostd = nanstd(allthethings, 0, 2);
%plot(timeaxis, squeeze(foo(5,:,v,:)));
for i = [8]
    cla;
    if true
        hold on;
        shadedErrorBar(timeaxis, squeeze(foo(5, :, v, 1)), squeeze(foostd(5, :, v, 1)), 'b', 1);
        shadedErrorBar(timeaxis, squeeze(foo(18, :, v, 1)), squeeze(foostd(18, :, v, 1)), 'r', 1);
        shadedErrorBar(timeaxis, squeeze(foo(i, :, v, 1)), squeeze(foostd(i, :, v, 1)), 'g', 1);
        hold off;
        title(sprintf('Response to %s, %s and %s', labels{5}, labels{18}, labels{i}));
        xlabel('milliseconds post-pulse');
        ylabel('volts');
        legend(labels{[5 18 i]});
        foo=get(gca, 'XLim');
        foo(1)=2.2;
        set(gca, 'XLim', foo);
    elseif false
        plot(timeaxis, squeeze(foo(i,:,v,:)));
    else
        plot(timeaxis, squeeze(allthethings(i, :, v, 1)));
    end
    pause(3);
    
end
saveas(gcf, 'current_steering_two_patterns.png');
