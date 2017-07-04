function ts = generate_ts_semic(session_n, varargin)

% [ts, exp] = generate_ts_semic

semicircular = false;
rng('shuffle');

for i = 1:length(varargin)
    if ischar(varargin{i})
        switch varargin{i}
            % functional commands
            case {'semicircular'}
                semicircular = true;
            case {'linear'}
                semicircular = false;
            case {'data'}
                data = varargin{i+1};
        end
    end
end


switch session_n
    case 1
        
        S1{1} = repmat({'NONE'}, 16, 1);
        S1{2} = repmat({'LV0'}, 16, 1);
        S1{3} = repmat({'0000'}, 16, 1);
        S1{5} = repmat({'3'}, 16, 1);
        S1{6} = repmat({'3', '9'; '5', '7'; '9', '3'}, 6, 1);
        S1{7} = repmat({{'draw_social_cue', [.2, 0, 1]}; {'draw_social_cue', [.4, 0, 1]}; {'draw_social_cue', [.6, 0, 1]}; {'draw_social_cue', [.8, 0, 1]}}, 4, 1);
        
        if semicircular
            S1{4} = repmat({'overall_avoidance_semicircular'}, 16, 1);
        else
            S1{4} = repmat({'overall_avoidance'}, 16, 1); 
        end
        
        trial_n = 16;
        
        for k = 1:numel(S1)
            for run_i = 1
                temp = S1{k}(randperm(trial_n),:);
                switch k
                    case {1, 2, 3, 5}
                        for j = 1:trial_n
                            ts{run_i}{j}(k) = temp(j);
                        end
                    case 4
                        for j = 1:trial_n
                            ts{run_i}{j}(4) = {temp(j)};
                        end
                    case 6
                        for j = 1:trial_n
                            ts{run_i}{j}(6) = temp(j,1);
                            ts{run_i}{j}(7) = temp(j,2);
                        end
                    case 7
                        for j = 1:trial_n
                            ts{run_i}{j}(8) = temp(j);
                        end
                end
            end
        end
        
    case 2
        
        S2{1} = repmat({'PP'}, 12, 1);
        S2{2} = repmat({'LV1'; 'LV2'; 'LV3'}, 4, 1);
        S2{3} = repmat({'0010'}, 12, 1);
        S2{5} = repmat({'0'}, 12, 1);
        S2{6} = repmat({'5', '11'; '7', '9'; '9', '7'; '11', '5'}, 3, 1);
        
        if semicircular
            S2{4} = repmat({'overall_avoidance_semicircular'}, 16, 1);
        else
            S2{4} = repmat({'overall_avoidance'}, 16, 1); 
        end
        
        trial_n = 12;
        
        for k = 1:numel(S2)
            for run_i = 1
                temp = S2{k}(randperm(trial_n),:);
                switch k
                    case {1, 2, 3, 5}
                        for j = 1:trial_n
                            ts{run_i}{j}(k) = temp(j);
                        end
                    case 4
                        for j = 1:trial_n
                            ts{run_i}{j}(4) = {temp(j)};
                        end
                    case 6
                        for j = 1:trial_n
                            ts{run_i}{j}(6) = temp(j,1);
                            ts{run_i}{j}(7) = temp(j,2);
                        end
                end
            end
        end
        
    case 3
        
        for j = 1:4, rating_lv{j} = []; end
        for trial_i = 1:numel(data.dat{1})
            rating_lv{str2double(data.dat{1}{trial_i}.intensity(end))}(end+1) = data.dat{1}{trial_i}.overall_avoidance_rating;
        end
        
        ref_mean = cellfun(@mean, rating_lv)';
        ref_bounds = [ref_mean - mean(diff(ref_mean)) ref_mean + mean(diff(ref_mean))]; % column 1: lower bound, column 2: upper bound

        % linspace
        % standard deviation
        
        for i=1:3   %for each intensity, fill in ref
            average=mean(ref_mean(i));
            ref=linspace(average-mean(diff(ref_mean)), average+mean(diff(ref_mean)),4);
            [A,B]=meshgrid(ref, std);
            ref(16*i-15: 16*i,:)=reshape(cat(2,A',B'),[],2);
        end
        ref=ref(randperm(48),:);
        
end

end