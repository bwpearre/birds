JITTERSD = true;

%% TIMING vs. FRAMESIZE


framesize = [0.5 1 1.5 2 4];
latencies_legend = {'Ideal', 'LabView', 'Swift+serial'};
latencies_delta = [ 0.2 0 0.4 1.2 1.9;
    0.5 0.9 1.5 2.7 3.3;
    1 1.2 0.9 2.9 1.4];
jitters_delta = [ 0.2 0.3 0.4 0.6 1.1;
    0.8 0.6 0.7 0.8 1.3;
    1.1 1 1.6 0.9 2.2];

latencies_lny64_300 = [NaN -2.1 -1.1 -0.6 0.6;
    NaN -1.9 -0.2 0.6 1.2;
    NaN -1 -0.1 0.6 1.3];
jitters_lny64_300 = [NaN 2 2 2 2.2;
    NaN 3.1 2.4 2.5 2.5;
    NaN 1.9 1.9 2 2.1];

figure(1);
if JITTERSD
    subplot(1,2,1);
    cla;
    hold on;
    for i = 1:length(latencies_legend)
        errorbar(framesize+0.05*(i-2), latencies_delta(i,:), jitters_delta(i,:));
    end
    hold off;
    title('Latency: \delta-song');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (s)');
    
    subplot(1,2,2);
    cla;
    hold on;
    for i = 1:length(latencies_legend)
        errorbar(framesize+0.05*(i-2), latencies_lny64_300(i,:), jitters_lny64_300(i,:));
    end
    hold off;
    title('Latency: syllable at 300 ms');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (s)');
    legend(latencies_legend, 'Location', 'SouthEast');


else
    subplot(2,2,1);
    plot(framesize, latencies_delta);
    title('Latency: \Delta-song');
    xlabel('FFT frame interval (ms)');
    ylabel('Latency (s)');
    l = get(gca, 'YLim');
    l(1) = 0;
    set(gca, 'YLim', l);
    l = get(gca, 'XLim');
    l(1) = 0;
    set(gca, 'XLim', l);

    legend(latencies_legend, 'Location', 'SouthEast');

    subplot(2,2,2);
    plot(framesize, jitters_delta);
    title('Jitter: \Delta-song');
    xlabel('FFT frame interval (ms)');
    ylabel('Jitter (s)');
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
    ylabel('Latency (s)');
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
    ylabel('Jitter (s)');
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
latencies_syl = [ -0.4 -1.1 -0.5 -1.1 -1.3 -0.5;
    0.6 -0.2 0.6 -0.1 -1.4 0.4];
jitters_syl = [ 2.3 2 2.1 2 2.1 2.2;
    2.1 1.8 2.1 1.9 2.1 2.2];

figure(2);

if JITTERSD
    subplot(1,1,1);
    cla;
    hold on;
    for i = 1:length(legend_syl)
        errorbar(syllables+0.05*(i-2), latencies_syl(i,:), jitters_syl(i,:), 'o');
    end
    hold off;
    title('Latency vs. test syllable');
    xlabel('Syllable @t (ms)');
    ylabel('Latency (s)');
    legend(legend_syl, 'Location', 'NorthEast');
else
    subplot(1,2,1);
    plot(syllables, latencies_syl, 'o');
    title('Latency vs. test syllable');
    xlabel('Syllable @t (ms)');
    ylabel('Latency (s)');
    l = get(gca, 'YLim') + [-0.5 0.5];
    set(gca, 'YLim', l);
    l = get(gca, 'XLim') + [-20 20];
    set(gca, 'XLim', l);
    legend(legend_syl, 'Location', 'NorthEast');
    
    
    subplot(1,2,2);
    plot(syllables, jitters_syl, 'o');
    title('Jitter vs. test syllable');
    xlabel('Syllable @t (ms)');
    ylabel('Jitter (s)');
    l = get(gca, 'YLim') + [-0.05 0.05];
    set(gca, 'YLim', l);
    l = get(gca, 'XLim') + [-20 20];
    set(gca, 'XLim', l);
end

%% TIMING vs. DETECTOR

% delta; bird
legend_det = {'\delta-syllable', 'Song 300 ms'};
detectors = {'Ideal', 'LabView','Swift+serial','Swift+audio','Matlab+serial','Matlab+audio'};
latencies_det = [ 0.4 1.5 0.9 5.9 8.1 12.5;
    -1.1 -0.2 -0.1 1.2 3.8 8.4];
jitters_det = [ 0.4 0.7 1.6 2.6 2.3 5.9;
    2 2.4 1.9 4.9 2 5.9];

detectors_num = 1:length(detectors);

figure(3);

if JITTERSD
    subplot(1,1,1);
    cla;
    hold on;
    for i = 1:length(legend_det)
        errorbar(detectors_num, latencies_det(i,:), jitters_det(i,:), 'o');
    end
    title('Latency vs. detector');
    ylabel('Latency (s)');
    set(gca, 'XLim', [detectors_num(1)-0.5 detectors_num(end)+0.5]);
    xticklabel_rotate(detectors_num, 45, detectors);
    legend(legend_det, 'Location', 'NorthWest');
else
    
    subplot(1,2,1);
    plot(detectors_num, latencies_det, 'o');
    title('Latency vs. detector');
    ylabel('Latency (s)');
    set(gca, 'XLim', [detectors_num(1)-0.5 detectors_num(end)+0.5]);
    xticklabel_rotate(detectors_num, 45, detectors);
    legend(legend_det, 'Location', 'NorthWest');
    
    
    subplot(1,2,2);
    plot(detectors_num, jitters_det, 'o');
    title('Jitter vs. detector');
    ylabel('Jitter (s)');
    set(gca, 'XLim', [detectors_num(1)-0.5 detectors_num(end)+0.5]);
    xticklabel_rotate(detectors_num, 45, detectors);
end
