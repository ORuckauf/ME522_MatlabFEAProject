function [units,scale] = getDXFUnits(filename)

    fid = fopen(filename);
    C = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = strtrim(C{1});
    
    units = 0; % default = unitless
    for i = 1:length(lines)-1
        code = str2double(lines{i});
        value = lines{i+1};
        if code == 9 && strcmp(value, '$INSUNITS')
            units = str2double(lines{i+3}); % the 70 code value after $INSUNITS
            break;
        end
    end

    switch units
        case 0, scale = 1;
        case 1, scale = 0.0254;  % inches -> meters
        case 2, scale = 0.3048;  % feet -> meters
        case 4, scale = 0.001;   % mm -> meters
        case 5, scale = 0.01;    % cm -> meters
        case 6, scale = 1;       % meters
        case 7, scale = 1000;
        case 8, scale = 0.0000254; 
        case 9, scale = 0.0000254;
        otherwise, scale = 1; 
    end
end
