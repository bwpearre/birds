clear;

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

set(gca, 'XLim', [0 npolarities+1]);
xticklabel_rotate((1:npolarities)-0.4, 90, labels(sortorder), 'Fontsize', 8);
ylabel('Volts');
xlabel('CSC');
title('Maximum absolute voltage of any electrode vs. CSC');



%set(gcf,'PaperPositionMode','auto'); 
%saveas(gcf, 'current_steering_voltages.eps', 'epsc');
%saveas(gcf, 'current_steering_voltages.png');
%saveas(gcf, 'current_steering_voltages.fig');

