
%% Restructure DDEC results from cell arrays to timetable
%
% [DDEC, BB] = cell2timetable(filePath,fileName,saveTimetable,savePath)
%
% Inputs:       filePath
%               fileName (example: DDECdB_Allnoise_CL172_TN1_DK_20190527_to_20190820_DSG1_437641)
%               saveTimetable - true or false. Set saveTimetable to true to
%                   save or false (default) to just create the timetable
%                   from the original struct/cell file. "_timetable" will
%                   be appended to the fileName, when saving the new
%                   mat-file.
%               savePath (optional) - default: savePath == filePath
%               desc - (optional) char string. Short Project Description
%
% Outputs:      DDEC - timetable with Decidecade data
%               BB  - timetable with BroadBand (10 Hz to 10 kHz) levels
%
% Script written by
% Michael Ladegaard, michael.ladegaard@bio.au.dk,
% 2022 May 18
%
% Updated 2022 June 1, Michael Ladegaard: indexing bug fix
%
% Updated 5/7/2022 by Emily T. Griffiths to be more broadly applicable to
% DDEC data. emilytgriffiths@ecos.au.dk
%
% Updated 26/10/2022 by Emily T. Griffiths for the NSE project. To export
% the file name it saves as, and so that it doesn't remove the '.mat' til
% the end of the file name because that was causing issues. 
%
% Update 27/10/2022, ETG, fixed bug if datetime information is missing in
% the array.
%
% Updated on 18/11/2024 by ETG to replace TOL with DDEC, for decidecade data,
% which is more accurate. Function now works within DUNA. 

function [DDEC, BB, saveName] = cell2timetable(filePath,fileName,saveTimetable,savePath, desc)


if nargin < 2
    help cell2timetable ;
    return ;
end
if nargin < 3
    saveTimetable = false ;
end
if nargin < 4
    savePath = filePath ;
end
if nargin < 5
    desc = '';
end

%% Load the data
load(fullfile(filePath,fileName));

%% Get frequency and date info
% Find relevant DDEC centre frequencies
try
    DDECfreqs = allnoise.fm(allnoise.fm >= 10) ; % Only >=10 Hz 1/3 octave bands have been computed
catch % ugly solution to the problem that allnoise.fm is missing from 'O:\Tech_DK-Noise-Monitoring\TANGO\Analysis\Results\TangoDKNord4\A_mayDeployment\DDECdB_Allnoise_CL172_TN4_DK_20190527_to_20190826_DSG4_437635.mat'
    DDECfreqs =  [10.0000000000000	12.5892541179417	15.8489319246111	19.9526231496888	25.1188643150958	31.6227766016838	39.8107170553497	50.1187233627272	63.0957344480193	79.4328234724282	100	125.892541179417	158.489319246111	199.526231496888	251.188643150958	316.227766016838	398.107170553497	501.187233627272	630.957344480193	794.328234724282	1000	1258.92541179417	1584.89319246111	1995.26231496888	2511.88643150958	3162.27766016838	3981.07170553497	5011.87233627272	6309.57344480193	7943.28234724281	10000	12589.2541179417	15848.9319246111	19952.6231496888	25118.8643150958	31622.7766016838	39810.7170553497]' ;
end
DDECfreqs = round(DDECfreqs,0) ; % round to nearest integer
d=size(allnoise.TOLdB{10});
if  length(DDECfreqs) > d(2)
    DDECfreqs=DDECfreqs(1:d(2));
end

% Nominal frequency band for these 37 bands
DDECfreqs_nominal = [10,12.5,16,20,25,31.5,40,50,63,80] ;
DDECfreqs_nominal = [DDECfreqs_nominal,DDECfreqs_nominal*10,DDECfreqs_nominal*100,DDECfreqs_nominal*1000, DDECfreqs_nominal*10000]' ;
DDECfreqs_nominal = strcat(string(DDECfreqs_nominal(1:length(DDECfreqs))),"Hz") ;

% Find total number of timestamps
Ntimestamps = sum( cellfun(@(x) length(x),allnoise.timestamps) ) ;

%% Preallocate timetable - fill with NaNs

%% properly format datetime.
if isdatetime(allnoise.timestamps{1,1})
    dtis=zeros(size(allnoise.timestamps));
    for arg = 1:length(allnoise.timestamps)
        dtis(arg)=isdatetime(allnoise.timestamps{1,arg});
    end
    [~, Index] = find(dtis==0);
    if length(Index) > 0
        for i =1:length(Index)
            allnoise.timestamps{1,Index(i)} = NaT; 
            allnoise.timestamps{1,Index(i)}.TimeZone='Z';
        end
    end


    dtvertcat=vertcat(allnoise.timestamps{:});
else
    tempdt=vertcat(allnoise.timestamps{:});
    dtvertcat = datetime(tempdt, 'ConvertFrom','datenum');
end

DDEC = array2timetable(nan(Ntimestamps,length(DDECfreqs)),"RowTimes",dtvertcat,"VariableNames",DDECfreqs_nominal) ; % ,"VariableNames",strcat(string(DDECfreqs),"Hz")

%% Add some info to timetable
DDEC.Properties.Description = desc ;
DDEC.Properties.UserData = fileName ;

BB = DDEC(:,1) ; % This way of making BB also copy-paste all of the above properties
BB.Properties.VariableNames{1} = '10Hz_to_10kHz' ; %

%% Insert DDEC data into timetable
Nrow = 0 ; % row counter
h = waitbar(0,{'Creating timetable from cells';'Please wait...'}) ;
for k = 1:length(allnoise.TOLdB)
    % Insert noise level data
    idx = Nrow + [1, height(allnoise.TOLdB{1,k})] ;
    DDEC{idx(1):idx(2),:} = allnoise.TOLdB{1,k} ;
    if isfield(allnoise, 'bb') 
        BB{idx(1):idx(2),:} = allnoise.bb{1,k} ; 
    end
    % Update row counter and waitbar
    Nrow = Nrow + length(allnoise.timestamps{1,k}) ;
    waitbar(k/length(allnoise.TOLdB),h)
end
close(h)

%% remove missing - remove all columns with no data
DDEC = rmmissing(DDEC,'MinNumMissing',size(DDEC,2)) ; % remove rows where data in all columns is NaN
BB = rmmissing(BB,'MinNumMissing',size(BB,2)) ; % remove rows where data in all columns is NaN

%% dateshift - shift date times to the start of the second
% i.e. ignore any potential millisecond info (to prepare the timetable for
% using the retime function with "fillwithmissing", which creates regular
% (1 s) spacing between rows)
DDEC.Time = dateshift(DDEC.Time,'start','second') ;
BB.Time = dateshift(BB.Time,'start','second') ;

% %% Fill missing data
% Might be useful in some plotting functions in order to avoid long
% connecting lines over areas with missing data.
% Fill with NaNs
DDECtimes = DDEC.Time ; % Extract times for checking that 'fillwithmissing' is done correctly without uintentionally removing/missing some rows
DDEC = retime(DDEC,"secondly","fillwithmissing") ;
BB = retime(BB,"secondly","fillwithmissing") ;

% Check that all rows are still part of the new table - print a warning if in case of a mismatch
if numel(DDECtimes) ~= nnz(ismember(DDECtimes,DDEC.Time))
    fprintf('\n\t WARNING: A total of %d data rows were unintentionally deleted - check retime function and its "fillwithmissing" performance. Rounding of input timestamps might be needed. \n',numel(DDEC.Time)-nnz(ismember(DDECtimes,DDEC.Time)) );
end

%% Save time table (-v7.3 format to allow >2 GB file size)
% Data is saved in the same folder as the original data file with the name
% extenstion "_timetable" attached to the original file name, unless the
% savePath input is given
if saveTimetable
    fileName = extractBefore(fileName,'.mat') ; % Strip fileName of the file extension
    saveName = fullfile(savePath,strcat(strcat(fileName,"_timetable"),".mat")) ;
    save(saveName,"DDEC","BB",'-v7.3')
    fprintf('\n   Time tables "DDEC" and "BB" saved at: \n\t %s \n',saveName)
end

end
