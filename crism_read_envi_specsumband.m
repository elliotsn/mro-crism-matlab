%
% Function to read a particular spectral summary map from a long wavelength
% (IR) ENVI file containing multiple summary maps. The map is then adjusted in
% several ways to make it more useable. Parameter is the name of the
% spectral parameter to be retrieved and cubfile is the path to the ENVI
% file.
%
function [band, lonvec, latvec] = crism_read_envi_specsumband(parameter, imgfile)

[img, lonvec, latvec, info] = read_envi(imgfile);

% Assume that .hdr file is in same directory with same filename and
% appended extension '.hdr'
hdrfile = [strtok(imgfile,'.'), '.hdr'];
header = crism_read_envi_hdr(hdrfile);

band_names = csvstr2arr(header.band_names);
found = 0;
for i = 1:str2double(header.bands)
    if findstr(band_names{i}, parameter)    
        found = 1;
        break;
    end
end

% If not found:
if ~found
    error([parameter, ' is not a CRISM spectral summary parameter in: ', imgfile]);
else
    % Get the band.
    band = img(:,:,i);

    % Set values that are equal to the data ignore value to 0.
    band( band == info.data_ignore_value ) = 0;

    % Set values that are < 0 = 0.
    band( band < 0 ) = 0;
end

end