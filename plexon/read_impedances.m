function [ impedances ] = read_impedances(dirname, area)

dd = dir(strcat(dirname, filesep, '*', area, '.csv'));
if length(dd) == 0
    impedances = [];
    return;
end
if length(dd) > 1
    disp(strcat('*** Warning: more than one impedances file for bird ''', dirname, ''', area ''', area, '''.'));
end

[~, dirn, ~] = fileparts(dirname);


fid = fopen(strcat(dirname, filesep, dd(1).name));
headers = textscan(fid, '%s', 8, 'Delimiter', ',');
data = textscan(fid, '%s%s%s%d%f%f%f%f', 'Delimiter', ',');
fclose(fid);

impedances = data{5}(9:24);
