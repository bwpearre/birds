function [ implant_date ] = get_implant_date(bird);

if strcmp(bird, 'lw85ry')
    implant_date = datenum([ 2015 04 27 0 0 0 ]);
elseif strcmp(bird, 'lw95rhp')
    implant_date = datenum([ 2015 05 04 0 0 0 ]);
elseif strcmp(bird, 'lw94rhp')
    implant_date = datenum([ 2015 04 28 0 0 0 ]);
else
    implant_date = datenum([ 0 0 0 0 0 0 ]);
end
