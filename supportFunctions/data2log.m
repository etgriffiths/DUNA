% Organise decidecade levels, apply clip level, and convert into dB.
%
% Current Version by Emily T. Griffiths, 2020-2024, reformated as a function to
% work within DUNA.
%
% Other Developers:
%   Pernille Meyer Sørensen, 2018. 
%   Line Hermannsen, 2019-2020.
%   Mia L. K. Nielsen, 2018-2029.



function [allnoise, resultname] = data2log(depData, AnaLog)

    OutLoc = unique(AnaLog.resultsPath);
    dFile = AnaLog.dataFile(AnaLog.analysisType=='DDEC-volts');
    path = fullfile(OutLoc, dFile);

    load(path)
    
    for  i = 1:length(results.datafiles)
        if isempty(results.datafiles(i).bands_1s)
            allnoise.TOLdB{i} = nan ;
            allnoise.minTOLdB{i} = nan ;
            allnoise.maxTOLdB{i} = nan ;
            allnoise.timestamps{i} = nan ;
            allnoise.bb{i} = nan ;
        elseif ~isfield(results.datafiles,'minSPL_1s')
            allnoise.TOLdB{i} = 10*log10(results.datafiles(i).bands_1s(:,11:end))+depData.ClipLevel;
            allnoise.timestamps{i} = results.datafiles(i).timestamps_1s(:);
            allnoise.bb{i} = 10*log10(results.datafiles(i).broadband(:))+depData.ClipLevel;% broadband 10-10000Hz (11 = 10Hz, 41 = 10000Hz).
            allnoise.fm=results.fm;
        else
            allnoise.TOLdB{i} = 10*log10(results.datafiles(i).bands_1s(:,11:end))+depData.ClipLevel;
            allnoise.minTOLdB{i} = 10*log10(results.datafiles(i).minSPL_1s(:,11:end))+depData.ClipLevel;
            allnoise.maxTOLdB{i} = 10*log10(results.datafiles(i).maxSPL_1s(:,11:end))+depData.ClipLevel;
            allnoise.timestamps{i} = results.datafiles(i).timestamps_1s(:);
            allnoise.bb{i} = 10*log10(results.datafiles(i).broadband_1s(:))+depData.ClipLevel;% broadband 10-10000Hz (11 = 10Hz, 41 = 10000Hz).
            allnoise.fm=results.fm;
        end
    end
    resultname=strcat('DDECdB_Allnoise_CL',num2str(round(depData.ClipLevel)),'_',dFile);
    save(fullfile(OutLoc, resultname),'allnoise','-v7.3');
end

