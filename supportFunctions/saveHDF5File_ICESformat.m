% Organise decidecade levels (DDEC) as single text output (instead of structure) 
% Formated for the HELCOM ICES database.
%
% This version is designed to work with DUNA, converted into a function by 
% Emily T. Griffiths, 2020-2026.
%
% Input:
%   filePath & fileName -   Location and name of data struct.
%   depData             -   Metadata associated with deployment
%   depID               -   Deployment ID, taken from DUNA
%   Email               -   Email of user. Manually entered in DUNA.

% Output:
%   Files saved by month in ICES h5 formatting.

%This function is dependent on the sublibrary 'easyh5', located here: https://github.com/NeuroJSON/easyh5


function [] = saveHDF5File_ICESformat(filePath, fileName, depData, depID, Email, calDate)

%% Load the data
load(fullfile(filePath,fileName));

stationlist=[ "12870" "12869" "12868" "12867" "12866" "12865" "12864" "12863",
    "DKMst201" "DKMst105" "DKMst104" "DKMst103" "DKMst038" "DKMst037" "DKMst036" "DKMst035"]';

% Select the folder to save the file
outputLocation = uigetdir([depData.dataPath '..\..'], 'Select Data Ouput Location');

try
    lmoc= timetable2table(TOL);
catch
    lmoc = timetable2table(DDEC);
end
LeqMeasurementsOfChannel1= lmoc(:,2:end);
DaTi=lmoc(:,1);
dDT=datetime(table2array(DaTi), 'InputFormat','yyyy-MMM-dd HH:mm:ss');


 %% IR data
        Institute='5123'  ;     %char(6)			EDMO code of the measuring institution -- Set to Aarhus University
        Contact = 'Jakob Tougaard';        %char(225)			Point of contact Contact of all future external queries/who submits/holds responsibility for submission. Set to JAT for AU.
        CountryCode = 'DK' ;       %char(4)			ISO country code
        StationCode  = char(stationlist(find(contains(stationlist(:,2), (depID(1:8)))),1))   ;  %char(10)			Station code The station code and its associated coordinates can be found in the ICES station dictionary.

 %% MD data
        if strncmp(depData.loggerType,'SM',2)%|| strncmp(depData.loggerType, 'ST600',5) %  Wildlife Acoutics or ST600 in-situ hp
            HydrophoneType='IR'; 
        else    
            HydrophoneType='SEH'; 
        end            %nvarchar(225)   Manufacturer and used hydrophone type/model e.g. 'Brüell&Kjaer 8106'. This field needs to be an array if there are multiple channels (one per channel).	
        
        if isempty(depData.hpID)
            HydrophoneSerialNumber = '';
        else
            HydrophoneSerialNumber=depData.hpID; 
        end    %nvarchar(50)			e.g. 'SN#1234'This field needs to be an array if there are multiple channels (one per channel).
        if strncmp(depData.loggerType,'SM',2)%  Wildlife Acoutics
            if strncmp(depData.loggerType,'SM3',3)
                RecorderType='WSM3M';
            else
                RecorderType = 'WSM2M';
            end
        elseif strncmp(depData.loggerType,'DSG',3)   
            RecorderType='LHDS';
        else
            RecorderType='OIS5H';
        end                              %varchar(50)			Recorder/data logger type e.g. 'Soundtrap'
        if depData.loggerID == "n/a"
            RecorderSerialNumber= '';
        else
            RecorderSerialNumber=extractAfter(depData.loggerID, '_');          %nvarchar(50)			Recorder serial number e.g. 'SN#2345'
        end
        MeasurementHeight=2;    %float(10)              Height above the seafloor, in meters.
        MeasurementPurpose= 'HMON';
        MeasurementSetup='AUT'  ;                      %varchar(10)			Description of deployment. Mandatory in case the purpose is 'HELCOM monitoring'
        RigDesign='MFB' ;                      %varchar(10)			Description of deployment construction. Mandatory in case the purpose is 'HELCOM monitoring'.
        FrequencyCount=int64(size(LeqMeasurementsOfChannel1, 2));                  %int(2)                 Number of frequency bands.
        FrequencyIndex=char(extractBefore(LeqMeasurementsOfChannel1.Properties.VariableNames, 'Hz')) ;                         %float(10)              Third octave band nominal center frequencies.
        FrequencyUnit='Hz' ;                        %varchar(10)             Hz or kHz
        ChannelCount=int64(1)   ;                 %int(2)         		Number of channels used
        MeasurementUnit='SPL'  ;              %varchar(10)			Unit in which the values are in e.g. dB re 1µPa
    
        sec=dDT(2)-dDT(1);
        AveragingTime=reshape(int64(seconds(sec) ), 1, [])  ;             %int(5)             	Averaging time in seconds.           
    
        ProcessingAlgorithm='AUBIAS' ;            %nvarchar(225)			Algorithm used to process the data e.g. computation method for third octave band (fft, filter bank ...).	
        
        DatasetVersion='v1.0' ;                 %nvarchar(255)			Indicates version of the submitted dataset. It should be changed upon resubmission.
        CalibrationProcedure='CPC'  ;          %nvarchar(255)			Method used to check the measuring chain. E.g. point calibration with pistonphone, functionality test with microphone and loudspeaker (frequency dependent), or other method used to check the measuring chain. E.g. point calibration with pistonphone, functionality test with microphone and loudspeaker (frequency dependent), or other. Mandatory in case the purpose is 'HELCOM monitoring'.	
        
        CalibrationDateTime   =datestr(calDate.calibrationDate,'yyyy-mm-dd HH:MM:SS');            %datetime(21)			Date of when the system was last calibrated. Mandatory in case 'CalibrationProcedure' is specified UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss].	
        
        Comments  = 'na';       %char(255)   

%% Format by Date
        mons=unique(dDT.Month);
        for m = 3:length(mons)
            S=(dDT.Month==mons(m));        
            LMOC_byMo=table2array(LeqMeasurementsOfChannel1(S,:));
            DT_byMo=dDT(S,:);
            
            DataUUID=char(java.util.UUID.randomUUID);                        %nvarchar(255)			'Unique identification number, linking the data submission to the corresponding raw data. It should be used for resubmissions of the same data; matlab function available: uuid = char(java.util.UUID.randomUUID);'.	
            MeasurementTotalNo=int64(size(LMOC_byMo, 1));             %int(5)                 Number of measurements. This field needs to be an array if there are multiple channels (one per channel).	
        
            
            ofilename=['ICES_HELCOM_' depID '_v1_Month' num2str(mons(m)) ];
    
            %Get TimeStamp in UTC that this file is created and format it to ISO 8601.
            t=datestr(now,'yyyy-mm-dd HH:MM:SS');
            t=datetime(t,'TimeZone', 'UTC+1');
            t.TimeZone='UTC';
            t=datestr(t,'yyyy-mm-dd HH:MM:SS');
            
            StartDate=datestr(DT_byMo(1,:),'yyyy-mm-dd HH:MM:SS' )  ;    %datetime(21)			Measurement collection start date. Date of file creation. UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss].	
            EndDate=datestr(DT_byMo(end,:),'yyyy-mm-dd HH:MM:SS' )  ;  
    
            %%  Create the three data structs seperately.
            DT=struct('LeqMeasurementsOfChannel1',LMOC_byMo,... %Equivalent continuous sound pressure level measurements over time for all covered frequency bands. One frequency per column. In case there are multiple channels, there should be an array of values for each channel. If there are 3 channels, there would be three arrays called LeqOfChannel1, LeqOfChannel2, LeqOfChannel3. In case of channel failure, report NAN values.	
                     'DateTime',DT_byMo); ...   %UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss].
    
            IR=struct('Email', char(Email), ...	%E-mail of the author. Creator of the HDF5 file/ who holds responsibility for data QA and creation of the submited hdf5 file.	
                    'CreationDate',t,... UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss]	
                    'StartDate',StartDate,... %Measurement collection start date. Date of file creation. UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss].	
                    'EndDate', EndDate, ...Measurement collection end date. Date of file creation. UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss].	
                    'Institution',Institute,... %EDMO code of the measuring institution
                    'Contact', Contact,...			Point of contact Contact of all future external queries/who submits/holds responsibility for submission	
                    'CountryCode', CountryCode,... %ISO country code
                    'StationCode', StationCode);
    
            MD=struct('HydrophoneType', HydrophoneType,...         %nvarchar(225)          Manufacturer and used hydrophone type/model e.g. 'Brüell&Kjaer 8106'. This field needs to be an array if there are multiple channels (one per channel).	
                    'HydrophoneSerialNumber',HydrophoneSerialNumber,...   %nvarchar(50)			e.g. 'SN#1234'This field needs to be an array if there are multiple channels (one per channel).	
                    'RecorderType',RecorderType, ...                    %varchar(50)			Recorder/data logger type e.g. 'Soundtrap'
                    'RecorderSerialNumber',RecorderSerialNumber, ...    %nvarchar(50)			Recorder serial number e.g. 'SN#2345'
                    'MeasurementHeight', MeasurementHeight, ...               %float(10)              Height above the seafloor, in meters.
                    'MeasurementPurpose',MeasurementPurpose,...
                    'MeasurementSetup',MeasurementSetup,...               %varchar(10)			Description of deployment. Mandatory in case the purpose is 'HELCOM monitoring'
                    'RigDesign', RigDesign,...                      %varchar(10)			Description of deployment construction. Mandatory in case the purpose is 'HELCOM monitoring'.
                    'FrequencyCount', FrequencyCount,...                   %int(2)                 Number of frequency bands.
                    'FrequencyIndex',str2num(FrequencyIndex)',...      %float(10)              Third octave band nominal center frequencies.
                    'FrequencyUnit', FrequencyUnit,...                         %varchar(10)             Hz or kHz
                    'ChannelCount', ChannelCount,...                   %int(2)         		Number of channels used
                    'MeasurementTotalNo', MeasurementTotalNo,...       %int(5)                 Number of measurements. This field needs to be an array if there are multiple channels (one per channel).	
                    'MeasurementUnit',MeasurementUnit,...           %varchar(10)			Unit in which the values are in e.g. dB re 1µPa
                    'AveragingTime',AveragingTime,...             	Averaging time in seconds.
                    'ProcessingAlgorithm',ProcessingAlgorithm,...          %nvarchar(225)			Algorithm used to process the data e.g. computation method for third octave band (fft, filter bank ...).	
                    'DataUUID', DataUUID,...                      %nvarchar(255)			'Unique identification number, linking the data submission to the corresponding raw data. It should be used for resubmissions of the same data; matlab function available: uuid = char(java.util.UUID.randomUUID);'.	
                    'DatasetVersion', DatasetVersion,...             %nvarchar(255)			Indicates version of the submitted dataset. It should be changed upon resubmission.
                    'CalibrationProcedure', CalibrationProcedure,...    %nvarchar(255)			Method used to check the measuring chain. E.g. point calibration with pistonphone, functionality test with microphone and loudspeaker (frequency dependent), or other method used to check the measuring chain. E.g. point calibration with pistonphone, functionality test with microphone and loudspeaker (frequency dependent), or other. Mandatory in case the purpose is 'HELCOM monitoring'.	
                    'CalibrationDateTime', CalibrationDateTime,...       %datetime(21)			Date of when the system was last calibrated. Mandatory in case 'CalibrationProcedure' is specified UTC DateTime in ISO 8601 format: YYYY-MM-DDThh:mm[:ss] or YYYY-MM-DD hh:mm[:ss].	
                    'Comments',Comments);
    
            %Merge them into one struct for the H5 file.
            ICES_data=struct('Data',DT,...
                'FileInformation',IR,...
                'Metadata',MD);
            
            save([outputLocation ofilename '.mat'], 'ICES_data', 'DT_byMo')
    
            %% creates and writes data to hdf5 file (file must not exits at time of function call)

            if exist([outputLocation ofilename '.h5'], 'file')
                delete(fullfile(outputLocation, [ofilename '.h5']));   % start fresh (if intended)
            end

            %matlab_write_recursive_hdf5([ofilename '.h5'], '',ICES_data);

            write_ices_continuousnoise_h5(fullfile(outputLocation, [ofilename '.h5']), DT, IR, MD);
                   
        end   
        disp(['Data exported in ' num2str(length(mons)) ' files to: ' outputLocation])

end

