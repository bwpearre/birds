function plotwhich(source, event)
global showP;

whichone = str2double(source.Tag);
v = source.Value;
if v
    showP = sort(union(showP, whichone));
else
    showP = showP(find(showP ~= whichone));
end

plot_wiggles();
