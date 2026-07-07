function write_ices_continuousnoise_h5(filename, DT, IR, MD)
% Write data structs to an ICES-format HDF5 file
% using MATLAB's low-level HDF5 API, with correct datatypes.
%
% Emily T Griffiths
% emilytgriffiths@ecos.au.dk
% July 2026 - Aarhus University
%
% INPUTS
%   These structs match the information required by the ICES continuous
%   noise database, and are structured to reflect ICES fomatting. DT, IR,
%   and MD are used for shorthand for the tables required for ICES, to keep
%   code more compact.
%
%   filename - output .h5 path
%   Data            - struct with fields:
%   (DT)            LeqMeasurementsOfChannel1 (, 2, 3, ...) : [nTime x nFreq] double matrix
%                   DateTime : datetime array (length nTime) OR cellstr/string array
%                   already in ISO 8601 text
%   FileInformation - struct, e.g. Email, CreationDate, StartDate, EndDate,
%   (IR)            Institution, Contact, CountryCode, StationCode
%                   (CreationDate/StartDate/EndDate may be datetime or char)
%   Metadata        - struct, e.g. HydrophoneType, HydrophoneSerialNumber,
%   (MD)            RecorderType, RecorderSerialNumber, MeasurementHeight,
%                   MeasurementPurpose, MeasurementSetup, RigDesign,
%                   FrequencyCount, FrequencyIndex, FrequencyUnit,
%                   ChannelCount, MeasurementTotalNo, MeasurementUnit,
%                   AveragingTime, ProcessingAlgorithm, DataUUID,
%                   DatasetVersion, CalibrationProcedure,
%                   CalibrationDateTime, Comments
%
% Field-name-based type overrides are defined in get_field_type() below.
% If the portal's template adds/renames fields, update that map rather
% than the writing logic.
%
% For transparency, this function was writen with some reverse engineering 
% of previous, depreciated Matlab functions using Claude AI, and updated to 
% reflect modern libraries + employing low-level functions.  Presently,  
% this funtion is specific for ICES countinuous noise data formatting.

    GROUP_NAME_DATA     = 'Data';
    GROUP_NAME_FILEINFO = 'FileInformation';
    GROUP_NAME_METADATA = 'Metadata';
 
    if exist(filename, 'file')
        delete(filename);
    end
    fid = H5F.create(filename, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
 
    try
        gid_dt = H5G.create(fid, ['/' GROUP_NAME_DATA],     'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
        gid_ir = H5G.create(fid, ['/' GROUP_NAME_FILEINFO], 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
        gid_md = H5G.create(fid, ['/' GROUP_NAME_METADATA], 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
        
        write_struct_as_group(gid_dt, DT');
        write_struct_as_group(gid_ir, IR);
        write_struct_as_group(gid_md, MD);

        H5G.close(gid_dt);
        H5G.close(gid_ir);
        H5G.close(gid_md);
    catch ME
        H5F.close(fid);
        rethrow(ME);
    end

    H5F.close(fid);
    fprintf('Wrote %s\nVerify with h5disp(''%s'')\n', filename, filename);
end


function write_struct_as_group(gid, S)
% Writes every field of S as a Dataset under group gid (never an
% attribute), with datatype chosen by get_field_type().
    fn = fieldnames(S);
    for i = 1:numel(fn)
        name  = fn{i};
        val   = S.(name);
        dtype = get_field_type(name, val);
        val   = coerce_value(val, dtype);
        write_dataset_generic(gid, name, val, dtype);
    end
end


function dtype = get_field_type(name, val)
% Field-name-based type map, matched against the known-good reference
% file. dtype: 'double' | 'int64' | 'string'
    int_fields = {'FrequencyCount','ChannelCount','MeasurementTotalNo','AveragingTime'};
    str_fields = {'Institution','StationCode','HydrophoneSerialNumber','RecorderSerialNumber'};
    % Everything else: numeric -> double (matches reference; NOT single),
    % char/datetime -> string.
 
    if any(strcmpi(name, int_fields))
        dtype = 'int64';
    elseif any(strcmpi(name, str_fields))
        dtype = 'string';
    elseif ischar(val) || isstring(val) || iscellstr(val) || isa(val,'datetime')
        dtype = 'string';
    else
        dtype = 'double';
    end
end
 
 
function val = coerce_value(val, dtype)
    switch dtype
        case 'double'
            val = double(val);
        case 'int64'
            val = int64(val);
        case 'string'
            if isa(val, 'datetime')
                s = cellstr(datestr(val, 'yyyy-mm-dd HH:MM:SS')); %#ok<DATST>
                val = s;
                if numel(val) == 1
                    val = val{1};
                end
            elseif iscellstr(val) || isstring(val)
                val = cellstr(val);
            elseif ischar(val)
                % already text, leave as-is
            elseif isnumeric(val)
                % e.g. Institution/StationCode/serial numbers stored as
                % numeric but needed as text. Use num2str, NOT char(),
                % since char() on a number misinterprets it as a
                % character code rather than its text representation.
                % If leading zeros must be preserved (e.g. a 4-digit
                % EDMO code), replace num2str(val) with
                % sprintf('%04d', val) here.
                if isscalar(val)
                    val = num2str(val);
                else
                    val = cellstr(num2str(val(:)));
                end
            else
                val = char(val);
            end
    end
end
 
 
function write_dataset_generic(gid, name, val, dtype)
    if strcmp(dtype, 'string')
        write_fixed_string_dataset(gid, name, val);
        return
    end
 
    switch dtype
        case 'double', h5type = 'H5T_IEEE_F64LE';
        case 'int64',  h5type = 'H5T_STD_I64LE';
    end
 
    % Dims kept in MATLAB's native order -- NOT reversed/transposed.
    % This matches the reference file, where e.g.
    % LeqMeasurementsOfChannel1 (passed in as [nFreqBands x nTime])
    % appears on disk with Size 37x2678400, i.e. exactly size(val).
    if isvector(val)
        dims = numel(val);   % includes scalars (dims = 1)
    else
        dims = size(val);
    end
 
    type_id  = H5T.copy(h5type);
    space_id = H5S.create_simple(numel(dims), dims, dims);
 
    dcpl = H5P.create('H5P_DATASET_CREATE');
    H5P.set_chunk(dcpl, dims);   % chunk = full extent, matching reference file
 
    dset_id = H5D.create(gid, name, type_id, space_id, dcpl);
    H5D.write(dset_id, type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', val);
 
    H5D.close(dset_id);
    H5S.close(space_id);
    H5T.close(type_id);
    H5P.close(dcpl);
end
 
 
function write_fixed_string_dataset(gid, name, val)
% Writes FIXED-length ASCII string dataset(s), sized to the longest
% string present, matching the reference file's H5T_STR_NULLTERM /
% H5T_CSET_ASCII convention -- NOT variable-length, NOT UTF-8.
    if ischar(val)
        val = {val};
    end
    n = numel(val);
 
    max_len = 1;
    for i = 1:n
        max_len = max(max_len, length(val{i}));
    end
    str_size = max_len + 1;   % +1 for null terminator (H5T_STR_NULLTERM)
 
    type_id = H5T.copy('H5T_C_S1');
    H5T.set_size(type_id, str_size);
    H5T.set_strpad(type_id, 'H5T_STR_NULLTERM');
    H5T.set_cset(type_id, 'H5T_CSET_ASCII');
 
    space_id = H5S.create_simple(1, n, n);
    dset_id  = H5D.create(gid, name, type_id, space_id, 'H5P_DEFAULT');


        % IMPORTANT: for a FIXED-length string type, H5D.write needs the
    % buffer as a plain char matrix of size [str_size x n] -- one
    % *column* per string, null-padded -- NOT a cell array. (Cell arrays
    % are only correct for variable-length string types.) Passing a cell
    % array here causes MATLAB to flatten it incorrectly, producing an
    % "elements expected" mismatch of exactly n * str_size.
    buf = zeros(str_size, n, 'uint8');   % zero == null padding, matches NULLTERM
    for i = 1:n
        s = uint8(val{i});
        buf(1:numel(s), i) = s;
    end
    buf = char(buf);
 
    H5D.write(dset_id, type_id, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', buf);

    H5D.close(dset_id);
    H5S.close(space_id);
    H5T.close(type_id);
end