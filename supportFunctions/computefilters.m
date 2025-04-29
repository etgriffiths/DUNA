%% compute filters (TOL bands)
function filters = computefilters(samplefile)

a = audioinfo(samplefile);          % get audioinfo
sr = a.SampleRate;                  % Finds samplesrate
filters.sr = sr;                    % information of samplerate saved in the filters struct. 

w = hann(sr,'periodic');            % Hann window for Welch average. 
filters.w = w;
window_corr = sr/sum(w.^2);         % Ratio between Hann-weighted, 0% overlap and unweighted = correction factor. When a window is put on a signal, the energy of the signal will be less than in the original signal. The correction factor is a number multiplied onto the signal, to compensate for this change and depends on the window type
filters.window_corr = window_corr;  % The correction factor is saved in the filters struct. 
G = 10^(3/10);                      % Octave ratio, base 10 system
b = 3;                              % Octave fraction (3 = 1/3 octave)
fref = 1000;                        % Reference frequency (1 kHz)
fc = [1,1.25,1.6,2,2.5,3.16,4,5,6.3,8,10,12.5,16,20,25,31.6,40,50,63,80,...   %Nominal center frequencies in Hz
    100,125,160,200,250,316,400,500,630,800,... 
    1000,1250,1600,2000,2500,3160,4000,5000,6300,8000,...
    10000,12500,16000,20000,25000,31600,40000,50000,63000,80000,...    
    100000,125000,160000,200000,250000,316000,400000,500000];
filters.fc=fc;                      % Saves nominal center frequencies in filters struct. 

f = (0:sr/2)';                      % 1 Hz frequency bands in a column up until the Nyquist frequency
xmax = floor((log(f(end)/fref)/log(G)+10-1/(2*b))*b); % no. of filters = 41 for a sr of 32000 and 46 for a sr of 96000
filters.xmax = xmax;                % Saves the maximal no. of filters in the filters struct.
x = (0:xmax);                       % row of 41 columns for a sr of 32kHz. 
fm = G.^((x-30)/b)*fref;            % exact centre frequencies
filters.fm = fm; 
% Fc = 1000*((2^(1/3)).^[-20:1:17]); % Kristian Beedholm, tested 01.06.18.
f1 = G^(-1/(2*b))*fm;               % Lower band limits
f2 = G^(1/(2*b))*fm;                % Upper band limits
% % f1 = G^(-1/(2*b))*filters.fc;   % Lower band limit based on nominal center frequencies. Using the nominal center frequencies gives almost exactly the same as f1 and f2 in use now (exact center frequencies.  
% % f2 = G^(1/(2*b))*filters.fc;    % Upper band limit based on nominal center frequencies

bands = false(sr/2+1,xmax+1);       % Makes a sr/2 * max(x) number array of 0's. Each column corresponds to a TOL band and each row to a 1 Hz band. 
for n=11:xmax+1                     % For columns 11:xmax+1 (each TOL band), the determined upper and lower limits defines what 1 Hz bands are included to defined that given TOL band - these are changed to 1. 
    bands(:,n)=f>=f1(n) & f<f2(n);
end

filters.bands = bands;              % Bands are saved in the struct array. 
bb = sum(filters.bands(:,11:41),2); % Variable that includes the sum of all filters in a 10-10000Hz band. 
filters.bb = logical(bb);           % Column of all 0 and 1 logicals, with 1 corresponding to the 1 Hz bands included in the broadband filter.     
filters.bwcorr=sum(bands,1)./(f2-f1); % Correction between actual bandwidth and ideal bw

end