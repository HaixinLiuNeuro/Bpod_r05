function sma=addBitcodeStates(sma, trialnum, state)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %            BITCODE               %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Put in bitcode: do this my own damn self because the brodylab
    % hacked way to do this sucks and doesn't work
    nbits = 12; % 12 possible bits for trials (4096)
    trialnum = dec2bin(trialnum);
    trialnum = ['1' '0'*ones(1, nbits-length(trialnum)) trialnum];
    time_per_state = 0.005; % 5 ms bitcode signals
    
    % First, send a hi sync signal
    % Next, send bitcode
    for i=1:length(trialnum),
        % break state between bits
        if(i>1)
            sma = AddState(sma, 'Name', ['BitcodeBreak' num2str(i-1)], ...
                'Timer', time_per_state,...
                'StateChangeConditions', {'Tup', ['BitcodeByte' num2str(i-1)]},...
                'OutputActions', {'PWM1', 0});
        end
        if(i==length(trialnum))
            next_state=state;
        else
            next_state=['BitcodeBreak' num2str(i)];
        end
        sma = AddState(sma, 'Name', ['BitcodeByte' num2str(i-1)], ...
            'Timer', time_per_state,...
            'StateChangeConditions', {'Tup', next_state},...
            'OutputActions', {'PWM1', 255*str2double(trialnum(i))});
    end
