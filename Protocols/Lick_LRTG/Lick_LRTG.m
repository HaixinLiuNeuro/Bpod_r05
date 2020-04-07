%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function Lick_LRTG
% This protocol demonstrates control of the Island Motion olfactometer by using the hardware serial port to control an Arduino Leonardo Ethernet client. 
% Written by Josh Sanders, 10/2014.
%
% SETUP
% You will need:
% - An Island Motion olfactometer: http://island-motion.com/5.html
% - Arduino Leonardo double-stacked with the Arduino Ethernet shield and the Bpod shield
% - This computer connected to the olfactometer's Ethernet router
% - The Ethernet shield connected to the same router
% - Arduino Leonardo connected to this computer (note its COM port)
% - Arduino Leonardo programmed with the Serial Ethernet firmware (in /Bpod Firmware/SerialEthernetModule/)

% HL 2016-3-10
% Lick taste task
% tone ready light go
% 3rd step of Lick_TRLG
% add in punishment for pre-mature response during ready cue
% delivery Suc Qui Water dependenting on readycue (outcome cue)
% 2016-7-29
% modified from _P_T
% only use S and Q others the same

% HL 2016-9-20 
% modify task:
% Light cue means ready, tone means go. Later phase 3 adding another tone
% as NoGo cue
% this is Phase 1 training protocol
% Also, change water delivery method. Just one big drop upon response
global BpodSystem

%% Define parameters
disp('Lick_LRTG')
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
% disp(S)
% pause
% disp(BpodSystem)
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    disp('empty default setting 5khz GO cue')
    S.GUI.GoCueDur = 3;
    S.GUI.ReadyCueDur_min = 2;
    S.GUI.ReadyCueDur_max = 4;
%     S.GUI.RespDur = 3; % response window licks get rewarded
    S.GUI.RewardWaterDur = 0.8; % water reward big drop upon resp
    S.GUI.TimeOutDur = 4;% time out if respond during ready cue
    S.GUI.MinITI = 10;
    S.GUI.MaxITI = 15;
    S.GUI.PreReadyGate = 0.01;
    S.GUI.GoTone = 5;% 5khz
    S.GUI.NoGoTone = 12;% 12khz
else
        disp(S)
        if any(ismember(fieldnames(S), 'go_tone')) && ...
                any(ismember(fieldnames(S), 'nogo_tone'))
            S.GUI.GoTone = S.go_tone;% 5khz
            S.GUI.NoGoTone = S.nogo_tone;% 12khz
        else
            error('protocol setting is wrong!')
        end
        S.GUI.GoCueDur = 3;
        S.GUI.ReadyCueDur_min = 2;
        S.GUI.ReadyCueDur_max = 4;
%         S.GUI.RespDur = 3; % response window licks get rewarded
        S.GUI.RewardWaterDur = 0.8; % water reward big drop upon resp
        S.GUI.TimeOutDur = 4;% time out if respond during ready cue
        S.GUI.MinITI = 10;
        S.GUI.MaxITI = 15;
        S.GUI.PreReadyGate = 0.01;
end
%[HL] define some variable
% mouse hearing range 1k - 100kHz 5-15 is good for behavior according to HK
% gocue_tone = 250; %whitenoise
punishment_tone = 250; %whitenoise for signaling preM response
punishtonedur = 0.5;

Lick = 'Port3In'; 
Vacuum = 'PWM5';
Light = 'PWM6';
Port = 'PWM2';
trialtype_n = 1;
% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 5000;
TrialTypes = ones(1,MaxTrials);%ceil(rand(1,MaxTrials)*2)+1;% pseudorandom 2 3; 2 trial types 2 and 3
% TrialTypes (1:4) = [1 2 3 4];
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [425 250 500 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.2 .3 .75 .5]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);
BpodNotebook('init');

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    %random ITI
    min_iti=min(S.GUI.MinITI,S.GUI.MaxITI);
    max_iti=max(S.GUI.MinITI,S.GUI.MaxITI);
    range_iti=max_iti-min_iti;
    current_iti=min_iti+range_iti*rand(1);
    %random ReadyCue duration
    min_readycue=min(S.GUI.ReadyCueDur_min,S.GUI.ReadyCueDur_max);
    max_readycue=max(S.GUI.ReadyCueDur_min,S.GUI.ReadyCueDur_max);
    current_readycue=min_readycue+(max_readycue-min_readycue)*rand(1);
   
    %get current trial type % not useful in phase 1
%     if currentTrial == 1 %first trial
%         TrialTypes(1) = ceil(rand(1)*trialtype_n)+1;% 2 and 3 % 3 types of trials equal prob
% %     else %not first trial
% %         TrialTypes = SelectNextTrial(TrialTypes,BpodSystem.Data);
%     end
    
%     %define states based on trial type
%     switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
% %         case 1 % water
% %             Port = 'PWM2';
% %             readycue_tone = 9; %9 kHz for water 
% %             S.GUI.RewardWaterDur = 0.035;
%         case 2 % suc
%             Port = 'PWM3';
%             readycue_tone = 5; %5 kHz for suc
%             S.GUI.RewardWaterDur = 0.02;
%         case 3 %qui
%             Port = 'PWM4';
%             readycue_tone = 13;
%             S.GUI.RewardWaterDur = 0.04;
%         case 4 % suc catch
%             Port = 'PWM4'; S.GUI.RewardWaterDur = 0.04;%Qui
%             readycue_tone = 5; %5 kHz for suc
%     end
    disp(['current trial:', num2str(TrialTypes(currentTrial))]); 

    
    %start state matrix
    sma = NewStateMatrix(); % Assemble state matrix
    
%     sma = SetGlobalTimer(sma, 1, S.GUI.RespDur); 
    %Arguments: (sma, GlobalTimerNumber, Duration(s))
    % used for signaling the end of response window
    
    sma = addBitcodeStates(sma, currentTrial, 'ITI');
    
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', current_iti,...
        'StateChangeConditions', {'Tup', 'PreCueGate'},...
        'OutputActions', {}); 
    
    %if no lick for gatedur  go to ReadyCue
    sma = AddState(sma, 'Name', 'PreCueGate', ...
        'Timer', S.GUI.PreReadyGate,...
        'StateChangeConditions', {'Tup', 'ReadyCue',Lick, 'GotoPreCueGate'},... 
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'GotoPreCueGate', ...
        'Timer', 0.0005,...
        'StateChangeConditions', {'Tup', 'PreCueGate'},...
        'OutputActions', {});

    sma = AddState(sma, 'Name', 'ReadyCue', ...
        'Timer', current_readycue,...
        'StateChangeConditions', {'Tup', 'ReadyCueTup'},...% , Lick,'PreMature_Puni'
        'OutputActions', {Light, 255}); % ready cue = light  {'Serial1Code', readycue_tone}
    
    sma = AddState(sma, 'Name', 'ReadyCueTup', ...%turn off ReadyCue no need this step
        'Timer', 0.0005,...
        'StateChangeConditions', {'Tup', 'GoCue'},...% let ReadyCue play 
        'OutputActions', {}); % 'Serial1Code', 255

    sma = AddState(sma, 'Name', 'GoCue', ...
        'Timer', S.GUI.GoCueDur,...
        'StateChangeConditions', {'Tup', 'CueTup', Lick, 'Resp'},...% 
        'OutputActions', {'Serial1Code', S.GUI.GoTone}); % turn go cue tone
    
    sma = AddState(sma, 'Name', 'Resp', ...
        'Timer', S.GUI.RewardWaterDur,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {Port, 255, 'Serial1Code', 255}); %turn off go cue
        % give water; keep light on; turn on response window timer
    
    % not used states
    sma = AddState(sma, 'Name', 'Wait4lick', ...
        'Timer', 0,...
        'StateChangeConditions', {Lick, 'Licked','GlobalTimer1_End', 'End_Resp'},...% wait for change
        'OutputActions', {Light, 255}); 
        
    sma = AddState(sma, 'Name', 'Licked', ...
        'Timer', S.GUI.RewardWaterDur,...
        'StateChangeConditions', {'Tup', 'Wait4lick','GlobalTimer1_End', 'End_Resp'},...
        'OutputActions', {Port, 255, Light, 255}); % give water
    
    sma = AddState(sma, 'Name', 'End_Resp', ...% vacuum 0.5 s -> change 1s 2016-5-17 HL
        'Timer', 1,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'Serial1Code', 255, Vacuum, 255});% stop go cue; brief on vacuum to get rid of residual; then exit

    % missed
    sma = AddState(sma, 'Name', 'CueTup', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Miss'},...% Cue time up goto ITI
        'OutputActions', {'Serial1Code', 255}); % stop code
    
    sma = AddState(sma, 'Name', 'Miss', ...
        'Timer', 0.0005,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    
    %premature response -> punishment
    sma = AddState(sma, 'Name', 'PreMature_Puni', ...
        'Timer', 0.0005,...
        'StateChangeConditions', {'Tup', 'Punishementsound'},...%
        'OutputActions', {'Serial1Code', 255 }); % stop tone 
    sma = AddState(sma, 'Name', 'Punishementsound', ...
        'Timer', punishtonedur,...
        'StateChangeConditions', {'Tup', 'TimeOut'},...%
        'OutputActions', {'Serial1Code', punishment_tone}); % play whitenoise
    sma = AddState(sma, 'Name', 'TimeOut', ...
        'Timer', S.GUI.TimeOutDur,...
        'StateChangeConditions', {'Tup', 'exit'},...%
        'OutputActions', {'Serial1Code', 255}); % stop whitenoise     
 
        
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
    % prepare next trial
    % select trial type based on outcome
%     TrialTypes = SelectNextTrial(TrialTypes,BpodSystem.Data);
end
%% 
function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Resp(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Miss(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.PreMature_Puni(1))
        Outcomes(x) = -1; % red circle
    else
        Outcomes(x) = 3;
    end
end
disp(['total trial: ',num2str(length(Outcomes)),...
    '; collected: ',num2str(length(find(Outcomes == 1))),...
    '; preM: ', num2str(length(find(Outcomes == -1))),...
    '; missed: ', num2str(length(find(Outcomes == 0)))]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes)
%% 
function [TrialTypes]= SelectNextTrial(TrialTypes, Data)
% select next trial based on current trial outcome, if preM -> repeat the
% trial
x = Data.nTrials;
% if ~isnan(Data.RawEvents.Trial{x}.States.Resp(1)) % resp or miss onto next trial selection in predefined TrialType
%     Outcomes(x) = 1;
% elseif ~isnan(Data.RawEvents.Trial{x}.States.Miss(1))
%     Outcomes(x) = 0;
if ~isnan(Data.RawEvents.Trial{x}.States.PreMature_Puni(1)) % preM response for the current trial, repeat it
    TrialTypes((x+1):end) = TrialTypes (x:(end-1));
elseif  x < 3 % first 3 trials % 3 trials in a row change it
    TrialTypes(x+1) = ceil(rand(1)*2)+1;% only two choices S or Q, but code use to call taste type keep consistent with three choices
else % check last three trials
    last3trialtypes = TrialTypes(x-2:x);
    C = unique(last3trialtypes);
    if length(C)==1 % same type for 3 consecutive trials = all three are the same => change
        temp_next = ceil(rand(1)*2)+1;
        while temp_next == C %same from last trial
            temp_next = ceil(rand(1)*2)+1;
        end
        TrialTypes(x+1) = temp_next;
    else %rand choose
        TrialTypes(x+1) = ceil(rand(1)*2)+1;  
    
    end
end




