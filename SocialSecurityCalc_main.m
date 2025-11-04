%% Social Security Difference-Equation Model (Monthly)
% Discrete-time (month) system:
% PIA_{t+1} = PIA_t * (1 + c_t)
% B_{t+1}^p = I_{t+1}^p * phi^p * PIA_{t+1}^p * (1 + xi^{p<-q}) * omega_t^p
% B_{t+1}^{kids} = lambda_t * 0.5 * K_t * max(PIA_{t+1}^ind, PIA_{t+1}^sp)
% S_{t+1}^{HH} = S_t^{HH} + B_{t+1}^{HH}
clear; clc; close all;

%% =================== USER INPUTS ===================
% Individual (you)
me.birthY = 1985; me.birthM = 9;
me.monthlyIncome = 6500;        % covered earnings ($/mo)
me.workStartY = 2008; me.workEndY = 2048;
me.claimAgeY = 67;              % you claim at this age (years)
me.deathAgeY = 90;              % optional; set [] for open-ended

% Spouse (toggle)
hasSpouse = true;
sp.birthY = 1986; sp.birthM = 3;
sp.monthlyIncome = 4200;
sp.workStartY = 2009; sp.workEndY = 2047;
sp.claimAgeY = 67;
sp.deathAgeY = 90;

% Children (toggle)
hasChildren = true;
children = [ struct('birthY',2015,'birthM',7), ...
             struct('birthY',2018,'birthM',11) ];

% Simulation
simEndAgeY = 100;              % simulate to this age
applyEarningsTest = false;     % simple on/off
todayY = year(datetime('now')); %#ok<DATST>

%% =================== PARAMETERS / TABLES ===================
% FRA in months-from-birth (simplified; swap for official table)
FRA_m = @(by) (by>=1960)*67*12 + (by<1960)*(66*12 + max(0,(by-1954)*2));

% Early reduction (worker), Delayed credit (monthly to 70)
R_early = @(mEarly) ((5/9)/100)*min(mEarly,36) + ((5/12)/100)*max(0,mEarly-36);
DRC     = @(mDelay) ((2/3)/100)*mDelay;

% Spousal early reduction (applied to *excess*)
R_spousal = @(mEarly) ((25/36)/100)*min(mEarly,36) + ((5/12)/100)*max(0,mEarly-36);

% Family maximum (approx; replace with official piecewise if desired)
FMB = @(PIA) (PIA<=1226).*max(1.5*PIA,PIA+200) + ...
             (PIA>1226 & PIA<=1770).*1.75*PIA + ...
             (PIA>1770 & PIA<=2320).*2.0*PIA + ...
             (PIA>2320).*2.188*PIA;

% AWI proxy and Bend points (scale base by AWI ratio; replace with official tables)
AWI = @(y) 32154*(1.032).^(y-1990);
bpBaseYear = 2025; bpBase = [1174, 7078];  % example-like AIME bend points
scaleBend = @(eligY) round(bpBase * (AWI(eligY)/AWI(bpBaseYear)));

% COLA annual series (placeholder): constant 2%/yr → monthly c_t
COLA_annual = @(y) 0.02;
c_month = @(y) COLA_annual(y)/12; % monthly COLA rate for year y (approx)

% Earnings test thresholds (optional)
ET_under = @(y) 22320*(1.02)^(y-2024);

%% =================== HELPERS ===================
ym2idx = @(Y,M) 12*Y + M;
ageMAt = @(bY,bM,Y,M) (Y-bY)*12 + (M-bM);
makeE = @(Y1,Y2,wm) [(Y1:Y2)', repmat(12*wm, Y2-Y1+1, 1)];
safeDiv = @(a,b) (b<=0)*0 + (b>0).*(a./b);

%% =================== INITIALIZATION (AIME/PIA62) ===================
% You
me.FRAm = FRA_m(me.birthY);
me.eligY62 = me.birthY + 62;
bp_me = scaleBend(me.eligY62);
earn_me = makeE(me.workStartY, me.workEndY, me.monthlyIncome);
me.AIME = computeAIME(me.birthY, me.birthM, earn_me, AWI);
me.PIA62 = computePIAfromAIME(me.AIME, bp_me(1), bp_me(2));

% Spouse
if hasSpouse
    sp.FRAm = FRA_m(sp.birthY);
    sp.eligY62 = sp.birthY + 62;
    bp_sp = scaleBend(sp.eligY62);
    earn_sp = makeE(sp.workStartY, sp.workEndY, sp.monthlyIncome);
    sp.AIME = computeAIME(sp.birthY, sp.birthM, earn_sp, AWI);
    sp.PIA62 = computePIAfromAIME(sp.AIME, bp_sp(1), bp_sp(2));
else
    sp = struct([]);
end

%% =================== TIME GRID ===================
startY = min([me.birthY+62, hasSpouse*(sp.birthY+62)+~hasSpouse*9999, todayY]);
endY   = max([me.birthY+simEndAgeY, hasSpouse*(sp.birthY+simEndAgeY)+~hasSpouse*(me.birthY+simEndAgeY)]);
[months, gridY, gridM] = makeMonthGrid(startY, endY);
T = numel(months);

% Indices: claim & death months (from birth)
me.tClaim = me.claimAgeY*12;
me.tDeath = ifEmptyToInf(me.deathAgeY)*12;
if hasSpouse
    sp.tClaim = sp.claimAgeY*12;
    sp.tDeath = ifEmptyToInf(sp.deathAgeY)*12;
end

% Age in months (state) at each t for convenience
me.ageM = ageMAt(me.birthY, me.birthM, gridY, gridM);
if hasSpouse, sp.ageM = ageMAt(sp.birthY, sp.birthM, gridY, gridM); end

%% =================== DIFFERENCE VARIABLES ===================
% PIA_t (COLA-adjusted), initialized at first visible month using 62-index
PIA_me = zeros(T,1); PIA_sp = zeros(T,1);
% monthly COLA rate c_t (by calendar year)
c_t = arrayfun(@(y) c_month(y), gridY(:));

% Init PIA at t=1 based on calendar year vs eligibility year:
PIA_me(1) = me.PIA62 * colaCumulFrom62(me.eligY62, gridY(1), COLA_annual);
if hasSpouse
    PIA_sp(1) = sp.PIA62 * colaCumulFrom62(sp.eligY62, gridY(1), COLA_annual);
end

% Indicator I_t (alive & claimed)
I_me = zeros(T,1); I_sp = zeros(T,1);
% Age multipliers (fixed at claim time)
phi_me = 1; phi_sp = 1;
% Spousal excess factor xi (we'll compute each step from current PIAs)
% Earnings test omega_t (1 default)
omega_me = ones(T,1); omega_sp = ones(T,1);

% Outputs
B_me = zeros(T,1); B_sp = zeros(T,1); B_kids = zeros(T,1);
B_HH = zeros(T,1); S_HH = zeros(T,1);

%% =================== MAIN DIFFERENCE LOOP ===================
for t = 1:T
    y = gridY(t); m = gridM(t);

    % ---- (1) PIA update: PIA_{t} known; compute PIA_{t+1} if not last ----
    if t > 1
        % advance from t-1 → t with monthly COLA c_{t-1}
        PIA_me(t) = PIA_me(t-1) * (1 + c_t(t-1));
        if hasSpouse
            PIA_sp(t) = PIA_sp(t-1) * (1 + c_t(t-1));
        end
    end

    % ---- (2) Claiming indicator I_{t}: alive & claimed ----
    I_me(t) = (me.ageM(t) >= me.tClaim) && (me.ageM(t) < me.tDeath);
    if hasSpouse
        I_sp(t) = (sp.ageM(t) >= sp.tClaim) && (sp.ageM(t) < sp.tDeath);
    end

    % ---- (3) Age multiplier phi (set once at claim) ----
    if me.ageM(t) == me.tClaim
        dev = me.tClaim - me.FRAm;
        if dev < 0,  phi_me = 1 - R_early(-dev);
        elseif dev > 0, phi_me = 1 + DRC(dev);
        else, phi_me = 1;
        end
    end
    if hasSpouse && sp.ageM(t) == sp.tClaim
        dev = sp.tClaim - sp.FRAm;
        if dev < 0,  phi_sp = 1 - R_early(-dev);
        elseif dev > 0, phi_sp = 1 + DRC(dev);
        else, phi_sp = 1;
        end
    end

    % ---- (4) Earnings test omega_t (optional) ----
    if applyEarningsTest
        EY_me = (y <= me.workEndY) * (12*me.monthlyIncome);
        omega_me(t) = double( ~(me.ageM(t) < me.FRAm && me.ageM(t) >= me.tClaim && EY_me > ET_under(y)) );
        if hasSpouse
            EY_sp = (y <= sp.workEndY) * (12*sp.monthlyIncome);
            omega_sp(t) = double( ~(sp.ageM(t) < sp.FRAm && sp.ageM(t) >= sp.tClaim && EY_sp > ET_under(y)) );
        end
    end

    % ---- (5) Spousal excess xi (deemed filing simplified) ----
    xi_me = 0; xi_sp = 0;
    if hasSpouse
        if I_me(t)
            excess = max(0, 0.5*PIA_sp(t) - PIA_me(t));
            mEarlySp = max(0, me.FRAm - me.tClaim);
            xi_me = safeDiv(excess*(1 - R_spousal(mEarlySp)), max(PIA_me(t), eps));
        end
        if I_sp(t)
            excess = max(0, 0.5*PIA_me(t) - PIA_sp(t));
            mEarlySp = max(0, sp.FRAm - sp.tClaim);
            xi_sp = safeDiv(excess*(1 - R_spousal(mEarlySp)), max(PIA_sp(t), eps));
        end
    end

    % ---- (6) Own + spousal (difference form) ----
    B_me(t) = I_me(t) * phi_me * PIA_me(t) * (1 + xi_me) * omega_me(t);
    if hasSpouse
        B_sp(t) = I_sp(t) * phi_sp * PIA_sp(t) * (1 + xi_sp) * omega_sp(t);
    else
        B_sp(t) = 0;
    end

    % ---- (7) Children auxiliaries with FMB scaling ----
    if hasChildren
        K_t = 0; % eligible children count
        for k = 1:numel(children)
            kidAgeM = ageMAt(children(k).birthY, children(k).birthM, y, m);
            if kidAgeM < 18*12, K_t = K_t + 1; end
        end
        if K_t > 0
            PIA_hi = max(PIA_me(t), PIA_sp(t));
            Bkids_raw = 0.5 * K_t * PIA_hi;
            Fcap = FMB(PIA_hi);
            baseOW = (PIA_hi==PIA_me(t))*B_me(t) + (PIA_hi==PIA_sp(t))*B_sp(t);
            pool   = max(0, Fcap - baseOW);
            lambda = min(1, safeDiv(pool, Bkids_raw));
            B_kids(t) = lambda * Bkids_raw;
        else
            B_kids(t) = 0;
        end
    else
        B_kids(t) = 0;
    end

    % ---- (8) Household difference update ----
    B_HH(t) = B_me(t) + B_sp(t) + B_kids(t);
    if t == 1, S_HH(t) = B_HH(t); else, S_HH(t) = S_HH(t-1) + B_HH(t); end
end

%% =================== OUTPUTS & PLOTS ===================
fprintf('\n==== Lifetime Benefits (nominal, difference-model) ====\n');
fprintf('You:       $%0.0f\n', sum(B_me));
if hasSpouse, fprintf('Spouse:    $%0.0f\n', sum(B_sp)); end
if hasChildren, fprintf('Children:  $%0.0f\n', sum(B_kids)); end
fprintf('Household: $%0.0f\n\n', S_HH(end));

figure('Name','Monthly Benefits (Difference-Equation)','Color','w');
plot(months, B_me, 'LineWidth',1.3); hold on;
if hasSpouse, plot(months, B_sp, 'LineWidth',1.3); end
if hasChildren, plot(months, B_kids, 'LineWidth',1.3); end
plot(months, B_HH, 'k','LineWidth',1.8);
grid on; xlabel('Calendar Month Index'); ylabel('Benefit ($/mo)');
lg = {'You'}; if hasSpouse, lg{end+1}='Spouse'; end
if hasChildren, lg{end+1}='Children'; end
lg{end+1}='Household Total';
legend(lg,'Location','best'); title('Difference-Equation Benefit Flows');

figure('Name','Household Cumulative (Difference-Equation)','Color','w');
plot(months, S_HH, 'LineWidth',1.8); grid on;
xlabel('Calendar Month Index'); ylabel('Cumulative Benefits ($)');
title('Household Lifetime Accumulation S_{t} = S_{t-1} + B_{t}');

%% =================== LOCAL FUNCTIONS ===================
function [months, ys, ms] = makeMonthGrid(yStart, yEnd)
  months = (yStart*12+1):(yEnd*12+12);
  ys = floor(months/12);
  ms = months - ys*12; ms(ms==0)=12;
end

function v = ifEmptyToInf(x)
  if isempty(x), v = inf; else, v = x; end
end

function AIME = computeAIME(bY,bM, earnTable, AWIfun)
% earnTable: [year, annual_earnings]; AWI indexing up to age-60 year
  y60 = bY + 60;
  Eidx = zeros(size(earnTable,1),1);
  for i=1:size(earnTable,1)
      y = earnTable(i,1); e = earnTable(i,2);
      if y <= y60
          Eidx(i) = e * (AWIfun(y60)/AWIfun(y));
      else
          Eidx(i) = e; % post-60 not indexed
      end
  end
  if numel(Eidx) < 35, Eidx = [Eidx; zeros(35-numel(Eidx),1)]; end
  Es = sort(Eidx, 'descend');
  AIME = floor(sum(Es(1:35))/420); % floor to whole dollars
end

function PIA = computePIAfromAIME(AIME, BP1, BP2)
  if AIME <= BP1
      PIA0 = 0.90*AIME;
  elseif AIME <= BP2
      PIA0 = 0.90*BP1 + 0.32*(AIME-BP1);
  else
      PIA0 = 0.90*BP1 + 0.32*(BP2-BP1) + 0.15*(AIME-BP2);
  end
  PIA = floor(PIA0*10)/10; % round down to dime
end

function F = colaCumulFrom62(eligY62, yNow, COLA_annual_fun)
% cumulative COLA multiplier from eligibility year to current year (Jan-to-Jan)
  if yNow <= eligY62, F = 1; return; end
  years = (eligY62+1):yNow;
  F = prod(1 + arrayfun(COLA_annual_fun, years));
end
