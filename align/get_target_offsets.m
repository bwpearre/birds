function [ target_offsets ] = get_target_offsets(MIC_DATA, times_of_interest, fs, timestep_length_ds, canonical_songs);

% How big a window is 20ms?
window_halfsize = floor(0.03 * fs);

nsongs = size(MIC_DATA, 2);

samples_of_interest = floor(times_of_interest * timestep_length_ds * fs);

target_offsets = zeros(length(times_of_interest), nsongs);

for i = 1:length(samples_of_interest)
        template = MIC_DATA(samples_of_interest(i) - window_halfsize : samples_of_interest(i) + window_halfsize, ...
                            canonical_songs(i));
        for j = 1:nsongs
                cor = xcorr(template, ...
                            MIC_DATA(samples_of_interest(i) - window_halfsize : samples_of_interest(i) + window_halfsize, j));
                [val pos] = max(cor);
                target_offsets(i,j) = pos - 2 * window_halfsize - 1;
        end
end

% Convert from sample steps to timestep_length_ds units
target_offsets = round( ( target_offsets / fs ) / timestep_length_ds );
