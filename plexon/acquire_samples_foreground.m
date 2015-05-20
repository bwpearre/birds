function [data] = acquire_samples_foreground(channels, fs, samplefor)



%fs=100e3; % sampling frequency (in Hz)
%samplefor=0.1; % sample for this long
in_device='Dev1'; % location of input device
in_device_type='ni'; % input device type
channel_labels={'Current', 'Voltage'}; % labels for INCHANNELS

daq.reset;
devices = daq.getDevices;

session=daq.createSession(in_device_type);
session.Rate=fs;
session.IsContinuous=0;
session.DurationInSeconds = 0.1;


for i=1:length(channels)
    addAnalogInputChannel(session, in_device, sprintf('ai%d', i-1), 'voltage');

	param_names=fieldnames(session.Channels(i));

	session.Channels(i).Name=channel_labels{i};
	session.Channels(i).Coupling='DC';

	if any(strcmp(param_names,'TerminalConfig'))
		session.Channels(i).TerminalConfig='SingleEnded';
	elseif any(strcmp(param_names,'InputType'))
		session.Channels(i).InputType='SingleEnded';
	else
		error('Could not set NiDaq input type');
	end

end

[data, time] = session.startForeground;


