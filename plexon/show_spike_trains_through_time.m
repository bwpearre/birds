clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bird = 'lw94rhp'

channels = 1:16;
%channels = [1 8 10 12 16]
threshold = 5;
window = [-0.001 0.002];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%[a,experiment,c] = fileparts(pwd);
%e1 = strsplit(experiment, '-');

d = dir(sprintf('%s*', bird));
has_x_recordings = zeros(1,length(d));

for i = 1:length(d)
    session{i}.data = read_lots_of_intan_files(d(i).name);
    if isempty(session{i}.data)
        continue;
    end
    [ session{i}.goodchannels, session{i}.peaklocs ] = findspikes(session{i}.data, channels, threshold);
end
