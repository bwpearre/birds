clear;

show_trial_scatter = false;
show_reanalysed_thresholds = false;
show_bar = false;
show_which_ones = [ 1  2   4   5    7    9   11   13   16    17   19    23    27    29    30    31 ];

load('response_thresholds');

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
%sortorder = 1:length(sortorder);
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

if exist('show_which_ones', 'var') & ~isempty(show_which_ones)
    sortorder = sortorder(show_which_ones);
end

figure(3);
clf;
subplot(12,1,[1:11]);

if show_bar
    % Bar with errorbars
    hBar = bar(channel_voltage_means(sortorder));
end

% Pull in the maximum-likelihood sigmoid fit results:
if show_reanalysed_thresholds
    if exist('reanalysed_thresholds.mat', 'file')
        load('reanalysed_thresholds.mat');
        for i = 1:length(polarities)
            foo = find(reanalysed_thresholds(:,1) == polarities(i) & reanalysed_thresholds(:,2) ~= 0);
            if length(foo) == 1
                reanalysed_voltage_loc(i) = foo;
                reanalysed_reordered(i,:) = reanalysed_thresholds(reanalysed_voltage_loc(i),:);
            elseif length(foo) == 0
                disp(sprintf('Couldn''t find a reanalysed voltage for %d', polarities(i)));
                reanalysed_voltage_loc(i) = NaN;
                reanalysed_reordered(i,:) = NaN * ones(1, size(reanalysed_thresholds, 2));
            end
        end
    else
        warning('Requested show_reanalysed_thresholds but reanalysed_thresholds.mat does not exist.');
    end
end


%reanalysed_reordered = reanalysed_thresholds(reanalysed_voltage_loc,:);

if show_trial_scatter
    %scatterrand = (rand(1,size(channel_voltage,1))-0.5)*0.5;
    scatterrand = linspace(-0.2, 0.2, size(channel_voltage,1));
    % Plot each datum as well, invisibly, to get auto-limit scaling
    hold on;
    for ii=1:length(channel_voltage_means)
        tmp = channel_voltage(:,sortorder(ii)); %temporarily store data in variable "tmp"
        x = repmat(ii,1,length(tmp)); %the x axis location
        x = x+scatterrand(1:length(x)); %add a little random "jitter" to aid visibility
        if channel_voltage_counts(sortorder(ii)) == nfrequencies
            plot(x, tmp, '.r')
        else
            plot(x, tmp, 'or', 'MarkerSize', 30 - 1.2*channel_voltage_counts(sortorder(ii)));
        end
    end
    hold off;
    autoylim = get(gca, 'YLim');
end

if show_reanalysed_thresholds
    errorbars_offset = 0.1;
else
    errorbars_offset = 0;
end


hold on;
for ii=1:length(sortorder) % channel_voltage_means)
    if show_reanalysed_thresholds
        % Plot centres for the maximum-likelihood estimates
        scatter(ii+errorbars_offset, reanalysed_reordered(sortorder(ii),2), ...
            40*reanalysed_reordered(sortorder(ii),3)+eps, [0 0.5 0], '+');
        
        % Plot error bars for the maximum-likelihood estimates
        if reanalysed_reordered(sortorder(ii),4) > 0 && reanalysed_reordered(sortorder(ii),4) < 3.5
            line([1 1]*ii+errorbars_offset, reanalysed_reordered(sortorder(ii),4:5), ...
                'Color', [0 0.7 0], 'LineWidth', 5);
            %'Color', [0 0.5 0], 'LineWidth', reanalysed_reordered(sortorder(ii),3));
        end
    end
        
    % Plot error bars for the threshold-scan bars
    line([1 1]*ii-errorbars_offset, ...
        channel_voltage_means(sortorder(ii))+[-1 1]*channel_voltage_95(sortorder(ii)), ...
        'Color', [0 0 0], 'LineWidth', 2);
    if ~show_bar
        line(ii+[-0.2 0.2] - errorbars_offset, channel_voltage_means(sortorder(ii))*[1 1], 'Color', [0 0 0], 'LineWidth', 2);
    end
        
    if show_trial_scatter
        % Replot scatter of each sample, so they will be on top:
        tmp = channel_voltage(:,sortorder(ii)); %temporarily store data in variable "tmp"
        x = repmat(ii,1,length(tmp)); %the x axis location
        x = x+scatterrand(1:length(x)); %add a little random "jitter" to aid visibility
        if channel_voltage_counts(sortorder(ii)) == nfrequencies
            plot(x, tmp, '.r')
        else
            plot(x, tmp, 'or', 'MarkerSize', 50 - 5*channel_voltage_counts(sortorder(ii)));
        end
    end
    hold off;
end

if show_trial_scatter
    set(gca, 'YLim', autoylim);
end

set(gca, 'XLim', [0 length(sortorder)+1]);
ylabel('Volts');
%xlabel('CSC');
xticklabel_rotate((1:length(sortorder)), 45, labels(sortorder), 'Fontsize', 8);
title('Maximum absolute voltage of any electrode vs. CSC');

axfoo = axes('Position', [0 0 1 1], 'Visible', 'off');
axes(axfoo);
mstext = text(0.5, 0.05, 'Current Steering Configuration', 'HorizontalAlignment', 'center');

%set(gcf,'PaperPositionMode','auto'); 
%saveas(gcf, 'current_steering_voltages.eps', 'epsc');
%saveas(gcf, 'current_steering_voltages.png');
%saveas(gcf, 'current_steering_voltages.fig');

