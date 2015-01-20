% Record from audio device...

SampleRate = 44100;
FrameLatency = 0.01;
nseconds = 4;

mic = dsp.AudioRecorder('SampleRate', SampleRate, ...
                        'NumChannels', 2, ...
                        'BufferSizeSource', 'Property', ...
                        'BufferSize', 512, ...
                        'QueueDuration', 0, ...
                        'OutputNumOverrunSamples', true, ...
                        'SamplesPerFrame', round(SampleRate*FrameLatency));
%spectrum = dsp.SpectrumAnalyzer('SampleRate', SampleRate, ...
%                                'SpectrumType', 'Spectrogram', ...
%                                'PlotAsTwoSidedSpectrum', false, ...
%                                'OverlapPercent', 80, ...
%                                'TimeSpanSource', 'Property', ...
%                                'TimeSpan', 2);
%spectrum.hide;
a = 1;
totalframes = nseconds / FrameLatency;


spectrum = dsp.SpectrumEstimator('SampleRate', SampleRate, ...
                                 'SpectrumType', 'Power', ...
                                 'FrequencyRange', 'onesided', ...
                                 'FFTLengthSource', 'Property', ...
                                 'FFTLength', 512);

aud = step(mic);
audiodata = zeros([totalframes 1] .* size(aud));
audiodata(size(aud, 1)*(a-1)+1 : size(aud, 1)*a, :) = aud;

v = step(spectrum, aud);
spectraldata = zeros([nseconds / FrameLatency   size(v)]);
          
spectraldata(a,:,:) = v;

tic;


lasttime = toc;

while toc < nseconds
        a = a + 1;
        disp(sprintf('Step %d took %g ms', a, 1000*(toc - lasttime)));
        lasttime = toc;
        aud = step(mic);
        audiodata(size(aud, 1)*(a-1)+1 : size(aud, 1)*a, :) = aud;
        spectraldata(a, :, :) = step(spectrum, aud);
end

speck = specgram(audiodata(60000:80000,1), 512, [], [], 500) + eps;


% Record song audio on channel 1.  Record neural net syllable detector
% output on channel 2.  Graph the spectrum of channel 1 through time.
% Could do same for channel 2, or put a blip at point-of-detection.

release(mic);
release(spectrum);

figure(1);
subplot(3,1,1);
imagesc(squeeze(log(abs(speck))));
axis xy;
subplot(3,1,2);
imagesc(squeeze(log(abs(speck))));
axis xy;
subplot(3,1,3);
plot(audiodata);


