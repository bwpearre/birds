clear;
filebase = 'net_detector_0.46';

% This seems inefficient, and it is, but I'm trying to duplicate the steps
% from the LabView realtime code as precisely as possible.  Trust me.

load(strcat(filebase, '.mat'));
aud = audioread(strcat(filebase, '.wav'));

show_size = 10000;

sample_buffer = aud(1:FFT_SIZE, 1);
nfreqs = length(freq_range_ds);
fftb = zeros(nfreqs * time_window_steps, 1);
triggerb = zeros(length(bias1), show_size);
triggerb_official = zeros(length(bias1), show_size);
triggerb_original = zeros(length(bias1), show_size);

samples_steps = round(FFT_TIME_SHIFT * samplerate);

fullbuf = zeros(FFT_SIZE/2, show_size);

window = hamming(FFT_SIZE);

counter = 0;
pos = 0;

%while(pos < size(aud, 1) - samples_steps)

if 0
        subplot(3,1,1);
        for i = 1:1
                f = reshape(nnsetX(:,i), nfreqs, time_window_steps);
                imagesc(f);
                axis xy;
                colorbar;
                pause(0.5);
        end
end

while counter < show_size
        
        
        counter = counter + 1;
        
        %% Pull in some data...
        sample_buffer = [sample_buffer(samples_steps+1:end) ; aud(pos+1:pos+samples_steps, 1)];
        pos = pos + samples_steps;
        
        
        %% Rotate the buffers
        fftb = [fftb(nfreqs+1:end); fftb(1:nfreqs)];
        triggerb = [triggerb(:, 2:end) triggerb(:, 1)];
        triggerb_official = [triggerb_official(:, 2:end) triggerb_official(:, 1)];
        triggerb_original = [triggerb_original(:, 2:end) triggerb_original(:, 1)];
        fullbuf = [fullbuf(:, 2:end) fullbuf(:, 1)];
        
        %% Do FFT
        freqs = abs(fft(sample_buffer .* window));
        fullbuf(:, end) = freqs(1:FFT_SIZE/2);
        fftb(end-nfreqs+1:end) = freqs(freq_range_ds);
        fftbn = normc(fftb);
        fftbn_img = reshape(fftbn, nfreqs, time_window_steps);

        %subplot(3,1,1);
        %imagesc(fullbuf);
        %axis xy;
        %colorbar;
        if 0
                subplot(3,2,2);
                imagesc(fftbn_img);
                title('fft buffer');
                axis xy;
                colorbar;
        end
        
        if counter > time_window_steps
                
                origimg = nnsetX(:, counter - time_window_steps);
                f = reshape(origimg, nfreqs, time_window_steps);
                subplot(3,2,1);
                imagesc(f);
                colorbar;
                axis xy;
                title('training input');
                net_out_original = sim(net, origimg)

                if 0
                        subplot(3,2,5);
                        imagesc(fftbn_img - f);
                        axis xy;
                        colorbar;
                        title('fft - train');
                        subplot(3, 2, 6);
                        imagesc(f ./ fftbn_img);
                        axis xy;
                        title('train / fftb');
                        colorbar;
                end
                
                trigger_out_original = net_out_original > trigger_thresholds';
                triggerb_original(:, end) = trigger_out_original + [2 0]';


                % Run the neural network manually:
        
                net_out_official = sim(net, fftbn)
                fftbmmm = mapminmax('apply', fftbn, net.inputs{1}.processSettings{1});
                fftbmmmm = (fftbn - net.inputs{1}.processSettings{1}.xoffset) ...
                        .* net.inputs{1}.processSettings{1}.gain ...
                        - 1;
                if mean(fftbmmm == fftbmmmm) ~= 1
                        disp('WARNING: input map min max ~= map min max manual');
                end
                net_mid = tansig(layer0 * fftbmmm + bias0);
                net_out = layer1 * net_mid + bias1;
                net_out_manual = (net_out + 1) ./ net.outputs{2}.processSettings{1}.gain ...
                        + net.outputs{2}.processSettings{1}.xoffset;
                net_out_orig = net_out;
                net_out = mapminmax('reverse', net_out, net.outputs{2}.processSettings{1})
                
                if mean(net_out == net_out_manual) ~= 1
                        fprintf('WARNING: output map min max ~= map min max manual: %g', mean(net_out - net_out_manual));
                end
                if mean(net_out == net_out_orig) ~= 1
                        fprintf('WARNING: output map min max ~= map min max orig: %g', mean(net_out - net_out_orig));
                end

        
                trigger_out = net_out > trigger_thresholds';
                trigger_out_official = net_out_official > trigger_thresholds';
                triggerb(:, end) = trigger_out + [2 0]';
                triggerb_official(:, end) = trigger_out_official + [2 0]';
        end
        
        subplot(9,1,6);
        plot(triggerb');
        axis tight;
        ylim([-1 4]);
        colorbar;
        title('hand-executed');
        subplot(9,1,5);
        plot(triggerb_official');
        axis tight;
        ylim([-1 4]);
        colorbar;
        title('official');
        subplot(9,1,4);
        plot(triggerb_original');
        axis tight;
        ylim([-1 4]);
        colorbar;
        title('original');
        drawnow;
        
end
