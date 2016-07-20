clear;


%detector_file = '~/v/birds/detector_lny29_0.08_0.15_0.22_0.27_0.31_0.38_0.505_0.655s_frame3ms_16hid_1000train-normed.mat';
%detector_file = '~/v/birds/detector_lny29_0.08_0.15_0.22_0.27_0.31_0.38_0.505_0.655s_frame4ms_16hid_1000train.mat';
detector_file = '~/v/birds/detector_lny29_0.08_0.15_0.22_0.27_0.31_0.38_0.505_0.655s_frame3ms_16hid_1000train.mat';
%detector_file = '~/v/birds/align/entropy/detector_lny64_0.06_0.15_0.25_0.31_0.4s_frame1ms_10hid_1000train.mat';
datadir = '/Volumes/Data/song/';
moredirs = '/chop_data/wav/';
detectsyllables = '~/v/syllable-detector-swift/detectsyllables';

%audio_files = '/Volumes/Data/song/lny29/2015-07-29/chop_data/wav/*.wav';
%audio_files = '/Volumes/Data/song/lny29/2015-07-29/chop_data/wav/channel_07.2015.07.29.16.04-f07.9_chunk_2.wav';

net = load(detector_file);
ntimes_of_interest = length(net.times_of_interest);

datadirs = dir(strcat(datadir, filesep, net.BIRD, filesep, '201*'));

convert_to_text('network_foo.mat', detector_file);
%s = system(sprintf('%s --net network_foo.mat --audio %s --debounce 0.02 > out.csv', ...
%    detectsyllables, ...
%    audio_files));

data = zeros(1, 1 + ntimes_of_interest);
data_lines = 0;
data_capacity = 1;

for i = 1:length(datadirs)
    dirname = datadirs(i).name;
    [~, dirn, ~] = fileparts(dirname);
    e1 = strsplit(dirn, '-');
    day = datenum([ str2double(e1{1}) str2double(e1{2}) str2double(e1{3}) 0 0 0]);
    disp(sprintf('Working on day %s...', datestr(day)));
    
    datafiledir = strcat(datadir, filesep, net.BIRD, filesep, datadirs(i).name, moredirs, filesep);
    datafiles = dir(strcat(datafiledir, '*.wav'));
    for j = 1:length(datafiles)
        filename = strcat(datafiledir, datafiles(j).name);
        
        fname = datafiles(j).name;
        [~, dirn, ~] = fileparts(fname);
        e1 = strsplit(dirn, '.');
        e2 = strsplit(e1{6}, '-');
        starttime = datenum([ str2double(e1{2}) str2double(e1{3}) str2double(e1{4}) str2double(e1{5}) str2double(e2{1}) 0]);
        %disp(sprintf('File %s', datestr(starttime)));
        
        d = run_network_on_wav(net, filename);
        dl = size(d, 1);

        d = [repmat(starttime, dl, 1) d];
        
        
        % Preallocate data:
        if data_lines + dl > data_capacity
            data_capacity = data_capacity * 2 + dl;
            data(data_capacity, 1) = 0;
            disp(sprintf('Increasing space for data: capacity now %d', data_capacity));
        end
        data(data_lines+1:data_lines+dl, :) = d;
        data_lines = data_lines + dl;
    end
end
% Chop off unused preallocated memory:
data = data(1:data_lines, :);

datas = data;
% Thresholding and syllable labeling:
foo = datas(:, 2:end);
% Remove elements without positive values.  This lets us tweak the thresholds.
fooo = bsxfun(@gt, foo, 0);
datas = datas(find(sum(fooo, 2)), :);
[~, active_syllable] = max(datas(:, 2:end), [], 2);


%for i = 1:size(datas,1)
%    disp(sprintf('%s %g %d', datestr(datas(i,1)), datas(i, 4), datas(i,5)));
%end

plot_transition_probabilities(datas, active_syllable, ntimes_of_interest);
