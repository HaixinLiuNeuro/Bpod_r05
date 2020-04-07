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
function Ladder_2
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
%
%% protocol description
% run ladder
% turn ladder on LED 7 for 10 sec if not fall
% stop by experimenter Poke8, mouse click
% ITI 10-15
% 2018-3-10 HL
% two trial types
% 1 tone 3kHz - 25 speed 8s
% 2 tone 9kHz - 35 speed 8s
% tone duration 200ms
% ITI 4-8s
%%
global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.Ladder_Dur = 8;
%     S.GUI.Ladder_Spd = 25;% 25% of 255 PWD output
    S.GUI.MinITI = 4;
    S.GUI.MaxITI = 8;
%     S.GUI.Prob_catch = 0.1; % 10% catch type2 and 10% for catch type 3
end

STOP = 'Port8In'; 
SyncLED = 'PWM8'; SyncDur = 0.1; % 100 ms should be good for sync?
LadderMotor = 'PWM7';

GoToneLo = 3;% 3khz
Ladder_SpdLo = 25;
GoToneHi = 9;% 9k
Ladder_SpdHi = 35;

GoToneDur = 0.25; % 1s before wheel starts

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 1000;
TrialTypes = ones(1,MaxTrials);
for ii = 1:(MaxTrials/20) % 20 trials as a block 2:2:16
% temp = randsample(20,20);
temp = randperm(20);
% temp = rand(1,10)
temp(temp<11) = 2;
temp(temp>10) = 1;
% temp(temp>4) = 1;
TrialTypes ([1:20]+20*(ii-1)) = temp;
end
% TrialTypes (1:5) = [1 1 1 1 3];% no prep trial number assignment is 3

%predefine trial types => make sure enough trial # for each type


BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.[200 200 1000 200]

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [425 250 500 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.2 .3 .75 .5]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);
BpodNotebook('init');

%% Main trial loop
disp('Two ToneSpeed Paradigm Lever_2');
disp('Trial type: 1-Lo 2-Hi')
for currentTrial = 1:MaxTrials
    disp(['Trial #: ', num2str(currentTrial)]);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    %random ITI
    min_iti=min(S.GUI.MinITI,S.GUI.MaxITI);
    max_iti=max(S.GUI.MinITI,S.GUI.MaxITI);
    range_iti=max_iti-min_iti;
    current_iti=min_iti+range_iti*rand(1);
    
    %current trial type
    disp(['current trial type:', num2str(TrialTypes(currentTrial))]);

    sma = NewStateMatrix(); % Assemble state matrix
    
    sma = addBitcodeStates(sma, currentTrial, 'ITI');
    
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', current_iti,...
        'StateChangeConditions', {'Tup', 'VideoSync'},...
        'OutputActions', {}); 
    switch TrialTypes(currentTrial)
        case 1 % Lo
            sma = AddState(sma, 'Name', 'VideoSync', ...
                'Timer', SyncDur,...
                'StateChangeConditions', {'Tup', 'GoCue'},...
                'OutputActions', {SyncLED, 100});
            
            sma = AddState(sma, 'Name', 'GoCue', ...
                'Timer', GoToneDur,...
                'StateChangeConditions', {'Tup', 'LadderOn'},...
                'OutputActions', {'Serial1Code', GoToneLo});
            
            sma = AddState(sma, 'Name', 'LadderOn', ...
                'Timer', S.GUI.Ladder_Dur,...
                'StateChangeConditions', {'Tup', 'exit', STOP, 'LadderOFF'},...
                'OutputActions', {LadderMotor,255*Ladder_SpdLo/100, 'Serial1Code', 255}); % also stop gocue
            
            sma = AddState(sma, 'Name', 'LadderOFF', ...
                'Timer', 0,...
                'StateChangeConditions', {'Tup', 'exit'},...
                'OutputActions', {});
        case 2 % Hi
            sma = AddState(sma, 'Name', 'VideoSync', ...
                'Timer', SyncDur,...
                'StateChangeConditions', {'Tup', 'GoCue'},...
                'OutputActions', {SyncLED, 100});
            
            sma = AddState(sma, 'Name', 'GoCue', ...
                'Timer', GoToneDur,...
                'StateChangeConditions', {'Tup', 'LadderOn'},...
                'OutputActions', {'Serial1Code', GoToneHi});
            
            sma = AddState(sma, 'Name', 'LadderOn', ...
                'Timer', S.GUI.Ladder_Dur,...
                'StateChangeConditions', {'Tup', 'exit', STOP, 'LadderOFF'},...
                'OutputActions', {LadderMotor,255*Ladder_SpdHi/100, 'Serial1Code', 255}); % also stop gocue
            
            sma = AddState(sma, 'Name', 'LadderOFF', ...
                'Timer', 0,...
                'StateChangeConditions', {'Tup', 'exit'},...
                'OutputActions', {});
        otherwise
            error('No such trial type');
    end
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
%     TrialTypes = SelectNextTrial(TrialTypes,BpodSystem.Data, S.GUI.Prob_catch);
end

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.VideoSync(1))% no response needed
        Outcomes(x) = 1;% success
%     elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
%         Outcomes(x) = 1;
%     else
%         Outcomes(x) = 1;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes)
%% 
function [TrialTypes]= SelectNextTrial(TrialTypes, Data, Prob_catch)
% select next trial based on current trial outcome, if preM -> repeat the
% trial
x = Data.nTrials;
% if ~isnan(Data.RawEvents.Trial{x}.States.Resp(1)) % resp or miss onto next trial selection in predefined TrialType
%     Outcomes(x) = 1;
% elseif ~isnan(Data.RawEvents.Trial{x}.States.Miss(1))
%     Outcomes(x) = 0;
% if
%     ~isnan(Data.RawEvents.Trial{x}.States.PreMature_Puni(1)) % preM response for the current trial, repeat it
%     TrialTypes((x+1):end) = TrialTypes (x:(end-1));
% multiple choice
if  x > 3 % start catch trials after 3 trials % first 3 trials % 3 trials in a row change it
    %     TrialTypes(x+1) = ceil(rand(1)*2);% only two choices Go/NoGo%
    % else % check last three trials
    %     last3trialtypes = TrialTypes(x-2:x);
    %     C = unique(last3trialtypes);
    %     if length(C)==1 % same type for 3 consecutive trials = all three are the same => change
    %         temp_next = ceil(rand(1)*2);
    %         while temp_next == C %same from last trial
    %             temp_next = ceil(rand(1)*2);
    %         end
    %         TrialTypes(x+1) = temp_next;
    %     else %rand choose
    %         %Add probability for NoGo trials
    temp = rand(1);
    if temp < Prob_catch
        TrialTypes(x+1) = 2;
    elseif temp < 2*Prob_catch
        TrialTypes(x+1) = 3;
    else
        TrialTypes(x+1) = 1;
    end
    
    
end


