% For each recording this script will extract timestamps and TOL SPLs per 1 
% sec, 20 sec and 5 mins in 31 different filter bands, including 63Hz, 125Hz
% and 2kHz as well as allow quantification over the entire frequency band 10
% -10000Hz. 
%
%  This is Step 1.
%
% Current Version by Emily T. Griffiths, 2020-2025, modified as a function
% to work within DUNA.
%
% Version updated in 2025 to formally integrate BSH quality functions, Q1, Q5, and Q13 so
% that they are not preformed as an extra step, but rather are collected to
% examine if needed.  Only Q1 triggers an error, as that indicates that the
% file is not readable and should not be processed. A warning is given so
% the user can double check if need be, and the Q error is logged.
%
% Version (c) June 2025b
%
% Originally Developed by Jakob Tougaard and Pernille Meyer Sørensen, 2018. 
% Modified and improved by Line Hermannsen and Mia L. K. Nielsen, 2018-2020.

function [outputLocation, results, resultname, QualityResults] = decidecadeProcessing(depData)
    
    
    %File name
    resultname=[depData.Deployment_ID '_to_' datestr(depData.DTslut, 'yyyymmdd') '_' depData.loggerID '.mat' ]; %save results in mat file with this name
    
    filters = computefilters(char(strcat(depData.dataPath, '\', depData.usableFiles.name(1))));                    % Construct the filters (42 of which 11-42 are functional) 
    w=filters.w;  

    filesdata=depData.usableFiles;

    %% initialize variables - Numbers are leftover from BSH original code.
    Q_01(1:height(filesdata)) = NaN; % cannot read file
    Q_05(1:2,1:height(filesdata)) = NaN; % too much clipping
    Q_13(1:height(filesdata)) = NaN; % check if data is stationary
    sr(1:height(filesdata))=NaN;
    duration(1:height(filesdata))=NaN;
    ts(1:height(filesdata))=NaN;
    stdrms(1:height(filesdata))=NaN;
    meanv(1:height(filesdata))=NaN;
    meanvDC(1:height(filesdata))=NaN;

    
    
    %%preallocate your final file.
    datafiles(height(filesdata)).bands_1s=deal([]);            % Saves bands_1s
    datafiles(height(filesdata)).bands_20s=deal([]);          % Saves bands_20s
    datafiles(height(filesdata)).bands_5min=deal([]);        % Saves bands_5min
    datafiles(height(filesdata)).filename=deal([]);  % Saves filename
    datafiles(height(filesdata)).datetime=deal([]);% Saves time stamp from filename
    datafiles(height(filesdata)).timestamps_1s=deal([]);  % Saves time stamps for each 1 sec segment
    datafiles(height(filesdata)).timestamps_20s=deal([]);% Saves time stamps for each 20 sec segment
    datafiles(height(filesdata)).timestamps_5min=deal([]);% Saves time stamps for each 5 min segment
    datafiles(height(filesdata)).minSPL_1s=deal([]);           % saves min SPL found for each 1 sec segment
    datafiles(height(filesdata)).maxSPL_1s=deal([]);           % saves max SPL found for each 1 sec segment  
    datafiles(height(filesdata)).minSPL_20s=deal([]);           % saves min SPL found for each 20 sec segment
    datafiles(height(filesdata)).maxSPL_20s=deal([]);           % saves max SPL found for each 20 sec segment
    datafiles(height(filesdata)).minSPL_5min=deal([]);         % Saves min SPL for for each 5 min segment
    datafiles(height(filesdata)).maxSPL_5min=deal([]);         % Saves max SPL for each 5 min segment
    datafiles(height(filesdata)).broadband_1s=deal([]);          % Saves the broadband 10 - 10000Hz 1 sec averages
    datafiles(height(filesdata)).broadband_20s=deal([]);  % Saves the broadband 10 - 10000Hz 20 sec averages
    datafiles(height(filesdata)).broadband_5min=deal([]);% Saves the broadband 10 - 10000Hz 5 min averages
    datafiles(height(filesdata)).negclipped=deal([]);   % Saves results of clipping test; positive clipping
    datafiles(height(filesdata)).posclipped=deal([]);
    
    
    
    
    %% Construct the results struct.
    results=struct;
    results.bands=filters.bands;                        % Filter bands.
    results.fc=filters.fc;                             % Band center frequencies.
    results.fm=filters.fm;                              % Precise band center frequencies.
    results.bwcorr=filters.bwcorr;                      % Window correction factor; ratio between Hann-weighted, 0% overlap and unweighted.
    results.station=depData.station;                        % The station name.
    results.position=[depData.mooringLat ', ' depData.mooringLon];                         % The latitude and longitude of deployment.
    results.broadband = filters.bb;                    % Broadband filter
    
    outputLocation = uigetdir(fullfile(depData.dataPath,'..\..', 'Results'), 'Select Data Ouput Location');
    cd(outputLocation)
    
    for fileno = 1:height(filesdata)
        pause(5)
        tic
        display([char(filesdata.name(fileno)) ' file ' num2str(fileno) ' of ' num2str(height(filesdata)) ' total']) % Displays the filenumber that is be processed
        
        [Q_01(fileno),sig,sr(fileno),duration(fileno),ts(fileno),stdrms(fileno),meanv(fileno),meanvDC(fileno)]=Q01([depData.dataPath '\' char(filesdata.name(fileno))]);
        
        if Q_01(fileno)==1
        %% Fill in blanks if file can not be read
            Q_05(:,fileno) = NaN;
            Q_13(fileno) = NaN;
            warning(['File ' char(filesdata.name(fileno)) ', index ' num2str(fileno) ', is not readable and has been skipped.'])
            continue
        else
            %% QC_05: Check if more than the limit of the data are clipped, from app.Maxofclippeddata.
            Q_05(:,kk)=Q05([depData.dataPath '\' char(filesdata.name(fileno))],data,0.01);  %Clip limit set for 1%
                        
            %% QC_13: Check if data is stationary
            Q_13(kk) = Q13(data,sr(kk),120); % 120 can be made variable, but for now we are standardizing it.
        end

        if seconds(duration(fileno)) < seconds(5)
            warning(['File ' char(filesdata.name(fileno)) ', index ' num2str(fileno) ', is less than 5 seconds long and therefore has been skipped.'])
            continue
        end
                   
        sig1 = sig - mean(sig);                         % Removes DC offset - doesn't make that big of a difference
        samples = length(sig1);                         % The no. of samples per file
        n_segments = floor(samples/sr);                 % Number of 1 second segments (e.g.  57600000 samples / 32000 samples/sec = 1800 1 sec segments (1800 / 60 sec = 30 minutes)
    
        data = reshape(sig1(1:sr*n_segments),sr,n_segments); % Reshape to segmentwise columns. Each column corresponds to a second, and each row is a sample.
        ps = 2*abs(fft(repmat(w,1,n_segments)/sr.*data,[],1).^2)*filters.window_corr;   %Repmat makes a sr*n_segments array with each column containing the hann window (filters.w)
    
        % Third-octave band levels per 1 s segments:
        bands_1s=NaN(n_segments,filters.xmax+1);    % no of 1 sec segments * 42 filters (TOL bands)
    
        lowcut=11;          % Lower ten TOL bands are not used in this analysis.
        for n=lowcut:filters.xmax+1                                                         % There's no reason to use filters at the really low frequencies - these are skipped, hence 11:42.
            bands_1s(:,n)=sum(sqrt(ps(filters.bands(:,n),:).^2))';                  % Average rms within each 1 sec band.
        end
        
        data_1s = reshape(bands_1s,1,n_segments,filters.xmax+1);   
        
        
        min_1s = squeeze(sqrt(min(data_1s(:,:,:).^2)))';                                  % Squeeze function removes singleton dimensions (see illustration dd = randn(2,1,3), squeeze(dd).). Sqrt and .^2 are necessary to ensure values are positive.
        max_1s = squeeze(sqrt(max(data_1s(:,:,:).^2)))';
        freqs=[NaN(1,10) filters.fc(11:filters.xmax+1)];   % Third-octave bands analysed, NaNs for low-frequencies not analyzed
        
        broadband = zeros(n_segments,1) ;                                               % Calculation of Broadband rms
        broadband(:,1) = sum(sqrt(ps(filters.bb(:,1),:).^2))';
    
        % Checking for clipping in the recordings:
        clipped_1s = zeros(2,n_segments);                                               % A signal is considered to be clipped if the amplitude is more than 90% of the clipping level
        for k = 1:size(data,2)
            clipped_1s(1,k) = sum(data(:,k)<-0.9);
            clipped_1s(2,k) = sum(data(:,k)>0.9);
        end
        clipped_1s = clipped_1s';
    
        % Third-octave levels per 20 s segments:
        % Divides file up into segments 20 sec duration.  This rounds down, for
        % the number of complete 20 second chunks.
    
        n_20segments = floor(samples/(sr*20));
       
    
        %If n_segments is a not an expected number, this removes seconds 
        %if there are not 20 for the last segment.
        
        if rem(n_segments,20) ~= 0
            r=rem(n_segments,20);
            bands_1s_shaped=bands_1s;
            bands_1s_shaped(end-(r-1):end,:)=[];
            broadband_shaped = broadband;
            broadband_shaped(end-(r-1):end,:) =[];
        else 
            bands_1s_shaped=bands_1s;
            broadband_shaped=broadband;
        end
        
    
        
        data_20s = reshape(bands_1s_shaped,20,n_20segments,filters.xmax+1);                % 20 seconds, n segments, 42 different bands (three dimensions).
        bands_20s = squeeze(mean(data_20s,1));                                      % Changed from original bands_20s = squeeze(sqrt(mean(data1.^2,1))); --> bands_20s = squeeze(sqrt(mean(data1,1).^2)); and finally to this current version.
        min_20s = squeeze(sqrt(min(data_20s(:,:,:).^2)));                                  % Squeeze function removes singleton dimensions (see illustration dd = randn(2,1,3), squeeze(dd).). Sqrt and .^2 are necessary to ensure values are positive.
        max_20s = squeeze(sqrt(max(data_20s(:,:,:).^2)));
    
        data_20sbb = reshape(broadband_shaped,20,n_20segments);                                   % Broadband averages per 20 sec segments.
        broadband_20s = mean(data_20sbb,1)';
    
        % TOL per 5 min bands:
        % Divides file up into segments 5 min in duration.  This rounds up,
        % in case there aren't enough seconds to fill the last segment.
    
        n_5msegments = floor(samples/(sr*300));
     
        if rem(n_segments,300) ~= 0
            r=rem(n_segments,300);
            bands_1s_shaped=bands_1s;
            bands_1s_shaped(end-(r-1):end,:)=[];
            broadband_shaped = broadband;
            broadband_shaped(end-(r-1):end,:) =[];
        else 
            bands_1s_shaped=bands_1s;
            broadband_shaped=broadband;
        end
     
        data_5m = reshape(bands_1s_shaped,300,n_5msegments,filters.xmax+1);                      % Divides file up into 5 min segments, 42 different bands. Uses the 'shaped' files agagin.
        bands_5min = squeeze(mean(data_5m,1));                                            % Data is squeezed to a matrix (each row corresponds to rms over 5 mins for each filter/band (columns)).
        min_5min = squeeze(sqrt(min(data_5m(:,:,:).^2)));
        max_5min = squeeze(sqrt(min(data_5m(:,:,:).^2)));
    
        data_5mbb = reshape(broadband_shaped,300,n_5msegments);
        broadband_5min = mean(data_5mbb,1)';
    
        % Timestamps.
        %This is generated automatically.  The duration from each sound file is
        %used to generate timestamps for 1s, 20s, and 5 min. One second is
        %removed because the duration is inclusive of the first timestamp.

        %  only if qR is in
        t1 = datetime(filesdata.clockDriftDate(fileno));
        durSec=seconds(duration(fileno));
       
        
        % Timestamps for each 1 sec bin.
        timestamps_1s=t1:seconds(1):t1+durSec;
        timestamps_1s=timestamps_1s(1:end-1);
        % Timestamps for each 20 sec bin
        timestamps_20s=t1:seconds(20):t1+durSec;
        timestamps_20s=timestamps_20s(1:end-1);
        % Timestamps for each 5 min bin
        timestamps_5m=t1:minutes(5):t1+durSec;
        timestamps_5m=timestamps_5m(1:end-1);

        %%  Without QR
        % t1 = filesdata.clockDriftDate(fileno);
        % 
        % % Timestamps for each 1 sec bin.
        % timestamps_1s=t1:seconds(1):t1+seconds(duration(fileno)-1);
        % 
        % % Timestamps for each 20 sec bin
        % timestamps_20s=t1:seconds(20):t1+seconds(duration(fileno)-1);
        % 
        % % Timestamps for each 5 min bin
        % timestamps_5m=t1:minutes(5):t1+seconds(duration(fileno)-1);
        % 
        % Save all variables
        datafiles(fileno).bands_1s=bands_1s;            % Saves bands_1s
        datafiles(fileno).bands_20s=bands_20s;          % Saves bands_20s
        datafiles(fileno).bands_5min=bands_5min;        % Saves bands_5min
       % This was what was in here but it is WRONG, as it pulls from a file
       % list that is not properly filtered.  It has been updated on all
       % scripts. ETG-2022
        %datafiles(fileno).filename=fullfiles(fileno);  % Saves filename
        datafiles(fileno).filename=filesdata.name(fileno);  % Saves filename
        datafiles(fileno).datetime=filesdata.clockDriftDate(fileno);% Saves time stamp from filename
        datafiles(fileno).timestamps_1s=timestamps_1s;  % Saves time stamps for each 1 sec segment
        datafiles(fileno).timestamps_20s=timestamps_20s;% Saves time stamps for each 20 sec segment
        datafiles(fileno).timestamps_5min=timestamps_5m;% Saves time stamps for each 5 min segment
        datafiles(fileno).minSPL_1s=min_1s;           % saves min SPL found for each 1 sec segment
        datafiles(fileno).maxSPL_1s=max_1s;           % saves max SPL found for each 1 sec segment  
        datafiles(fileno).minSPL_20s=min_20s;           % saves min SPL found for each 20 sec segment
        datafiles(fileno).maxSPL_20s=max_20s;           % saves max SPL found for each 20 sec segment
        datafiles(fileno).minSPL_5min=min_5min;         % Saves min SPL for for each 5 min segment
        datafiles(fileno).maxSPL_5min=max_5min;         % Saves max SPL for each 5 min segment
        datafiles(fileno).broadband_1s=broadband;          % Saves the broadband 10 - 10000Hz 1 sec averages
        datafiles(fileno).broadband_20s=broadband_20s;  % Saves the broadband 10 - 10000Hz 20 sec averages
        datafiles(fileno).broadband_5min=broadband_5min;% Saves the broadband 10 - 10000Hz 5 min averages
        datafiles(fileno).negclipped=clipped_1s(:,1);   % Saves results of clipping test; positive clipping
        datafiles(fileno).posclipped=clipped_1s(:,2);   % Saves results of clipping test; negative clipping
        toc
    end
    
    QualityResults.Q_Readable=Q_01;
    QualityResults.Q_Clipping=Q_05;
    QualityResults.Q_Stationary=Q_13;
    QualityResults.duration=duration;
    QualityResults.samprate=ts;
    QualityResults.stdrms=stdrms;
    QualityResults.meanv=meanv;
    QualityResults.meanvDC=meanvDC;
    QualityResults.filesdata=filesdata;

    results.datafiles = datafiles;
    save(resultname, 'results', '-v7.3')
    
end