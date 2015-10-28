function [ spikes r ] = look_for_spikes(response, data, d, detrend, handles);

%% This is obsolete, for now. Change to look_for_spikes_xcorr(d,data,detrend_param,...)
a(0)

% If response_detrended is [], 

[ nstims nsamples nchannels ] = size(d.response);
s = size(response);
%if length(s) == 3 & nstims == 1
%    response = reshape(response, s(2:3));
%end

times = d.times_aligned;

minstarttime = 0.001 + times(d.stim_active_indices(end));
maxendtime = -0.0005 + 1/data.repetition_Hz;
maxendtime = min(maxendtime, d.times_aligned(nsamples));

roi = detrend.response_roi;
baseline = detrend.response_baseline;
roi(1) = max(roi(1), minstarttime);
baseline(2) = min(baseline(2), maxendtime);

roii = find(times > roi(1) & times < roi(2));
baselinei = find(times > baseline(1) & times < baseline(2));
validi = find(times > roi(1) & times < baseline(2));



disp(sprintf('Look for spikes: toi [%g %g] ms, baseline [%g %g] ms', ...
    roi(1)*1000, roi(2)*1000, baseline(1)*1000, baseline(2)*1000));
if length(baselinei) < 10
    disp('   ...the baseline region is too short!');
    r = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end    
if length(roii) < 10
    disp('   ...the ROI region is too short!');
    r = zeros(1, nchannels);
    spikes = zeros(1, nchannels);
    return;
end    

%figure(1);
%plot(response(1:200,9),'b');


%%% This is a disgusting kludge: because my channel index is the third of
%%% three indices into the array, if there is only one channel, then the
%%% silent trailing dimension 1 is dropped from indexing.  BUT since I've
%%% averaged response, I can flip it and pretend that the multistim index is
%%% the channel index.
if nchannels == 1 && ndims(response) == 2
    response = response';
end


%[B A] = ellip(2, .5, 40, [300 10000]/((d.fs))/2));
%[B A]= ellip(2, .5, 40, 300/(d.fs/2), 'high');
%for i = 1:nchannels
%    response(:, i) = filtfilt(B, A, squeeze(response(:, i)));
%end




if exist('handles') & false
    set(handles.axes2, 'ColorOrder', distinguishable_colors(nchannels));
    cla(handles.axes2);
    hold(handles.axes2, 'on');
    for i = 1:nchannels
        plot(handles.axes2, ...
            times, ...
            response(:, i));
    end
    set(handles.axes2, 'XLim', get(handles.axes1, 'XLim'));
    hold(handles.axes2, 'off');
end



detector = '';
detector = 'xcorr';
%detector = 'rms';
%detector = 'range';
%detector = 'std';
%detector = 'threshold';
%detector = 'convolve';
%detector = 'spectrogram';

switch detector
    
    case 'xcorr'
        if isfield(data, 'detrend') & isequal(detrend, data.detrend)
            response = d.response_detrended;
        elseif ndims(response) == 3 & nstims > 1
            disp('Using response passed in as first argument.  I hope it''s detrended!');
        else
            disp('look_for_spikes: Detrending...');
            [ response trend ] = detrend_response(d.response, data.tdt, data, detrend);
        end
        
        xcorr_nsamples = round(0.001 * d.fs);
        parfor channel = 1:nchannels
            foo(channel,:,:) = xcorr(response(:, roii, channel)', xcorr_nsamples, 'none');
            cow(channel,:,:) = xcorr(response(:, baselinei, channel)', xcorr_nsamples, 'none');
        end
        
        a = 1:nstims+1:nstims^2;
        foo(:, :, a) = zeros(nchannels, size(foo,2), nstims);
        cow(:, :, a) = zeros(nchannels, size(cow,2), nstims);
        if exist('handles')
            imagesc(squeeze(foo(4,:,:)), 'Parent', handles.axes2);
            imagesc(squeeze(cow(4,:,:)), 'Parent', handles.axes4);
            colorbar('Peer', handles.axes2);
            colorbar('Peer', handles.axes4);
        end
        
        xcfoo = max(foo, [], 2);
        xccow = max(cow, [], 2);
        
        r = (mean(xcfoo, 3) ./ mean(xccow, 3))';
        spikes = r > 2;

  
    case 'rms'
        roirms1 = sqrt(mean(response(roii, :).^2, 1))

        roirms = rms(response(roii, :), 1)
        baserms = rms(response(baselinei, :), 1)
        r = (roirms ./ baserms);
        spikes =  r > 2;
        
    case 'std'
        roirms = std(response(roii, :), 0, 1)
        baserms = std(response(baselinei, :), 0, 1)
        r = (roirms ./ baserms)
        spikes =  r > 200
        
        
    case 'range'
        roipkpk = max(response(roii,:)) - min(response(roii,:));
        basepkpk = max(response(baselinei,:)) - min(response(baselinei,:));
        r = (roipkpk ./ basepkpk);
        spikes = r > 3;
        
        
    case 'threshold'
        roipkpk = (max(response(roii,:)) - min(response(roii,:)));
        basepkpk = (max(response(baselinei,:)) - min(response(baselinei,:)));
        r = (roipkpk - basepkpk);
        spikes = r > 0.00005;
        
        
    case 'convolve'
        c = load('stim_20151005_154801.070.mat');
        x = squeeze(mean(c.data.tdt.response(:,:,9)));
        x = filtfilt(B, A, x);
        y = find(c.data.tdt.times_aligned>0.0005 & c.data.tdt.times_aligned<0.002);
        b = x(y(end):-1:y(1));

        foo = zeros(length(validi), nchannels);
        for i = 1:nchannels
            foo(:,i) = conv(response(validi,i)', b, 'same');
        end
        
        [val pos] = max(foo, [], 1);
        r = val;
        spikes = abs(val) > 1.5e-7;

    case 'spectrogram'
        
        FFT_SIZE = 32;
        FFT_TIME_SHIFT = 0.0008;                        % seconds
        NOVERLAP = FFT_SIZE - (floor(d.fs * FFT_TIME_SHIFT));
        window = hamming(FFT_SIZE);

        for i = 1:nchannels
            [speck ffreqs fftimes] = spectrogram(response(:,i), window, NOVERLAP, [], d.fs);
            spectrograms(:,:,i) = speck;
        end
        fftimes = fftimes + times(1)
        spectrograms = abs(spectrograms);
        [nfreqs, nfftimes] = size(speck);
        speck = speck + eps;
        
        response_freq_range = [500 2000];
        response_freq_indices = find(ffreqs >= response_freq_range(1) & ffreqs <= response_freq_range(2));
        response_time_indices_roi = find(fftimes >= roi(1) & fftimes <= roi(2));
        response_time_indices_baseline = find(fftimes >= baseline(1) & fftimes <= baseline(2));
        response_spec_roi = squeeze(sum(sum(spectrograms(response_freq_indices, response_time_indices_roi, :), 1), 2)) ...
            / (length(response_freq_indices) * length(response_time_indices_roi));
        response_spec_baseline = squeeze(sum(sum(spectrograms(response_freq_indices, response_time_indices_baseline, :), 1), 2)) ...
            / (length(response_freq_indices) * length(response_time_indices_baseline));

        if exist('handles') & true
            imagesc([fftimes(1) fftimes(end)]*1000, ...
                [ffreqs(1) ffreqs(end)]/1000, ...
                squeeze(log(spectrograms(:,:,1))), ...
                'Parent', handles.axes2);
            %imagesc(squeeze(log(spectrograms(:,:,4))), ...
            %    'Parent', handles.axes2);
            axis(handles.axes2, 'xy');
            xlabel(handles.axes2, 'Time (ms)');
            ylabel(handles.axes2, 'Frequency (kHz)');
            colorbar('Peer', handles.axes2);
        end
        
        
        r = squeeze(response_spec_roi ./ response_spec_baseline)';
        spikes = r > 3;

    otherwise
        r = zeros(1, nchannels);
        spikes = zeros(1, nchannels);
end
