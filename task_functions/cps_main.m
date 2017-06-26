function data = cps_main(trial_sequence, varargin)

% This function is for controlling the LabView program to deliver pressure
% pain and collecting ratings (continuous or one-time ratings)
%
% Usage:
% -------------------------------------------------------------------------
% data = pressure_test(trial_sequence, varargin)
%
% Inputs:
% -------------------------------------------------------------------------
% trial_sequence trial_sequence should provide information of intensity,
%                duration, repetition of simulation, rating and scale type 
%                you want to use, and cue/iti duration. 
%
% The generic form of trial sequence:
% trial_sequence{run_number}{trial_number} = ...
%          {intensity(four digits:string), duration(four digits:string),
%           repetition_number, rating_scale_type, cue_duration,
%           post-stim jitter, inter_stim_interval (from the rating to the 
%           next trial), cue_message, during_stim_message};
% For details, see example below.
%
% Optional input:
% -------------------------------------------------------------------------
% 'post_st_rating_dur'  If you are collecting continuous rating, using this 
%                       option, you can specify the duration for the 
%                       post-stimulus rating. The default is 5 seconds.
%                       (e.g., 'post_st_rating_dur', duration_in_seconds)
% 'explain_scale'       If you want to show rating scale before starting
%                       the experiment, you can use this option.
%                       (e.g., 'explain_scale', {'overall_avoidance', 'overall_int'})
% 'test'                running a testmode with partial-screen
% 'scriptdir'           specify the script directory
% 'psychtoolbox'        specify the psychtoolbox directory
% 'fmri'                display some instructions for a fmri experiment
%
% Outputs:
% -------------------------------------------------------------------------
% data.
%
%
%
%
% Example:
% -------------------------------------------------------------------------
% trial_sequence{1}{1} = {'PP', 'LV1', '0010', {'overall_avoidance'}, '0', '3', '7'};
%     ----------------------------
%     {1}{1}: first run, first trial
%     'PP'  : pressure pain
%         -- other options --
%         'TP': thermal pain
%         'PP': thermal pain
%         'AU': aversive sounds
%         'VI': aversive visual
%         ** you can add more stimuli options...
%     'LV1'-'LV4' : intensity levels
%     '0010': duration in seconds (10 seconds)
%     {'overall_avoidance'}: overall avoidance rating (after stimulation ends)
%         -- other options --
%         'no'              : no ratings
%         'cont_int'        : continuous intensity rating
%         'cont_avoidance'  : continuous rating
%         'overall_int'     : overall intensity rating 
%         'overall_unpleasant' : overall intensity rating 
%         'overall_avoidance'  : overall avoidance rating 
%         ** to add more combinations, see "parse_trial_sequence.m" and "draw_scale.m" **
%     '0': cue duration 0 seconds: no cue
%     '3': interval between stimulation and ratings: 3 seconds
%     '7': inter_stim_interval: This defines the interval from the time the rating starts
%          to the next trial starts. Actual ITI will be this number minus RT.
%     ** optional: Using 8th cell array, you can specify cue text
%                  Using 9th cell array, you can specify text during stimulation
%
% trial_sequence{1}{2} = {'AU', 'LV2', '0010', {'overall_int'}, '0', '3', '7', 'How much pressure?'};
%     'How much pressure?' - will be appeared as cue. If the 8th cell is not 
%                            specified, it will display a fixation cross.
%
% trial_sequence{1}{3} = {'TP', 'LV4', '0010', {'overall_pleasant'}, '0', '3', '7'};
% 
% data = mpa1_main(trial_sequence, 'explain_scale', exp_instructions, 'fmri', 'biopac')
%
% -------------------------------------------------------------------------
% Copyright (C) 1/10/2015, Wani Woo
%
% Programmer's note:
% 10/19/2015, Wani Woo -- modified the original code for MPA1


%% SETUP: global
global theWindow W H; % window property
global white red orange bgcolor; % color
global t r; % pressure device udp channel
global window_rect prompt_ex lb rb scale_W anchor_y anchor_y2 anchor promptW promptH joy_speed; % rating scale

%% Parse varargin
post_stimulus_t = 5; % post-stimulus continuous rating seconds
doexplain_scale = false;
testmode = false;
dofmri = false;
USE_BIOPAC = false;
joy_speed = .8; % should be between 0.1 and .95(?) or 1, higher = slower

% need to be specified differently for different computers
%psytool = 'C:\toolbox\Psychtoolbox';
scriptdir = 'C:\Users\cnir\Documents\...';
% io32dir = 'C:\Program Files\MATLAB\R2012b\toolbox\io32';
io64dir = 'C:\...'; % need to edit
savedir = 'CPS_data';

for i = 1:length(varargin)
    if ischar(varargin{i})
        switch varargin{i}
            % functional commands
            case {'post_st_rating_dur', 'post_st_rating'}
                post_stimulus_t = varargin{i+1};
            case {'explain_scale'}
                doexplain_scale = true;
                exp_scale.inst = varargin{i+1};
            case {'test'}
                testmode = true;
            case {'scriptdir'}
                scriptdir = varargin{i+1};
            case {'psychtoolbox'}
                psytool = varargin{i+1};
            case {'fmri'}
                dofmri = true;
            case {'biopac'}
                USE_BIOPAC = true;
        end
    end
end

addpath(scriptdir); cd(scriptdir);
% addpath(genpath(psytool));

%% SETUP: BIOPAC
if USE_BIOPAC
    trigger_biopac = biopac_setting_io64(io64dir);
    BIOPAC_PULSE_WIDTH = 1;
end

%% SETUP: Screen
if exist('data', 'var'), clear data; end

bgcolor = 100;

if testmode
    window_num = 0;
    window_rect = [1 1 1024 500]; % in the test mode, use a little smaller screen
else
    screens = Screen('Screens');
    window_num = screens(end); % the last window
    window_info = Screen('Resolution', window_num); 
    window_rect = [0 0 window_info.width window_info.height]; % full screen
%     window_rect = [0 0 1024 768];
end

W = window_rect(3); %width of screen
H = window_rect(4); %height of screen
font = 'Helvetica';
fontsize = 33;
white = 255;
red = [158 1 66];
orange = [255 164 0];

% rating scale left and right bounds 1/4 and 3/4
lb = W/4; 
rb = (3*W)/4;

% Height of the scale (10% of the width; sorry for the poor naming)
scale_W = (rb-lb).*0.1;
anchor = [0.014 0.061 0.172 0.354 0.533].*(rb-lb)+lb;
% scale_name = {'line', 'linear', 'LMS'};


%% SETUP: instructions for each type of ratings
prompt_ex = prompt_setup;

%% SETUP: DATA and Subject INFO
[fname, start_line, SID] = subjectinfo_check(savedir); % subfunction
if exist(fname, 'file'), load(fname, 'data'); end

% save data using the canlab_dataset object
data.version = 'CPS_v1_06-02-2017_Cocoanlab';
data.subject = SID;
data.datafile = fname;
data.starttime = datestr(clock, 0); % date-time
data.starttime_getsecs = GetSecs; % in the same format of timestamps for each trial

% initial save of trial sequence
save(data.datafile, 'trial_sequence', 'data');

%% SETUP: Experiment
[run_num, trial_num, runstart, trial_starts, rating_types] = parse_trial_sequence(trial_sequence, start_line);
lvs = {'LV1', 'LV2', 'LV3', 'LV4'}; % you can add more..

%% SETUP: STIMULI -- modify this for each study
PP_int = pressure_pain_setup; % see subfunctions
players = auditory_setup;

%% START

try
    % START: Screen
    % whichScreen = max(Screen('Screens'));
	theWindow = Screen('OpenWindow', window_num, bgcolor, window_rect); % start the screen
    HideCursor;
    Screen('TextFont', theWindow, font); % setting font
    Screen('TextSize', theWindow, fontsize);
    
    % pretend to draw text in black and return new pen location -
    % - a trick to get display width and height
    [fixW, fixH] = Screen(theWindow,'DrawText','+',0,0); 
    % W and H for instructions
    for i = 1:numel(rating_types.prompts)
        promptW{i} = Screen(theWindow, 'DrawText',rating_types.prompts{i},0,0);
    end
    promptH = 50;
    
    % y location for anchors of rating scales -
    % - anchor_y: first line, anchor_y2: second line
    anchor_y = H/2+10+scale_W;
    anchor_y2 = H/2+10+scale_W+25;
    
    % 3. EXPLAIN SCALES
    if doexplain_scale
        explain_scale(exp_scale, rating_types);
    end
    
    % 4. START: RUN
    for run_i = runstart:run_num % run starts
        
        for tr_i = trial_starts(run_i):trial_num(run_i) % trial starts
            
            if run_i == 1 && tr_i == 1
                while (1)
                    [~,~,keyCode] = KbCheck;
                    if keyCode(KbName('space'))==1
                        break
                    elseif keyCode(KbName('q'))==1
                        abort_man;
                    end 
                    display_expmessage; % until space; see subfunctions
                end
            end
            
            if tr_i == 1 % first trial
                while (1)
                    [~,~,keyCode] = KbCheck;
                    
                    % if this is for fMRI experiment, it will start with 5,
                    % but if behavioral, it will start with "r" key. 
                    if dofmri
                        if keyCode(KbName('s'))==1
                            break
                        elseif keyCode(KbName('q'))==1
                            abort_man;
                        end
                    else
                        if keyCode(KbName('r'))==1
                            break
                        elseif keyCode(KbName('q'))==1
                            abort_man;
                        end
                    end
                    display_runmessage(run_i, run_num, dofmri); % until 5 or r; see subfunctions
                end
                
                if dofmri
                    % gap between 5 key push and the first stimuli (disdaqs: 10 seconds)
                    % 5 seconds: "Starting..."
                    [stimtext_W, stimtext_H] = Screen(theWindow,'DrawText','Starting...',0,0);
                    Screen(theWindow, 'FillRect', bgcolor, window_rect);
                    Screen(theWindow, 'DrawText', 'Starting...', W/2-stimtext_W/2, H/2-stimtext_H/2,255);
                    Screen('Flip', theWindow);
                    WaitSecs(4);
                    
                    % 5 seconds: Blank
                    Screen(theWindow,'FillRect',bgcolor, window_rect);
                    Screen('Flip', theWindow);
                    data.dat{run_i}{tr_i}.runscan_starttime = GetSecs;
                    WaitSecs(4); % ADJUST THIS
                end
                
                % 1 seconds: BIOPAC
                if USE_BIOPAC
                    data.dat{run_i}{tr_i}.biopac_triggertime = GetSecs;
                    feval(trigger_biopac,BIOPAC_PULSE_WIDTH); 
                end
                
                Screen(theWindow,'FillRect',bgcolor, window_rect);
                Screen('Flip', theWindow);
                WaitSecs(2); % ADJUST THIS
                
            end
            
            % HERE: CUE or FIXATION CROSS --------------------------------
            cue_t = str2double(trial_sequence{run_i}{tr_i}{5});
            data.dat{run_i}{tr_i}.cue_timestamp = GetSecs;
            %if USE_BIOPAC, feval(trigger_biopac,BIOPAC_PULSE_WIDTH); end
            if cue_t > 0 % if cue_t == 0, this is not running.
                try
                    if ~isempty(trial_sequence{run_i}{tr_i}{8})
                        stimtext = trial_sequence{run_i}{tr_i}{8};
                        [stimtext_W, stimtext_H] = Screen(theWindow,'DrawText',stimtext,0,0);
                    else
                        stimtext = '+';
                        stimtext_W = fixW;
                        stimtext_H = fixH;
                    end
                catch
                    stimtext = '+';
                    stimtext_W = fixW;
                    stimtext_H = fixH;
                end
                
                Screen(theWindow,'FillRect',bgcolor, window_rect);
                Screen(theWindow,'DrawText',stimtext, W/2-stimtext_W/2, H/2-stimtext_H/2,255);
                Screen('Flip', theWindow);
                WaitSecs(cue_t-.5);
                
                % 0.5 sec with blank
                Screen(theWindow,'FillRect',bgcolor, window_rect);
                Screen('Flip', theWindow);
                WaitSecs(.5);
            end
            
            % SETUP: Trial stimulus
            [type, int, dur, data] = parse_trial(data, trial_sequence, run_i, tr_i);
            
            % START: Trial
            % HERE: picture or other texts can be added
            try
                stimtext = trial_sequence{run_i}{tr_i}{9};
                [stimtext_W, stimtext_H] = Screen(theWindow,'DrawText',stimtext,0,0); 
            catch
                stimtext = '+';
                stimtext_W = fixW;
                stimtext_H = fixH;
            end
            
            Screen(theWindow,'FillRect', bgcolor, window_rect); % Fixation cross disappear
            Screen(theWindow,'DrawText', stimtext, W/2-stimtext_W/2, H/2-stimtext_H/2, 255);
            Screen('Flip', theWindow);
            
            % For continuous rating, show rating instruction before stimulus starts
            % This will add one second to the ITI.. I changed into 0s again.
            if ~isempty(rating_types.docont{run_i}{tr_i})
                cont_types = rating_types.docont{run_i}{tr_i}{1};
                eval(['data.dat{run_i}{tr_i}.' cont_types '_timestamp = GetSecs;']);
                show_cont_prompt(cont_types, rating_types);
                Screen('Flip', theWindow);
                % WaitSecs(1);
            end
            
            % RECORD: Time stamp
            SetMouse(0,0);
            data.dat{run_i}{tr_i}.stim_timestamp = GetSecs;
            
            % HERE: STIMULATION ------------------------------------------
            if strcmp(type, 'PP') % pressure pain
                eval(['fwrite(t, ''1,' PP_int{strcmp(lvs, int)} ',t'');']);
            elseif strcmp(type, 'AU') % aversive auditory
                play(players{strcmp(lvs, int)});
            % elseif strcmp(type, 'TP')
            % elseif strcmp(type, 'VI')
            end
            
            start_t = GetSecs; 

            % commented out for now
%             if strcmp(type, 'PP')
%                 message_1 = deblank(fscanf(r));
%                 if strcmp(message_1,'Read Error')
%                     error(message_1);
%                 else
%                     data.dat{run_i}{tr_i}.logfile = message_1;
%                 end
%             end
            
            rec_i = 0;
            
            % CONTINUOUS RATING
            if ~isempty(rating_types.docont{run_i}{tr_i})
                
                [joy_pos, joy_button] = mat_joy(0);
                start_joy_pos = joy_pos(1);
                % SetMouse(lb,H/2); % set mouse at the left; we're
                %                   % currently using joystick instead.
                
                % START: Instruction and rating scale
                deltat = 0;
                while deltat <= (str2double(dur)+post_stimulus_t) % collect data for the duration+post_stimulus_t
                    deltat = GetSecs - start_t; 
                    rec_i = rec_i+1; % the number of recordings
                    
                    % Track Mouse coordinate
                    % x = GetMouse(theWindow);
                    
                    % Track joystick coordinate
                    [joy_pos, joy_button] = mat_joy(0);
                    x = (joy_pos(1)-start_joy_pos) ./ joy_speed .* (rb-lb) + lb; % only right direction
                    % x = (joy_pos(1)-start_joy_pos) ./ joy_speed .* (rb-lb) + (rb+lb)/2; % both direction
                    
                    if x < lb, x = lb;
                    elseif x > rb, x = rb;
                    end
                    
                    cur_t = GetSecs;
                    data.dat{run_i}{tr_i}.time_from_start(rec_i,1) = cur_t-start_t;
                    data.dat{run_i}{tr_i}.cont_rating(rec_i,1) = (x-lb)./(rb-lb);
                    
                    show_cont_prompt(cont_types, rating_types);
                    Screen('DrawLine', theWindow, white, x, H/2, x, H/2+scale_W, 6);
                    Screen('Flip', theWindow);
                end
            else
                WaitSecs(str2double(dur));
                if strcmp(type, 'PP')
                    eval(['fwrite(t, ''1,' PP_int{strcmp(lvs, int)} ',s'');']);
                end
            end

            % commented out for now
%             if strcmp(type, 'PP')
%                 message_2 = deblank(fscanf(r));
%                 if ~strcmp(message_2, 's')
%                     disp(message_2);
%                     error('message_2 is not s.');
%                 end % make sure if the stimulus ends
%             end
            
            end_t = GetSecs;
            data.dat{run_i}{tr_i}.total_dur_recorded = end_t - start_t;
            
            % POST-STIM JITTER
            Screen('FillRect', theWindow, bgcolor, window_rect); % clear the screen
            Screen('Flip', theWindow);
            post_stim_jitter = str2double(trial_sequence{run_i}{tr_i}{6});
            data.dat{run_i}{tr_i}.post_stim_jitter = post_stim_jitter;
            WaitSecs(post_stim_jitter);
            
            % OVERALL RATINGS
            data.dat{run_i}{tr_i}.overall_rating_timestamp = GetSecs;
            
            if ~isempty(rating_types.dooverall{run_i}{tr_i})
                for overall_i = 1:numel(rating_types.dooverall{run_i}{tr_i})
                    overall_types = rating_types.dooverall{run_i}{tr_i}{overall_i};
                    eval(['data.dat{run_i}{tr_i}.' overall_types '_timestamp = GetSecs;']);
                    data = get_overallratings_joystick(overall_types, data, rating_types, run_i, tr_i);
                end
            end
            
            data.dat{run_i}{tr_i}.overall_RT = GetSecs - data.dat{run_i}{tr_i}.overall_rating_timestamp;
            
            % INTER-TRIAL INTERVAL
            Screen('FillRect', theWindow, bgcolor, window_rect); % basically, clear the screen
            Screen('Flip', theWindow);
            data.dat{run_i}{tr_i}.isi = str2double(trial_sequence{run_i}{tr_i}{7});
            data.dat{run_i}{tr_i}.iti = data.dat{run_i}{tr_i}.isi - data.dat{run_i}{tr_i}.overall_RT;
            if data.dat{run_i}{tr_i}.iti <= 0
                data.dat{run_i}{tr_i}.iti = 0.01;
            end
            WaitSecs(data.dat{run_i}{tr_i}.iti); % if the next is continuous rating, it should remove one second
            
            if mod(tr_i,2) == 0, save(data.datafile, '-append', 'data'); end % save data every two trials
            
            SetMouse(0,0);
        end % trial ends
        
        % save data between runs
        save(data.datafile,'-append', 'data');
        
        % message between runs
        while (1) 
            [~,~,keyCode] = KbCheck;
            if keyCode(KbName('space'))==1
                break
            elseif keyCode(KbName('q'))==1
                abort_man;
            end
            
            display_runending_message(run_i, run_num, dofmri);
        end
        
    end % run ends
    
    if exist('t', 'var') || exist('r', 'var')
        fclose(t);
        fclose(r);
    end
    
    Screen('CloseAll');
    disp('Done');
    save(data.datafile, '-append', 'data');
    
catch err
    % ERROR 
    disp(err);
    disp(err.stack(end));
    fclose(t);
    fclose(r);
    abort_error; 
end

end

%% SUBFUNCTIONS ----------------------------------------------------------

function display_expmessage

% MESSAGE FOR CHECKING SETTING BEFORE STARTING EXPERIMENT

global theWindow W H; % window property
global white red orange bgcolor; % color
global t r; % pressure device udp channel
global window_rect prompt_ex lb rb scale_W anchor_y anchor_y2 anchor promptW promptH; % rating scale

EXP_start_text{1} = 'Experimenter, please check everything is correctly set (biopac, ppd, etc.)';
EXP_start_text{2} = 'when ready, please press SPACE.';

for jj = 1:numel(EXP_start_text)
    exptextW{jj} = Screen('DrawText',theWindow,EXP_start_text{jj},0,0);
end

% display
Screen(theWindow,'FillRect',bgcolor, window_rect);
for jj = 1:numel(EXP_start_text)
    Screen('DrawText',theWindow,EXP_start_text{jj},W/2-exptextW{jj}/2,H/2+promptH*(jj-1)-150,white);
end
Screen('Flip', theWindow);
end


function display_runmessage(run_i, run_num, dofmri)

% MESSAGE FOR EACH RUN

% HERE: YOU CAN ADD MESSAGES FOR EACH RUN
%       You can use two lines of message. For now, I'm using one line.

global theWindow W H; % window property
global white red orange bgcolor; % color
global t r; % pressure device udp channel
global window_rect prompt_ex lb rb scale_W anchor_y anchor_y2 anchor promptW promptH; % rating scale

if dofmri
    if run_i <= run_num % 5
        Run_start_text{1} = 'If the participant is ready for the run, start scanning (5).';
        Run_start_text{2} = ' ';
    end
else
    if run_i <= run_num
        Run_start_text{1} = 'If the participant is ready for the run, please press r.';
        Run_start_text{2} = ' ';
    end
end

% runtextW: the max width for two lines of message
for jj = 1:numel(Run_start_text)
    runtextW{jj} = Screen('DrawText',theWindow,Run_start_text{jj},0,0);
end

% display
Screen(theWindow,'FillRect',bgcolor, window_rect);
for jj = 1:numel(Run_start_text)
    Screen('DrawText',theWindow,Run_start_text{jj},W/2-runtextW{jj}/2,H/2+promptH*(jj-1)-150,white);
end
Screen('Flip', theWindow);

end

function display_runending_message(run_i, run_num, dofmri)

global theWindow W H; % window property
global white red orange bgcolor; % color
global t r; % pressure device udp channel
global window_rect prompt_ex lb rb scale_W anchor_y anchor_y2 anchor promptW promptH; % rating scale

% MESSAGE FOR EACH RUN

% HERE: YOU CAN ADD MESSAGES FOR EACH RUN
%       You can use two lines of message. For now, I'm using one line.
clear Run_end_text;
if run_i < run_num
    Run_end_text{1} = ['This is the end of the run ' num2str(run_i) '.'];
    Run_end_text{2} = 'If the participant is ready for the next run, please press Space.';
else
    Run_end_text{1} = 'This is the end of this session.';
    Run_end_text{2} = 'To finish this session, please press Space.';
end

if dofmri
    Run_end_text{1} = ['Experimenter: ' Run_end_text{1}];
end
    
for jj = 1:numel(Run_end_text)
    runtextW{jj} = Screen('DrawText',theWindow,Run_end_text{jj},0,0);
end
Screen(theWindow,'FillRect',bgcolor, window_rect);

for jj = 1:numel(Run_end_text)
    Screen('DrawText',theWindow,Run_end_text{jj},W/2-runtextW{jj}/2,H/2+promptH*(jj-1)-200,white);
end
Screen('Flip', theWindow);
end


function [type, int, dur, data] = parse_trial(data, trial_sequence, run_i, tr_i)

% parse each trial

type = trial_sequence{run_i}{tr_i}{1}; % 'PP', 'TP', 'AU', 'VI'
int = trial_sequence{run_i}{tr_i}{2};  % 'LV1', 'LV2'...
dur = trial_sequence{run_i}{tr_i}{3};  % '0010'...

% RECORD: Trial Info
data.dat{run_i}{tr_i}.type = type;
data.dat{run_i}{tr_i}.intensity = int;
data.dat{run_i}{tr_i}.duration = str2double(dur);
data.dat{run_i}{tr_i}.scale = trial_sequence{run_i}{tr_i}{4};

end

function PP_int = pressure_pain_setup

% pressure_pain_setup

global t r; % pressure device udp channel

PP_int = {'0004', '0005', '0006', '0007'}; % kg/cm2
delete(instrfindall); %clear out old channels

try
    t=udp('localhost',61557); % open udp channels
    r=udp('localhost',61158,'localport', 61556);
    
    fopen(t);
    fopen(r);
    fwrite(t, '0005,o'); % open the remote channel
catch err
    % ERROR
    disp(err);
    disp(err.stack(1));
    disp(err.stack(2));
    disp(err.stack(end));
    fclose(t);
    fclose(r);
    abort_error;
end
end

function players = auditory_setup

% auditory_setup

% fnames = filenames('knife_on_bottle_LV*');
fnames = {'knife_on_bottle_LV1_-3dball_-8db2000Hz.wav',...
    'knife_on_bottle_LV2_-3dball_-4db2000Hz.wav',...
    'knife_on_bottle_LV3_-3dball_-1db2000Hz.wav',...
    'knife_on_bottle_LV4.wav'};

for i = 1:4
    try
        y = audioread(fnames{i});
    catch
        y = wavread(fnames{i});
    end
    players{i} = audioplayer(y, 44100);
end

end

function show_cont_prompt(cont_types, rating_types)

global theWindow W H; % window property
global white red orange bgcolor; % color
global t r; % pressure device udp channel
global window_rect prompt_ex lb rb scale_W anchor_y anchor_y2 anchor promptW promptH; % rating scale

i = strcmp(rating_types.alltypes, cont_types);
Screen('DrawText', theWindow, rating_types.prompts{i}, W/2-promptW{i}/2,H/2-promptH/2-150,orange);
draw_scale(cont_types);

end

function prompt_ex = prompt_setup

% prompt = prompt_setup

%% Instructions
prompt_ex{1} = 'Scale example: Experimenter will explain how to use the scale, and press Space.';
prompt_ex{2} = 'Scale example: Please practice rating, and when you are done, please press a button.';
prompt_ex{3} = 'Great job! If you are ready for the next step, please press a button.';

%% some additional instructions
prompt_ex{4} = 'Welcome! The experiment will start with an explanation of the rating scales.';
prompt_ex{5} = 'When you are ready, please press any button.';
prompt_ex{6} = 'Note that during the actual experiment, you don''t need to press a button for the continuous rating.';
prompt_ex{7} = 'Great! We''re done with the practice. Now, we are about to start the actual experiment.';
prompt_ex{8} = 'If you are ready for the next part, please press a button.';

end
