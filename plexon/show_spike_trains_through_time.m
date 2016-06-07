clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bird = 'lw94rhp'                    % Which bird to look at?

%channels = [1 8 16];               % Speed up reading by only looking for spikes here
%channels_show = [1 2 8 10 12 16];
threshold = 5;                      % Spike threshold in std.dev.
window = [-0.001 0.002];            % Time window to plot around spikes
n_min = 20;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

implant_date = get_implant_date(bird);

d = dir(sprintf('%s*', bird));
has_x_recordings = zeros(1,length(d));

recording_sessions = [];
recording_channels = zeros(1, 16);

if ~exist('channels', 'var')
    channels = 1:16;
end

for i = 1:length(d)
    sessions{i}.bird = bird;
    sessions{i}.experiment_date = get_experiment_date(d(i).name);    
    sessions{i}.experiment_day = sessions{i}.experiment_date - implant_date;
    disp(sprintf('%s: +%d days...', d(i).name, sessions{i}.experiment_day));

    sessions{i}.data = read_lots_of_intan_files(d(i).name);

    if ~isempty(sessions{i}.data) & isfield(sessions{i}.data, 'amplifier_data')
        [ sessions{i}.recording_channels, sessions{i}.peaklocs ] = findspikes(sessions{i}.data, channels, threshold);
        recording_sessions(i) = 1;
        recording_channels_ind = zeros(1, 16);
        recording_channels_ind(sessions{i}.recording_channels) = 1;
        recording_channels = or(recording_channels, recording_channels_ind);
    end

    
    session_days_imp_x(i) = sessions{i}.experiment_day;
    if ~isempty(sessions{i}.data.impedances.x)
        session_impedances_x(i,:) = sessions{i}.data.impedances.x;
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
    plotspikes(sessions, recording_sessions, plotchannels, n_min, window, colours);
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
