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
function FreeLickWater
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

% HL 2016-1-27
% version 2 of lever press task
% no punishment sound (white noise) were given
% reward sound is 1kHz lower than cue sound

% HL 2016-2-15
% modify to open water valve every lick

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
%     S.GUI.CueDuration = 10;
%     S.GUI.RewardSoundDuration = 0.5;
%     S.GUI.RewardWaterDuration = 0.05;
%     S.GUI.PunishSoundDuration = 0.5;
%     S.GUI.MinITI = 8;
%     S.GUI.MaxITI = 12;
      S.GUI.ValveOpenDur = 0.05; % 50ms
      S.GUI.WN_ON = 0;
end
%[HL] define some variable

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 50000;
TrialTypes = ones(MaxTrials,1);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.[200 200 1000 200]

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [425 250 500 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.2 .3 .75 .5]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',TrialTypes);
BpodNotebook('init');

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin

    current_iti = 10; % 10 sec wating every trial
    
    if S.GUI.WN_ON == 0; %no white noise during licking
        sma = NewStateMatrix(); % Assemble state matrix
        
        if currentTrial == 1
            sma = addBitcodeStates(sma, currentTrial, 'ITI'); % 12 bit only for the first trial
        end
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', current_iti,...
            'StateChangeConditions', {'Tup', 'Miss', 'Port3In', 'Reward'},...
            'OutputActions', {'Serial1Code', 255});
        
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', S.GUI.ValveOpenDur,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {'PWM2',255,'Serial1Code', 255}); % open valve
        
        sma = AddState(sma, 'Name', 'Miss', ...
            'Timer', 0.0005,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {}); % open valve
       
    else
        sma = NewStateMatrix(); % Assemble state matrix
        
        if currentTrial == 1
            sma = addBitcodeStates(sma, currentTrial, 'ITI'); % 12 bit only for the first trial
        end
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', current_iti,...
            'StateChangeConditions', {'Tup', 'Miss', 'Port3In', 'Reward'},...
            'OutputActions', {'Serial1Code', 255});
        
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', S.GUI.ValveOpenDur,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {'PWM2',255,'Serial1Code', 250}); % open valve
        
        sma = AddState(sma, 'Name', 'Miss', ...
            'Timer', 0.0005,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {'Serial1Code', 255}); % open valve
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
end

function UpdateOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Miss(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = 3;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes)
