clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bird = 'lw94rhp'

channels = 1:16;
%channels = [1 10 14 15 16];
channels = [1 8 16]
threshold = 5;
window = [-0.001 0.002];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(bird, 'lw85ry')
    implant_date = datenum([ 2015 04 27 0 0 0 ]);
elseif strcmp(bird, 'lw95rhp')
    implant_date = datenum([ 2015 05 04 0 0 0 ]);
elseif strcmp(bird, 'lw94rhp')
    implant_date = datenum([ 2015 04 28 0 0 0 ]);
else
    implant_date = datenum([ 0 0 0 0 0 0 ]);
end


d = dir(sprintf('%s*', bird));
has_x_recordings = zeros(1,length(d));

goodsessions = [];
goodchannels = zeros(1, 16);

for i = 1:length(d)
    sessions{i}.data = read_lots_of_intan_files(d(i).name);

    if isempty(sessions{i}.data)
        continue;
    end
    sessions{i}.bird = bird;
    sessions{i}.experiment_day = sprintf('%d', ...
        sessions{i}.data.experiment_date-implant_date);
    [ sessions{i}.goodchannels, sessions{i}.peaklocs ] ...
        = findspikes(sessions{i}.data, channels, threshold);
    goodsessions(i) = 1;
    goodchannels_ind = zeros(1, 16);
    goodchannels_ind(sessions{i}.goodchannels) = 1;
    goodchannels = or(goodchannels, goodchannels_ind);
    
end

%plotchannels = find(goodchannels);
%plotchannels = channels;

plotspikes(sessions, goodsessions, find(goodchannels), window);
