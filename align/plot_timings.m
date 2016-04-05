JITTERSD = true;

%% TIMING vs. FRAMESIZE


framesize = [0.5 1 1.5 2 4];
latencies_legend = {'Ideal', 'LabView', 'Swift+serial'};
latencies_delta = [ 0.249 0.159 0.658 1.43 1.875;
    0.521 0.945 1.516 2.678 3.287;
    1.003 1.177 0.878 2.878 1.403];
jitters_delta = [ 0.143 0.233 0.377 0.519 1.144;
    0.774 0.566 0.691 0.753 1.344;
    1.119 0.958 1.626 0.857 2.211];

latencies_lny64_300 = [NaN -2.145 -1.032 -0.606 0.558;
    NaN -1.852 -0.182 0.593 1.24;
    NaN -0.988 -0.075 0.588 1.259];
jitters_lny64_300 = [NaN 2.032 1.951 1.989 2.152;
    NaN 3.094 2.371 2.451 2.485;
    NaN 1.852 1.912 1.960 2.105];


figure(1);
if JITTERSD
    subplot(1,2,1);
    cla;
    hold on;
    for i = 1:length(latencies_legend)
        errorbar(framesize+0.05*(i-2), latencies_delta(i,:), jitters_delta(i,:));
    end
    hold off;
    title('Latency: \delta-syllable');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (ms)');
    set(gca, 'xlim', [0.25 4.25]);
    legend off

    subplot(1,2,2);
    cla;
    hold on;
    for i = 1:length(latencies_legend)
        errorbar(framesize+0.05*(i-2), latencies_lny64_300(i,:), jitters_lny64_300(i,:));
    end
    hold off;
    title('Latency: t^*_4');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (ms)');
    set(gca, 'xlim', [0.75 4.25]);
    legend(latencies_legend, 'Location', 'SouthEast');


else
    subplot(2,2,1);
    plot(framesize, latencies_delta);
    title('Latency: \delta-syllable');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (ms)');
    l = get(gca, 'YLim');
    l(1) = 0;
    set(gca, 'YLim', l);
    l = get(gca, 'XLim');
    l(1) = 0;
    set(gca, 'XLim', l);

    legend(latencies_legend, 'Location', 'SouthEast');

    subplot(2,2,2);
    plot(framesize, jitters_delta);
    title('Jitter: \delta-syllable');
    xlabel('FFT frame interval (ms)');
    ylabel('Jitter (ms)');
    l = get(gca, 'YLim');
    l(1) = 0;
    set(gca, 'YLim', l);
    l = get(gca, 'XLim');
    l(1) = 0;
    set(gca, 'XLim', l);
    
    subplot(2,2,3);
    plot(framesize, latencies_lny64_300);
    title('Latency: syllable at 300ms');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (ms)');
    %l = get(gca, 'YLim');
    %l(1) = 0;
    %set(gca, 'YLim', l);
    l = get(gca, 'XLim');
    l(1) = 0;
    set(gca, 'XLim', l);
    
    subplot(2,2,4);
    plot(framesize, jitters_lny64_300);
    title('Jitter: syllable at 300ms');
    xlabel('FFT frame interval (ms)');
    ylabel('Jitter (ms)');
    l = get(gca, 'YLim');
    l(1) = 0;
    set(gca, 'YLim', l);
    l = get(gca, 'XLim');
    l(1) = 0;
    set(gca, 'XLim', l);
end


%% TIMING vs. SYLLABLE

syllables = [ 150:50:400 ];

% ideal; swift+serial
legend_syl = {'Ideal', 'Swift+serial'};
xticl = {'t^*_1', 't^*_2', 't^*_3', 't^*_4', 't^*_5', 't^*_6'};
latencies_syl = [ -0.396 -1.085 -0.502 -1.032 -1.32 -0.504;
    0.599 -0.211 0.609 -0.075 -1.442 0.394];
jitters_syl = [ 2.303 1.966 2.110 1.951 2.110 2.180;
    2.120 1.771 2.071 1.912 2.103 2.155];

figure(2);

if JITTERSD
    subplot(1,1,1);
    cla;
    hold on;
    for i = 1:length(legend_syl)
        errorbar(syllables+5*(i-2), latencies_syl(i,:), jitters_syl(i,:), 'o');
    end
    hold off;
    title('Latency vs. trigger point');
    xlabel('Trigger point');
    ylabel('Latency (ms)');
    set(gca, 'xtick', syllables, 'xticklabel', xticl);
    legend(legend_syl, 'Location', 'NorthEast');
else
    subplot(1,2,1);
    plot(syllables, latencies_syl, 'o');
    title('Latency vs. test syllable');
    xlabel('Syllable @t (ms)');
    ylabel('Latency (ms)');
    l = get(gca, 'YLim') + [-0.5 0.5];
    set(gca, 'YLim', l);
    l = get(gca, 'XLim') + [-20 20];
    set(gca, 'XLim', l);
    legend(legend_syl, 'Location', 'NorthEast');
    
    
    subplot(1,2,2);
    plot(syllables, jitters_syl, 'o');
    title('Jitter vs. test syllable');
    xlabel('Syllable @t (ms)');
    ylabel('Jitter (ms)');
    l = get(gca, 'YLim') + [-0.05 0.05];
    set(gca, 'YLim', l);
    l = get(gca, 'XLim') + [-20 20];
    set(gca, 'XLim', l);
end

latencies_mean = mean(latencies_syl')
latencies_std = std(latencies_syl')
latencies_ste95 = 1.96 * latencies_std / sqrt(length(syllables))
jitters_mean = mean(jitters_syl')
jitters_std = std(jitters_syl')
jitters_ste95 = 1.96 * jitters_std / sqrt(length(syllables))


%% TIMING vs. DETECTOR

% delta; bird
legend_det = {'\delta-syllable', 'Trigger t^*_4'};
detectors = {'Ideal', 'LabView','Swift+serial','Swift+audio','Matlab+serial','Matlab+audio'};
latencies_det = [ 0.658 1.516 0.878 5.886 8.059 12.491;
    -1.032 -0.182 -0.075 1.242 3.794 8.367];
jitters_det = [ 0.377 0.691 1.626 2.552 2.324 5.874;
    1.951 2.371 1.912 4.877 2.043 5.882];

detectors_num = 1:length(detectors);

figure(3);

if JITTERSD
    subplot(1,1,1);
    cla;
    hold on;
    for i = 1:length(legend_det)
        errorbar(detectors_num+0.1*(i-2), latencies_det(i,:), jitters_det(i,:), 'o');
    end
    title('Latency vs. detector');
    ylabel('Latency (ms)');
    set(gca, 'XLim', [detectors_num(1)-0.5 detectors_num(end)+0.5]);
    xticklabel_rotate(detectors_num, 30, detectors);
    legend(legend_det, 'Location', 'NorthWest');
else
    
    subplot(1,2,1);
    plot(detectors_num, latencies_det, 'o');
    title('Latency vs. detector');
    ylabel('Latency (ms)');
    set(gca, 'XLim', [detectors_num(1)-0.5 detectors_num(end)+0.5]);
    xticklabel_rotate(detectors_num, 45, detectors);
    legend(legend_det, 'Location', 'NorthWest');
    
    
    subplot(1,2,2);
    plot(detectors_num, jitters_det, 'o');
    title('Jitter vs. detector');
    ylabel('Jitter (ms)');
    set(gca, 'XLim', [detectors_num(1)-0.5 detectors_num(end)+0.5]);
    xticklabel_rotate(detectors_num, 45, detectors);
end
