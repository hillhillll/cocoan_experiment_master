function draw_social_cue(m, std, n, rating_type)

global theWindow W H; % window property
global white red orange bgcolor; % color
global window_rect prompt_ex tb bb lb rb scale_H anchor_y anchor_y2 anchor promptW promptH joy_speed; % rating scale

cir_center = [(rb+lb)/2, bb];
radius = (rb-lb)/2; % radius

draw_scale(rating_type);

semicircular = strcmp(overall_types, 'overall_avoidance_semicircular');

if semicircular   	
    
    if n == 1
        th = deg2rad(m * 180); % convert 0-1 values to 0-180 degree
    else
        th = deg2rad(normrnd(m, std, n, 1) * 180); % convert 0-1 values to 0-180 degree
    end
    
    x = radius*cos(th)+cir_center(1);
    y = cir_center(2)-radius*sin(th);
    
    Screen('DrawDots', theWindow, [x y], 7, red, [0 0], 1);  %dif color
    
else
    
    if n == 1
        x = m * (rb-lb) + lb;
    else
        x = (normrnd(m, std, n,1))*(rb-lb) + lb;
    end
        
    Screen('DrawLine', theWindow, red, x, H/2-scale_H, x, H/2+scale_H, 6);
    
end

end