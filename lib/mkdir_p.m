function [] = mkdir_p(d);

% While 'd' does not exist, create the upstream one

[updir, enddir, ext] = fileparts(d);

if ~exist(updir, 'dir')
    mkdir_p(updir);
end

if ~exist(d, 'dir')
    mkdir(updir, [enddir ext]);
end
