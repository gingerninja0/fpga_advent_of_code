clear
clc

data = importdata("input.txt");

len = length(data);

dial_val = 50; % Initially the safe dial starts at 50
zero_count = 0; 

for i = 1:len

    temp = data(i);
    temp = temp{1};

    dir = temp(1);
    num = str2double(temp(2:end));

    if strcmp(dir,"L")
        dial_val = dial_val - num;
    else
        dial_val = dial_val + num;
    end

    % This condition looks weird because it matches the operation in the
    % fpga processor
    % Normally it would be: dial_val < 0
    while dial_val + 0 < 0
        dial_val = 100 + dial_val;
    end

    % This condition looks weird because it matches the operation in the
    % fpga processor
    % Normally it would be: dial_val > 99
    while 99 - dial_val < 0  
        dial_val = dial_val - 100;
    end
    
    if dial_val == 0
        zero_count = zero_count + 1;
    end

end

zero_count

% zero_count = 1154 (as required)