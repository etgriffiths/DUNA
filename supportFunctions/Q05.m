% Quality Check 05: check whether more than 0.1% of the data is clipped
% Exports percentage of clipped data - March 2024 - ETG


function [flag, perCl] = Q05(fileLoc,filedata,cliplimit)
    ClippedSamples = find(abs(filedata) == 1);
    ProcClippedSamples = length(ClippedSamples) / length(filedata) * 100;
        if ProcClippedSamples > cliplimit
%                 movefile([filepath filename], [filepath 'NoRealData05_' filename]);
                flag = 1;
            else
                flag = 0;
        end

        perCl = ProcClippedSamples;
end

