clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

datadir = '/Volumes/Data/plexon/';
bird = 'lw94rhp'                    % Which bird to look at?

channels = [1 8];               % Speed up reading by only looking for spikes here
%channels_show = [1 2 8 10 12 16];
threshold = 5;                      % Spike threshold in std.dev.
window = [-0.001 0.002];            % Time window to plot around spikes
n_min = 20;
days = [325 353 381];               % Plot just a few days
shadederror = true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

implant_date = get_implant_date(bird);


cd(datadir);
d = dir(sprintf('%s*', datadir, bird));
has_x_recordings = zeros(1,length(d));

recording_sessions = [];
recording_channels = zeros(1, 16);

if ~exist('channels', 'var')
    channels = 1:16;
end

s = 0;
for i = 1:length(d)
    experiment_date = get_experiment_date(d(i).name);
    experiment_day = experiment_date - implant_date;
    
    if ~any(experiment_day == days)
        continue;
    end
    
    s = s + 1;
    
    sessions{s}.bird = bird;
    sessions{s}.experiment_date = experiment_date;    
    sessions{s}.experiment_day = experiment_day;
    disp(sprintf('%s: +%d days...', d(i).name, sessions{s}.experiment_day));

    sessions{s}.data = read_lots_of_intan_files(d(i).name);

    if ~isempty(sessions{s}.data) & isfield(sessions{s}.data, 'amplifier_data')
        [ sessions{s}.recording_channels, sessions{s}.peaklocs ] = findspikes(sessions{s}.data, channels, threshold);
        recording_sessions(s) = 1;
        recording_channels_ind = zeros(1, 16);
        recording_channels_ind(sessions{s}.recording_channels) = 1;
        recording_channels = or(recording_channels, recording_channels_ind);
    end

    
    session_days_imp_x(s) = sessions{s}.experiment_day;
    if ~isempty(sessions{s}.data.impedances.x)
        session_impedances_x(s,:) = sessions{s}.data.impedances.x;
    end
end


if ~exist('channels_show', 'var')
    channels_show = channels;
    
    % Channel 13 is usually bad...?
    %channels_show = channels_show(find(channels_show ~= 13));
end
%plotchannels = intersect(channels_show, find(recording_channels));
plotchannels = channels_show;
colours = distinguishable_colors(length(plotchannels));


if ~isempty(recording_sessions)
    plotspikes(sessions, recording_sessions, plotchannels, n_min, window, colours, shadederror);
end


%%% Plot impedances over time
figure(101);
impedance_days = find(sum(session_impedances_x, 2));

h = semilogy(session_days_imp_x(impedance_days), session_impedances_x(impedance_days,plotchannels), '-o');

for i = 1:length(h)
    h(i).Color = colours(i,:);
end

legendnames = {};
for i = plotchannels
    legendnames{end+1} = sprintf('%d', i);
end
legend(legendnames, 'Location', 'NorthWest');
xlabel('Days post-implant');
%set(gca, 'YLim', [3e5, 2e7]);

set(gca, 'XTick', session_days_imp_x(impedance_days));
xticklabel_rotate([], 60);
ylabel('Impedance at 1 kHz (\Omega)');
title('Impedances');
