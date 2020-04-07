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
function Ladder
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
%%
global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.Ladder_Dur = 8;
    S.GUI.Ladder_Spd = 25;% 25% of 255 PWD output
    S.GUI.MinITI = 6; % HL 2018 0310 change to 4-8 3/15 6-8
    S.GUI.MaxITI = 8;
    
end

STOP = 'Port8In'; 
SyncLED = 'PWM8'; SyncDur = 0.1; % 100 ms should be good for sync?
LadderMotor = 'PWM7';

GoTone = 3;% 5khz % HL 20180310 change to 3kHz
GoToneDur = 1; % 1s before wheel starts 

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 5000;
TrialTypes = ones(5000,1);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.[200 200 1000 200]

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [425 250 500 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.2 .3 .75 .5]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);
BpodNotebook('init');

%% Main trial loop
disp('Ladder paradigm: 3kHz tone 25 speed for inital training')
for currentTrial = 1:MaxTrials
    disp(['Trial #: ', num2str(currentTrial)]);
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    %random ITI
    min_iti=min(S.GUI.MinITI,S.GUI.MaxITI);
    max_iti=max(S.GUI.MinITI,S.GUI.MaxITI);
    range_iti=max_iti-min_iti;
    current_iti=min_iti+range_iti*rand(1);
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    sma = addBitcodeStates(sma, currentTrial, 'ITI');
    
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', current_iti,...
        'StateChangeConditions', {'Tup', 'VideoSync'},...
        'OutputActions', {}); 
    
    sma = AddState(sma, 'Name', 'VideoSync', ...
        'Timer', SyncDur,...
        'StateChangeConditions', {'Tup', 'GoCue'},...
        'OutputActions', {SyncLED, 100});
    
    sma = AddState(sma, 'Name', 'GoCue', ...
        'Timer', GoToneDur,...
        'StateChangeConditions', {'Tup', 'LadderOn'},...
        'OutputActions', {'Serial1Code', GoTone});

%         sma = AddState(sma, 'Name', 'GoCue', ...
%         'Timer', GoToneDur,...
%         'StateChangeConditions', {'Tup', 'LadderOn', 'Tup', 'ToneOnMore'},...
%         'OutputActions', {'Serial1Code', GoTone});

    sma = AddState(sma, 'Name', 'LadderOn', ...
        'Timer', S.GUI.Ladder_Dur,...
        'StateChangeConditions', {'Tup', 'exit', STOP, 'LadderOFF'},...
        'OutputActions', {LadderMotor,255*S.GUI.Ladder_Spd/100, 'Serial1Code', 255}); % also stop gocue
    
%         sma = AddState(sma, 'Name', 'ToneOnMore', ...
%         'Timer', S.GUI.Ladder_Dur - GoToneDur,...
%         'StateChangeConditions', { STOP, 'LadderOFF'},...
%         'OutputActions', {'Serial1Code', 255}); % also stop gocue
% need to add in a timer to turn off tone
    sma = AddState(sma, 'Name', 'LadderOFF', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); 
    
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
end

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if isnan(Data.RawEvents.Trial{x}.States.LadderOFF(1))
        Outcomes(x) = 1;% success
%     elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
%         Outcomes(x) = 1;
%     else
%         Outcomes(x) = 1;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes)
