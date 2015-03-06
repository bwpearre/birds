function [ target_offsets sample_offsets ] = get_target_offsets_jeff(AUDIO, time_of_interest, fs, timestep_length_ds, canonical_song);

% Jeff Markowitz's code taken from https://github.com/jmarkow/syllable-detection/blob/master/sylldet_fir_learn.m

window_halfsize = floor(0.02*fs);

threshold = 0.1; % xcorr threshold for hits
onset_delay = 0;
jitter = 5;
marker_jitter = round(0.02 * fs);

% The index here represents which target sound we're working on
sample_of_interest = floor(time_of_interest * timestep_length_ds * fs);
TARGET_SOUND = AUDIO(sample_of_interest - window_halfsize : sample_of_interest + window_halfsize, ...
        canonical_song);
marker = sample_of_interest+window_halfsize;

[nsamples, ntrials] = size(AUDIO);
template = flipud(zscore(TARGET_SOUND(:)));
norm_factor = template'*template;
template = template/norm_factor;
len = length(template);
TARGET_MATRIX = zeros(size(AUDIO));
todel = [];
score = double(filter(template,1,zscore(AUDIO)));
sample_offsets = zeros(1, ntrials);

for i = 1:ntrials
        [vals,locs] = findpeaks(score(:,i),'minpeakheight',threshold,'minpeakdistance',round(.1*fs));
        flag1 = locs<marker-marker_jitter;
        flag2 = locs>marker+marker_jitter;
        to_del = flag1|flag2;
        vals(to_del) = [];
        locs(to_del) = [];
        if isempty(vals)
                todel = [todel i];
                vals = 1;
                locs = marker;
        end
        [sortvals, sortidx] = sort(vals(:),1,'descend');
        stoppoint = locs(sortidx(1));
        %hitpoint = round(stoppoint-round(onset_delay*len));
        sample_offsets(i) = stoppoint - window_halfsize;
        %hitpoints=hitpoint-jitter:hitpoint+jitter;
        %hitpoints(hitpoints<1|hitpoints>nsamples)=[];
        %TARGET_MATRIX(hitpoints,i)=1;
end

sample_offsets = sample_offsets - sample_of_interest;
target_offsets = round( (  ( sample_offsets ) / fs ) / timestep_length_ds );
%target_offsets = round( (  ( sample_offsets - sample_of_interest  ) / fs ) / timestep_length_ds );
%a(0)