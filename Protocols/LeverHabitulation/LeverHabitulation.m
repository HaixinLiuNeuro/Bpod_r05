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
function LeverHabitulation
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
global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.CueDuration = 2;
%     S.GUI.RewardSoundDuration = 0.5;
    S.GUI.RewardWaterDuration = 0.8;% 3ch spout, take longer to accumulate a drop at the tip. also give water at beginning of the session
%     S.GUI.PunishSoundDuration = 0.5;
    S.GUI.MinITI = 2;
    S.GUI.MaxITI = 4;
end
%[HL] define some variable
cue_tone = 5; %5kHz mouse hearing range 1k - 100kHz 5-15 is good for behavior according to HK
reward_tone = 4;
RewardSoundDuration = 0.5; 
waterport = 'PWM2';
% punish_wt = 250; %white noise
% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 5000;
TrialTypes = ones(5000,1);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.[200 200 1000 200]

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [4 800 500 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
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
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    sma = addBitcodeStates(sma, currentTrial, 'ITI');
    
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', current_iti,...
        'StateChangeConditions', {'Tup', 'Cue'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Cue', ...
        'Timer', S.GUI.CueDuration,...
        'StateChangeConditions', {'Tup', 'CueTup'},...
        'OutputActions', {'Serial1Code', cue_tone}); % play cue: number = kHz
    sma = AddState(sma, 'Name', 'CueTup', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'Miss'},...% Cue time up goto ITI
        'OutputActions', {'Serial1Code', 255}); % stop code
%     sma = AddState(sma, 'Name', 'CuePort1In', ...% press!
%         'Timer', 0,...%         'StateChangeConditions', {'Tup', 'RewardSound'},...
%         'StateChangeConditions', {'Tup', 'Reward'},...
%         'OutputActions', {'Serial1Code', 255}); 
    
    sma = AddState(sma, 'Name', 'Miss', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); 
%     sma = AddState(sma, 'Name', 'PunishTup', ...% deleted punishment sound
%         'Timer', 0,...
%         'StateChangeConditions', {'Tup', 'exit'},...
%         'OutputActions', {'Serial1Code', 255}); 

% change 2016-8-12 first half sec reward sound then reward  
%%%%%%%%%%%old%%%%%%%% 8-13 change back
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', S.GUI.RewardWaterDuration,...
        'StateChangeConditions', {'Tup', 'RewardSoundOff'},...
        'OutputActions', {'Serial1Code', reward_tone, 'PWM2',255});%reward tone 4kHz
    sma = AddState(sma, 'Name', 'RewardSoundOff', ...
        'Timer', max([RewardSoundDuration-S.GUI.RewardWaterDuration 0]),...
        'StateChangeConditions', {'Tup', 'RewardTup'},...
        'OutputActions', {});
%%%%%%%%end of old part
% % add new
%     sma = AddState(sma, 'Name', 'RewardSound', ...
%         'Timer', RewardSoundDuration,...
%         'StateChangeConditions', {'Tup', 'Reward'},...
%         'OutputActions', {'Serial1Code', reward_tone});%reward tone 4kHz
%     sma = AddState(sma, 'Name', 'Reward', ...
%         'Timer', S.GUI.RewardWaterDuration,...
%         'StateChangeConditions', {'Tup', 'RewardTup'},...
%         'OutputActions', {'Serial1Code', 255, waterport,255});%turn off reward tone and open water
    
    
    sma = AddState(sma, 'Name', 'RewardTup', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'Serial1Code', 255}); 
    
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
disp(['total trial: ',num2str(length(Outcomes)),...
    '; correct response: ',num2str(length(find(Outcomes == 1)))]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes)
