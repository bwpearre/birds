function [ intanstruct ] = read_lots_of_intan_files(dirname)


dd = dir(strcat(dirname, filesep, '*x*.rhd'));
if length(dd) == 0
    intanstruct = {};
    return;
end

[~, dirn, ~] = fileparts(dirname);
e1 = strsplit(dirn, '-');


alldata = [];
alltimes = [];
for i = 1:length(dd)
    intanstruct = read_Intan_RHD2000_file_bwp(strcat(dirname, filesep, dd(i).name));
    alldata = [alldata intanstruct.amplifier_data];
    alltimes = [alltimes intanstruct.t_amplifier];
end

% Centre it
for i = 1:size(alldata, 1)
    alldata(i, :) = (alldata(i, :) - mean(alldata(i, :)));
end

intanstruct.amplifier_data = alldata;
intanstruct.t_amplifier = alltimes;
intanstruct.experiment_date = datenum([ str2double(e1{2}) str2double(e1{3}) str2double(e1{4}) 0 0 0]);
