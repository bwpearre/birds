function [ day ] = get_experiment_date(dirname);

[~, dirn, ~] = fileparts(dirname);
e1 = strsplit(dirn, '-');

day = datenum([ str2double(e1{2}) str2double(e1{3}) str2double(e1{4}) 0 0 0]);
