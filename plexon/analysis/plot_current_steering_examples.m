clear;

show_ste = true;
show_std = false;


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
            title(sprintf('HVC responses with different Area X stimulation patterns: 95%%'));
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

%set(gcf,'PaperPositionMode','auto'); 
%saveas(gcf, 'current_steering_hvc_responses.png');
%saveas(gcf, 'current_steering_hvc_responses.eps', 'epsc');
%saveas(gcf, 'current_steering_hvc_responses.fig');

set(gcf, 'renderer', 'painters');
