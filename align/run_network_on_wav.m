function [ out ] = run_network_on_wav(net, filename);

[ MIC_DATA, fs ] = audioread(filename);

ntoi = length(net.toi);

if fs ~= net.samplerate
        [a b] = rat(net.samplerate/fs);
        
        MIC_DATA = double(MIC_DATA);
        MIC_DATA = resample(MIC_DATA, a, b);
end

%MIC_DATA = MIC_DATA / max(max(max(MIC_DATA)), -min(min(MIC_DATA)));


noverlap = net.fft_size - (floor(net.samplerate * net.fft_time_shift_seconds_target));

window = hamming(net.fft_size);

[spectrograms freqs times] = spectrogram(MIC_DATA(:,1), window, noverlap, [], net.samplerate);
% Adjust "times" to reflect the time at which the information is actually available--i.e. the end,
% rather than the middle, of the window:
times = times - times(1) + net.fft_size/net.samplerate;
[nfreqs, ntimes] = size(spectrograms);

%spectrograms = single(spectrograms);


% Create a pretty graphic for display (which happens later)
spectrograms = abs(spectrograms);


%% Draw the pretty full-res spectrogram and the targets
colours = distinguishable_colors(ntoi);
%figure(43);
subplot(2,1,1);
imagesc([times(1) times(end)]*1000, [freqs(1) freqs(end)]/1000, spectrograms);
axis xy;
xlabel('Time (ms)');
ylabel('Frequency (kHz)');
yl = get(gca, 'YLim');
xl = get(gca, 'XLim');

nwindows = ntimes - net.time_window_steps + 1;

testout = zeros(ntimes, length(net.toi));
nnsetX = zeros(length(net.freq_range_ds) * net.time_window_steps, ntimes);
for tstep = net.time_window_steps : ntimes
    nnsetX(:, tstep) = reshape(spectrograms(net.freq_range_ds, ...
        tstep - net.time_window_steps + 1  :  tstep), ...
        [], 1);
end
nnsetX = zscore(nnsetX);

testout = sim(net.net, nnsetX)';

abovethreshold = bsxfun(@minus, testout, net.trigger_thresholds);
hits = abovethreshold > 0;

if false
    subplot(2,1,2);
    cla;
    hold on;
    for i = 1:ntoi
        plot(times'*1000, abovethreshold(:, i), 'Color', colours(i,:));
        legend_names{i} = int2str(i);
    end
    set(gca, 'XLim', xl);
    line(xl, [0 0], 'Color', [0 0 0]);
    hold off;
    legend(legend_names);
    title(filename);
    

    subplot(2,1,1);
    for i = 1:ntoi
        xv = times(find(hits(:,i))')*1000;
        xv = repmat(xv, 2, 1);
        nh = size(xv, 2);
        if nh
            yv = repmat(yl', 1, nh);
            line(xv, yv, 'Color', colours(i, :));
        end
    end
    
    drawnow;
end

testout = testout(net.time_window_steps:end, :);

out = [zeros(nwindows, 3) testout];
