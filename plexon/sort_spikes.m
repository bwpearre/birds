clear;

% Create files that can be read using "Import" from the Plexon offline spike sorter.  Which, by the
% way, is a bit clunky.

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

implant_date = get_implant_date(bird);

d = dir(sprintf('%s*', bird));
has_x_recordings = zeros(1, length(d));
has_x_impedances = zeros(1, length(d));

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

for s = find(goodsessions)
    d = fdesign.bandpass('Fst1,Fp1,Fp2,Fst2,Ast1,Ap,Ast2',200,350,8800,9300,60,1,60,...
        sessions{6}.data.frequency_parameters.amplifier_sample_rate);
    Hd = design(d,'equiripple');
    
    for c = find(goodchannels)
        m = mean(sessions{s}.data.amplifier_data);
        fid = fopen(sprintf('channel_%d_day_%s.bin', c, sessions{s}.experiment_day), 'w');
        %[amp,aux_input,params,notes,supply_voltage,adc,dig_in,dig_out,temp_sensor,status]=read_intan_data_cli_rhd2000(a(fnum).name);
        Data=filtfilt(Hd.Numerator, 1, sessions{s}.data.amplifier_data(c, :) - m);
        fwrite(fid, Data*100, 'int16');
        fclose(fid);
    end
end
