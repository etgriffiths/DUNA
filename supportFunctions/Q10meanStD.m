% Quality Check 10: Check if following files are either twice as loud or
% quiet as the predecessing files



function [flag] = Q10(filestdrms,limit, fileAv)
    for ii = 1:length(filestdrms)
        if ii<=fileAv
            meanStDrms=mean(filestdrms(ii+1:ii+fileAv));
            if filestdrms(ii) > limit*meanStDrms || filestdrms(ii) < meanStDrms/limit
                flag(ii) = 1;
            else
                flag(ii) = 0;
            end
        else
            meanStDrms=mean(filestdrms(ii-fileAv:ii-1));
            if filestdrms(ii) > limit*meanStDrms || filestdrms(ii) < meanStDrms/limit
                flag(ii) = 1;
            else
                flag(ii) = 0;
            end
    end
end