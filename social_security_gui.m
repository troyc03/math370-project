function social_security_gui
%% ============================ GUI WINDOW ============================
f = figure('Name','Social Security Model GUI', ...
           'NumberTitle','off', ...
           'Position',[200 100 1100 600]);

%% =========== PANEL: USER INPUTS ====================================
panel = uipanel(f,'Title','User Inputs','FontSize',12,...
                 'Position',[0.01 0.05 0.28 0.90]);

y = 0.92; dy = 0.045;

% --- ME (YOU) ---
uicontrol(panel,'Style','text','String','Your Birth Year:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.4 0.04]);
me_birthY = uicontrol(panel,'Style','edit','String','1985',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-dy;

uicontrol(panel,'Style','text','String','Birth Month:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.4 0.04]);
me_birthM = uicontrol(panel,'Style','edit','String','9',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-dy;

uicontrol(panel,'Style','text','String','Monthly Income:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.4 0.04]);
me_income = uicontrol(panel,'Style','edit','String','6500',...
    'Units','normalized','Position',[0.50 y 0.4 0.05]); y=y-dy;

uicontrol(panel,'Style','text','String','Claim Age (years):',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.42 0.04]);
me_claimAge = uicontrol(panel,'Style','edit','String','62',...
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

uicontrol(panel,'Style','text','String','Spouse Income:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_income = uicontrol(panel,'Style','edit','String','4200',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-dy;

uicontrol(panel,'Style','text','String','Spouse Claim Age:',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.45 0.04]);
sp_claimAge = uicontrol(panel,'Style','edit','String','67',...
    'Units','normalized','Enable','off','Position',[0.50 y 0.4 0.05]);  y=y-1.1*dy;

% Toggle enabling/disabling spouse input
hasSpouse.Callback = @(src,~) toggle_spouse(src, sp_birthY, sp_income, sp_claimAge);

%% =========== CHILDREN (simplified on/off toggle) =====================
uicontrol(panel,'Style','text','String','Children Enabled?',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.6 0.04]);
hasChildren = uicontrol(panel,'Style','checkbox','Value',0,...
    'Units','normalized','Position',[0.70 y+0.01 0.1 0.05]); 
y = y - 1.5*dy;

% NOTE: To keep GUI clean, children ages are handled in code below.
uicontrol(panel,'Style','text','String','Preset: 2 Children (2015, 2017)',...
    'HorizontalAlignment','left','Units','normalized','Position',[0.05 y 0.90 0.04]);


%% ================= RUN BUTTON =======================================
uicontrol(panel,'Style','pushbutton','String','Run Simulation',...
    'FontWeight','bold','BackgroundColor',[0.1 0.8 0.1],...
    'Units','normalized','Position',[0.15 0.02 0.70 0.06],...
    'Callback', @(~,~) run_simulation());

%% ================= OUTPUT PLOTS (AXES) ===============================
ax1 = axes(f,'Position',[0.33 0.55 0.63 0.40]);
title(ax1,'Monthly Benefit Payments'); grid(ax1,'on');

ax2 = axes(f,'Position',[0.33 0.08 0.63 0.40]);
title(ax2,'Household Lifetime Accumulation'); grid(ax2,'on');

%% ================= CALLBACK FUNCTIONS ================================

    function toggle_spouse(src, y1, y2, y3)
        state = 'off';
        if src.Value == 1
            state = 'on';
        end
        set(y1,'Enable',state);
        set(y2,'Enable',state);
        set(y3,'Enable',state);
    end

    function run_simulation()
        %% --- Build Input Structs ---
        me.birthY = str2double(me_birthY.String);
        me.birthM = str2double(me_birthM.String);
        me.monthlyIncome = str2double(me_income.String);
        me.workStartY = 2008;
        me.workEndY   = 2048;
        me.claimAgeY  = str2double(me_claimAge.String);
        me.deathAgeY  = 90;

        hasSp = hasSpouse.Value;
        sp = struct;
        if hasSp
            sp.birthY = str2double(sp_birthY.String);
            sp.birthM = 3;
            sp.monthlyIncome = str2double(sp_income.String);
            sp.workStartY = 2009;
            sp.workEndY   = 2047;
            sp.claimAgeY  = str2double(sp_claimAge.String);
            sp.deathAgeY  = 90;
        end

        % preset 2 children (can expand)
        hasKids = hasChildren.Value;
        if hasKids
            children(1).birthY = 2015; children(1).birthM = 1;
            children(2).birthY = 2017; children(2).birthM = 6;
        else
            children = [];
        end
        
        %% --- Run model ---
        [months, years, B_me, B_sp, B_kids, B_HH, S_HH] = ...
            untitled_updated_v2(me, hasSp, sp, hasKids, children);

        %% --- PLOT: Monthly Benefit Flows ---
        axes(ax1); cla(ax1);
        hold(ax1,'on');
        plot(ax1, years, B_me, 'LineWidth',2);
        if hasSp
            plot(ax1, years, B_sp, 'LineWidth',2);
        end
        if hasKids
            plot(ax1, years, B_kids, 'LineWidth',2);
        end
        plot(ax1, years, B_HH, 'k','LineWidth',3);
        hold(ax1,'off');
        legend(ax1, composeLegend(hasSp,hasKids),'Location','northwest');
        xlabel(ax1,'Year'); ylabel(ax1,'$/mo');

        %% --- PLOT: Household Accumulation ---
        axes(ax2); cla(ax2);
        plot(ax2, years, S_HH,'LineWidth',2.5);
        xlabel(ax2,'Year'); ylabel(ax2,'Cumulative $');

    end

    function lg = composeLegend(hasSp,hasKids)
        lg = {'Me'};
        if hasSp, lg{end+1}='Spouse'; end
        if hasKids, lg{end+1}='Children'; end
        lg{end+1}='Household';
    end

end
