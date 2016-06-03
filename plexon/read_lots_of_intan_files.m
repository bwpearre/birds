function [ intanstruct ] = read_lots_of_intan_files(dirname)

impedances.x = read_impedances(dirname, 'x');
impedances.hvc = read_impedances(dirname, 'hvc');

dd = dir(strcat(dirname, filesep, '*x*.rhd'));
if length(dd) == 0
    intanstruct.impedances = impedances;
    return;
end

[~, dirn, ~] = fileparts(dirname);
e1 = strsplit(dirn, '-');


alldata = [];
alltimes = [];
for i = 1:length(dd)
    intanstruct = read_Intan_RHD2000_file_bwp(strcat(dirname, filesep, dd(i).name));

    % Centre it
    foo = bsxfun(@minus, intanstruct.amplifier_data, ...
        mean(intanstruct.amplifier_data, ...
        2));

    % Toss files with high noise levels; hopefully this is correlated with
    % various kinds of garbage in the files...
    if max(abs(foo)) <= 500
        alldata = [alldata intanstruct.amplifier_data];
        alltimes = [alltimes intanstruct.t_amplifier];
    end
end

% Better centering if we look at the whole thing at once, so repeat!
alldata = bsxfun(@minus, alldata, mean(alldata, 2));

intanstruct.impedances = impedances;
intanstruct.amplifier_data = alldata;
intanstruct.t_amplifier = alltimes;
intanstruct.t_total_s = length(alltimes) / intanstruct.frequency_parameters.amplifier_sample_rate;
intanstruct.experiment_date = datenum([ str2double(e1{2}) str2double(e1{3}) str2double(e1{4}) 0 0 0]);
