function plotwhich(source, event)
global showP;

whichone = str2double(source.String);
v = source.Value;
if v
    showP = sort(union(showP, whichone));
else
    showP = showP(find(showP ~= whichone));
end

plot_wiggles();
