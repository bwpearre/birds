load response_thresholds;

[nfrequencies ndurations npolarities] = size(response_thresholds);

vv=[];
for f = 1:nfrequencies
    for d = 1:ndurations
        for p = 1:npolarities
            vv(f,d,p,:) = response_thresholds{f,d,p}.voltages;
        end
    end
end

i=1;
%[~, sort_indices] = sort(respmean(:,2));
%polarities_sorted = d{1}.polarities(sort_indices);
for p = 1:npolarities
    %labels{p} = sprintf('%s (%d)', dec2bin(polarities(p), log2(max(polarities))), p);
    labels{p} = sprintf('%s', dec2bin(polarities(p), log2(max(polarities))));
end



% Probably want max per channel, actually...
channel_voltage = squeeze(max(vv, [], 4));
channel_voltage_means = squeeze(nanmean(nanmean(max(vv, [], 4), 1), 2));
channel_voltage_stds = squeeze(nanstd(max(vv(:, 1, :, :), [], 4), 0, 1));
channel_voltage_counts = sum(~isnan(channel_voltage));
n_valid = sum(channel_voltage_counts == nfrequencies);
channel_voltage_95 = channel_voltage_stds * 1.96 ./ sqrt(channel_voltage_counts');

% Sort the data in order of number of missing values (e.g. due to
% overvoltage)
[~, sortorder] = sort(channel_voltage_counts, 'descend');
% Sort the complete ones in voltage ascending order, for prettiness
something = mean(channel_voltage(:,sortorder));
[~, pos] = sort(something(1:n_valid));
sortorder(1:n_valid) = sortorder(pos);
% Sort the not-totally-valid ones in the same way?
%[~, pos] = sort(something(n_valid+1:end));
%sortorder(n_valid+1:end) = sortorder(pos+n_valid);
% Actually, sort these ones by number of valid points, worst-to-best:
% (Why?)
%  sortorder(n_valid+1:end) = sortorder(end:-1:n_valid+1);

figure(1);
clf;

% Bar with errorbars
if true
    hBar = barwitherr(channel_voltage_95(sortorder), channel_voltage_means(sortorder));
end

% Plot each datum as well, in red
if true
    hold on;
    for ii=1:length(channel_voltage_means)
        tmp = channel_voltage(:,sortorder(ii)); %temporarily store data in variable "tmp"
        x = repmat(ii,1,length(tmp)); %the x axis location
        x = x+(rand(size(x))-0.5)*0.3; %add a little random "jitter" to aid visibility
        if channel_voltage_counts(sortorder(ii)) == nfrequencies
            plot(x, tmp, '.r')
        else
            plot(x, tmp, 'or', 'MarkerSize', 10 - 1.2*channel_voltage_counts(sortorder(ii)));
        end
    end
    hold off;
end
set(gca, 'XLim', [0 npolarities+1]);
xticklabel_rotate((1:npolarities)-0.4, 90, labels(sortorder), 'Fontsize', 8);
ylabel('Volts');
title('Maximum absolute voltage of any electrode vs. Current Steering Configuration');



set(gcf,'PaperPositionMode','auto'); 
saveas(gcf, 'current_steering_voltages.eps', 'epsc');
saveas(gcf, 'current_steering_voltages.png');
saveas(gcf, 'current_steering_voltages.fig');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('allthethings', 'var')
    totalsamples = zeros(1, npolarities);
    allthethings = [];
    for f = nfrequencies:-1:1
        for d = 1:ndurations
            for p = 1:npolarities
                for r = 1:length(response_thresholds{f,d,p}.all_resp_filenames)
                    load(response_thresholds{f,d,p}.all_resp_filenames{r});
                    [ nstims nsamples nchannels ] = size(data.tdt.response_detrended);
                    allthethings(p, totalsamples(p)+1:totalsamples(p)+nstims, :, :) ...
                        = data.tdt.response_detrended;
                    totalsamples(p) = totalsamples(p) + nstims;
                end
            end
        end
    end
    allthethings = allthethings * 1e6; % millivolts
end

allthethings(find(allthethings==0)) = NaN;

%v = find(data.tdt.times_aligned > data.detrend_param.range(1) ...
%    & data.tdt.times_aligned < data.detrend_param.range(2));
%v = find(data.tdt.times_aligned >= data.detrend_param.range(1) ...
%    & data.tdt.times_aligned <= data.detrend_param.range(2));
v = find(data.tdt.times_aligned >= data.detrend_param.range(1) ...
    & data.tdt.times_aligned <= data.detrend_param.response_roi(2) + 0.008);
timeaxis = data.tdt.times_aligned(v)*1e3;

foo = nanmean(allthethings, 2);
foostd = nanstd(allthethings, 0, 2);
fooste = foostd ./ repmat(sqrt(totalsamples'), ...
    1, ndurations, nsamples, nchannels);
foo95 = fooste * 1.96;

show_ste = true;
show_std = true;
%xlimits = [2e-3 data.tdt.times_aligned(max(v))]*1e3;
xlimits = [2 12];
show = [ 1:npolarities ];
show = [ 4 8 21 25 ];

colours = distinguishable_colors(length(show));
hh = [];

figure(2);
clf;
if show_ste
    if show_std
        subplot(2,1,1);
    else
        subplot(1,1,1);
    end
    hold on;
    for i = 1:length(show)
        if true
            h = shadedErrorBar(timeaxis, squeeze(foo(show(i), :, v, 1)), ...
                squeeze(foo95(show(i), :, v, 1)), ...
                {'color', colours(i,:)}, 1);
            hh(show(i)) = h.mainLine;
            title(sprintf('HVC responses with different Area X stimulation patterns: stderr'));
        else
            h = plot(timeaxis, squeeze(allthethings(show(i), :, v, 1)), 'Color', colours(i,:));
            hh(show(i)) = h(1);
        end
    end
    hold off;
    if ~show_std
        xlabel('milliseconds post-pulse');
    end
    ylabel('microvolts');
    set(gca, 'XLim', xlimits);
    legend(hh(show), labels(show), 'Location', 'NorthEast');
end

if show_std
    if show_ste
        subplot(2,1,2);
    else
        subplot(1,1,1);
    end
    hold on;
    for i = 1:length(show)
        if true
            h = shadedErrorBar(timeaxis, squeeze(foo(show(i), :, v, 1)), ...
                squeeze(foostd(show(i), :, v, 1)), ...
                {'color', colours(i,:)}, 1);
            hh(show(i)) = h.mainLine;
            title(sprintf('HVC responses with different Area X stimulation patterns: \\sigma'));
        else
            h = plot(timeaxis, squeeze(allthethings(show(i), :, v, 1)), 'Color', colours(i,:));
            hh(show(i)) = h(1);
        end
    end
    hold off;
    xlabel('milliseconds post-pulse');
    ylabel('microvolts');
    set(gca, 'XLim', xlimits);
    if ~show_ste
        legend(hh(show), labels(show), 'Location', 'NorthEast');
    end
end

set(gcf,'PaperPositionMode','auto'); 
saveas(gcf, 'current_steering_hvc_responses.png');
saveas(gcf, 'current_steering_hvc_responses.eps', 'epsc');
saveas(gcf, 'current_steering_hvc_responses.fig');

