function social_security_gui
% SOCIAL_SECURITY_GUI  Simple GUI wrapper for household Social Security model
%   Usage: run this file (it creates a figure and a "Run Simulation" button)

%% ============== Window & panels ====================================
f = figure('Name','Social Security Model GUI', ...
           'NumberTitle','off', ...
           'Position',[200 100 1100 600]);

panel = uipanel(f,'Title','User Inputs','FontSize',12,...
                 'Position',[0.01 0.05 0.28 0.90]);

y = 0.92; dy = 0.045;

% --- ME (YOU) ---
uicontrol(panel,'Style','text','String','Your Birth Year:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.4 0.04]);
me_birthY = uicontrol(panel,'Style','edit','String','1985',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-dy;

uicontrol(panel,'Style','text','String','Birth Month (1-12):',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.4 0.04]);
me_birthM = uicontrol(panel,'Style','edit','String','9',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-dy;

uicontrol(panel,'Style','text','String','Monthly Income ($):',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.4 0.04]);
me_income = uicontrol(panel,'Style','edit','String','6500',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-dy;

uicontrol(panel,'Style','text','String','Claim Age (years):',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.42 0.04]);
me_claimAge = uicontrol(panel,'Style','edit','String','62',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-1.2*dy;

% --- Defaults for death age (can be adjusted later in model) ---
uicontrol(panel,'Style','text','String','Planned Death Age (years):',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.42 0.04]);
me_deathAge = uicontrol(panel,'Style','edit','String','90',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-1.2*dy;

%% =========== SPOUSE OPTIONS ==========================================
uicontrol(panel,'Style','text','String','Spouse Enabled?',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.55 0.04]);
hasSpouse = uicontrol(panel,'Style','checkbox','Value',0,...
    'Units','normalized','Position',[0.70 y+0.01 0.1 0.04]); 
y = y - dy;

uicontrol(panel,'Style','text','String','Spouse Birth Year:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_birthY = uicontrol(panel,'Style','edit','String','1986',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-dy;

uicontrol(panel,'Style','text','String','Spouse Birth Month:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_birthM = uicontrol(panel,'Style','edit','String','3',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-dy;

uicontrol(panel,'Style','text','String','Spouse Income ($):',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_income = uicontrol(panel,'Style','edit','String','4200',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-dy;

uicontrol(panel,'Style','text','String','Spouse Claim Age:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_claimAge = uicontrol(panel,'Style','edit','String','67',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-1.1*dy;

uicontrol(panel,'Style','text','String','Spouse Death Age:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_deathAge = uicontrol(panel,'Style','edit','String','90',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-1.3*dy;

% Toggle enabling/disabling spouse input
hasSpouse.Callback = @(src,~) toggle_spouse(src, sp_birthY, sp_birthM, sp_income, sp_claimAge, sp_deathAge);

%% =========== CHILDREN (simplified on/off toggle) =====================
uicontrol(panel,'Style','text','String','Children Enabled?',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.6 0.04]);
hasChildren = uicontrol(panel,'Style','checkbox','Value',0,...
    'Units','normalized','Position',[0.70 y+0.01 0.1 0.05]); 
y = y - 1.5*dy;

uicontrol(panel,'Style','text','String','Preset: 2 Children (2015, 2017)',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.90 0.04]);

%% ================= RUN BUTTON =======================================
uicontrol(panel,'Style','pushbutton','String','Run Simulation',...
    'FontWeight','bold','BackgroundColor',[0.1 0.8 0.1],...
    'Units','normalized','Position',[0.15 0.02 0.70 0.06],...
    'Callback', @(~,~) run_simulation());

%% ================= OUTPUT PLOTS (AXES) ================================
ax1 = axes(f,'Position',[0.33 0.55 0.63 0.40]);
title(ax1,'Monthly Benefit Payments'); grid(ax1,'on');

ax2 = axes(f,'Position',[0.33 0.08 0.63 0.40]);
title(ax2,'Household Lifetime Accumulation'); grid(ax2,'on');

%% ================ CALLBACKS & HELPERS ================================
    function toggle_spouse(src, y1, y2, y3, y4, y5)
        state = 'off';
        if src.Value == 1
            state = 'on';
        end
        set(y1,'Enable',state);
        set(y2,'Enable',state);
        set(y3,'Enable',state);
        set(y4,'Enable',state);
        set(y5,'Enable',state);
    end

    function run_simulation()
        % --- Read & sanitize ME inputs ---
        me.birthY = safeStr2double(me_birthY.String, 1985);
        me.birthM = safeStr2double(me_birthM.String, 9);
        me.monthlyIncome = safeStr2double(me_income.String, 6500);
        me.claimAgeY = safeStr2double(me_claimAge.String, 62);
        me.deathAgeY = safeStr2double(me_deathAge.String, 90);

        % --- Spouse (may be empty) ---
        if hasSpouse.Value
            sp = struct();
            sp.birthY = safeStr2double(sp_birthY.String, 1986);
            sp.birthM = safeStr2double(sp_birthM.String, 3);
            sp.monthlyIncome = safeStr2double(sp_income.String, 4200);
            sp.claimAgeY = safeStr2double(sp_claimAge.String, 67);
            sp.deathAgeY = safeStr2double(sp_deathAge.String, 90);
            hasSp = 1;
        else
            sp = [];
            hasSp = 0;
        end

        % --- Children preset (simple) ---
        if hasChildren.Value
            children = struct( ...
                'birthY', {2015, 2017}, ...
                'birthM', {1, 6} ...
            );
            hasKids = 1;
        else
            children = [];
            hasKids = 0;
        end

        % --- Call model (robust) ---
        try
            [months, years, B_me, B_sp, B_kids, B_HH, S_HH] = ...
                untitled_updated_v2(me, hasSp, sp, hasKids, children);
        catch ME
            errordlg(['Model error: ' ME.message],'Model Error');
            rethrow(ME);
        end

        % --- Plot: Monthly Benefit Flows ---
        axes(ax1); cla(ax1);
        hold(ax1,'on');
        plot(ax1, years, B_me, 'LineWidth',2);
        if hasSp && any(B_sp)
            plot(ax1, years, B_sp, 'LineWidth',2);
        end
        if hasKids && any(B_kids)
            plot(ax1, years, B_kids, 'LineWidth',2);
        end
        plot(ax1, years, B_HH, 'k','LineWidth',3);
        hold(ax1,'off');
        legend(ax1, composeLegend(hasSp,hasKids),'Location','northwest');
        xlabel(ax1,'Year'); ylabel(ax1,'$/mo');
        grid on;

        % --- Plot: Household Accumulation ---
        axes(ax2); cla(ax2);
        plot(ax2, years, S_HH,'LineWidth',2.5);
        xlabel(ax2,'Year'); ylabel(ax2,'Cumulative $');
        grid on;
    end

    function lg = composeLegend(hasSp,hasKids)
        lg = {'Me'};
        if hasSp, lg{end+1}='Spouse'; end
        if hasKids, lg{end+1}='Children'; end
        lg{end+1}='Household';
    end

    function v = safeStr2double(str, defaultVal)
        % Converts string to double, returns default if NaN or blank
        v = str2double(str);
        if isempty(strtrim(str)) || isnan(v)
            v = defaultVal;
        end
    end

end
