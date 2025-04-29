function [newDTall] = clockDrift(syncGPSstart, syncLOGstart, syncGPSslut, syncLOGslut, DT_all, n)
%%Interpolate datetimes to match the GPS timestamps and account for clock
%drift in the recorders. Returns a vector of adjusted datetimes. 

% Updated in March 2024 to work directly with DUNA.
% Emily T Griffiths, emilytgriffiths@ecos.au.dk

%% Definition of variables:

    %syncGPSstart -  Should be present for all deployments. This was the
    %time that the unit was synced with a GPS before deployment. This is
    %the actual GPS time, as sometimes there can be a difference between
    %the GPS time and the logger sync time, by a second or so, since Ocean
    %Instruments takes it start time from the computer and not by manual
    %input.
    
    %syncLOGstart - Should be present for all deployments. This was the
    %time that the unit was synced with a GPS before deployment. This is
    %the cooresponding Logger time.
    % 
    %syncGPSslut - Time on the unit when the data was offloaded according
    %to the GPS time.
    
    %syncLOGslot - Time according to the logger when data was offloaded.
   
    
    %DT_all - Datetime series you wish to adjust for Clock Drift, generally
    %derived from the timestamps on the files.
    
    %n - length of vectors you would like to interpolate over. Default is
    %5000.
    
    if isnat(syncGPSstart)
        error('Not enough information to adjust for Clock Drift. \nFunction requires time unit was synced with GPS time before deployment. \nInclude time syncGPSstart variable.')
    end

    if isnat(syncLOGstart)
        error('Not enough information to adjust for Clock Drift. \nFunction requires time unit was synced with GPS time before deployment. \nInclude time syncLOGstart variable.')
    end

    if isnat(syncGPSslut)
        error('Not enough information to adjust for Clock Drift. \nFunction requires either the GPS time the unit stopped, or the difference in seconds between the time the unit and the GPS time. \nInclude syncGPSslut variable.')
    end
    
    if isnat(syncLOGslut)
        error('Not enough information to adjust for Clock Drift. \nFunction requires internal time of deployed unit to calculate the difference in Clock Drift. \nInclude the syncLOGslut variable.')
    end
    

    
    if  nargin < 6 || isempty(n)
        n=5000;
    end
    

    %Create linear vectors of fixed length to interpolate on.
    timeGPSdiff=datenum(linspace(syncGPSstart,syncGPSslut,n));
    timeClockdiff=datenum(linspace(syncLOGstart,syncGPSslut,n));
    %Convert date times to datenum
    DTall_num=datenum(DT_all);
    %Interpolate!
    newDTall=datetime(interp1(timeClockdiff,timeGPSdiff,DTall_num),'ConvertFrom','datenum');
end
