function [ intanstruct ] = read_lots_of_intan_files(dirname)


dd = dir(strcat(dirname, filesep, '*x*.rhd'));
if length(dd) == 0
    intanstruct = {};
    return;
end


alldata = [];
alltimes = [];
for i = 1:length(dd)
    intanstruct = read_Intan_RHD2000_file_bwp(strcat(dirname, filesep, dd(i).name));
    alldata = [alldata intanstruct.amplifier_data];
    alltimes = [alltimes intanstruct.t_amplifier];
end


intanstruct.amplifier_data = alldata;
intanstruct.t_amplifier = alltimes;
