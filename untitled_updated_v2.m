function [M, Y, B1, B2, B3, B4, S] = untitled_updated_v2(me, hasSpouse, sp, hasChildren, children)
% untitled_updated_v2.m - Core Social Security Benefit Calculation Function (Revised)
%
% This function computes monthly social security benefits and cumulative
% benefits for a worker, spouse, and their children (max 9).
%
% Outputs:
%   M: Time in months
%   Y: Fractional Years (New: for better GUI plotting)
%   B1: Benefit for Worker (Me)
%   B2: Benefit for Spouse
%   B3: Benefit for Children (Total)
%   B4: Benefit for Household (Total B1+B2+B3)
%   S: Cumulative Household Benefit

%% ====== INPUT HANDLING AND DATA SETUP ======
% Handle missing / null inputs safely
if nargin < 1 || isempty(me)
    % Default profile if called without GUI inputs (for testing)
    me.birthY = 1985; me.birthM = 9; me.monthlyIncome = 6500;
    me.workStartY = 2008; me.workEndY = 2048; me.claimAgeY = 67; me.deathAgeY = 90;
end
if nargin < 2 || isempty(hasSpouse),   hasSpouse   = false; end
if nargin < 3 || isempty(sp),          
    % Create a default spouse struct to avoid errors later
    sp = struct('birthY', 0, 'birthM', 0, 'monthlyIncome', 0, 'workStartY', 0, 'workEndY', 0, 'claimAgeY', 0, 'deathAgeY', 0);
end
if nargin < 4 || isempty(hasChildren), hasChildren = false; end
if nargin < 5 || isempty(children),    children    = []; end

% Ensure death ages are not empty (use a large number if not provided)
me.deathAgeY = ifEmptyToInf(me.deathAgeY);
sp.deathAgeY = ifEmptyToInf(sp.deathAgeY);


% === Dummy Economic Data (Now using a mix of Historical and Projected AWI) ===
% AWI (Average Wage Index) data: [Year, AWI_value]
% Using dense historical data points for calculation stability.
AWI_data = [
    1980, 12513.46; 
    1990, 21067.88; % Stabilizing historical anchor point
    2000, 32921.92;
    2010, 41673.83; % Stabilizing historical anchor point
    2020, 55628.60;
    2024, 69846.57; % Crucial latest official value for PIA indexing
    2040, 97000.00; % Projected value
    2060, 130000.00 % Projected value
];
AWIfun = @(y) interp1(AWI_data(:,1), AWI_data(:,2), y, 'linear', 'extrap');

% COLA (Cost of Living Adjustment) data: [Year, COLA_rate]
COLA_data = [2024, 0.032; 2025, 0.03; 2050, 0.025]; % Example projected data
COLAs = @(y) interp1(COLA_data(:,1), COLA_data(:,2), y, 'previous', 'extrap');


%% =================== TIME GRID SETUP ===================
% Set simulation start and end years
% Determine potential years for the simulation grid.
potential_years = [me.birthY + me.claimAgeY];
end_years = [me.birthY + me.deathAgeY];

if hasSpouse
    % Only include spouse's data if spouse is present
    potential_years = [potential_years, sp.birthY + sp.claimAgeY];
    end_years = [end_years, sp.birthY + sp.deathAgeY];
end

if hasChildren && ~isempty(children)
    % Add the children's eligibility end year (birth year + 19) to the end_years list.
    end_years = [end_years, max([children.birthY]) + 19];
end

% Start year: Earliest claim year of the adults
startY = floor(min(potential_years));

% End year: Latest death age or children's end eligibility, up to a max
endY   = max([end_years, 2090]);

[months, gridY, gridM] = makeMonthGrid(startY, endY);
T = numel(months);

% NEW: Calculate fractional years for smooth x-axis plotting in the GUI
years = gridY + (gridM-1)/12;

% Initialize Benefit arrays
B_me   = zeros(T, 1);
B_sp   = zeros(T, 1);
B_kids = zeros(T, 1);
B_HH   = zeros(T, 1);
S_HH   = zeros(T, 1);

% Prepare Earnings Table (Simplified: assumes constant monthly income up to retirement)
earnings = zeros(me.workEndY - me.workStartY + 1, 2);
earnings(:, 1) = me.workStartY:me.workEndY;
earnings(:, 2) = me.monthlyIncome * 12;
me.earnTable = earnings;

if hasSpouse
    spEarnings = zeros(sp.workEndY - sp.workStartY + 1, 2);
    spEarnings(:, 1) = sp.workStartY:sp.workEndY;
    spEarnings(:, 2) = sp.monthlyIncome * 12;
    sp.earnTable = spEarnings;
else
    sp.earnTable = [];
end


%% =================== MAIN SIMULATION LOOP ===================
% Pre-calculate PIA and MFB for each individual
me.PIA = computePIA(me.birthY, me.birthM, me.earnTable, AWIfun);
if hasSpouse
    sp.PIA = computePIA(sp.birthY, sp.birthM, sp.earnTable, AWIfun);
else
    sp.PIA = 0; % Ensure sp.PIA exists if sp data is used elsewhere
end
me.MFB_limit = 1.5 * me.PIA; % Approximation of the MFB rule
sp.MFB_limit = 1.5 * sp.PIA; % Approximation of the MFB rule

% Find max PIA for children's benefit base
maxPIA_base = max(me.PIA, sp.PIA);

% Initial PIA values (before COLA is applied)
current_me_PIA = me.PIA;
current_sp_PIA = sp.PIA;

% Simulation starts (time index t)
for t = 1:T
    currentY = gridY(t);
    currentM = gridM(t);
    
    % Apply COLA at the beginning of each year (January)
    if currentM == 1
        cola_rate = COLAs(currentY);
        current_me_PIA = current_me_PIA * (1 + cola_rate);
        current_sp_PIA = current_sp_PIA * (1 + cola_rate);
        me.MFB_limit = me.MFB_limit * (1 + cola_rate);
        sp.MFB_limit = sp.MFB_limit * (1 + cola_rate);
    end

    % --- 1. Worker (Me) Benefit Calculation ---
    B_me(t) = computeBenefit(me, currentY, currentM, current_me_PIA);
    
    % --- 2. Spouse Benefit Calculation ---
    B_sp(t) = 0;
    if hasSpouse
        B_sp(t) = computeSpousalBenefit(me, sp, currentY, currentM, current_sp_PIA, current_me_PIA);
    end
    
    % --- 3. Children Benefit Calculation ---
    B_kids(t) = 0;
    if hasChildren && ~isempty(children)
        % For children, the benefit is based on the highest PIA of the two workers
        B_kids(t) = computeChildrenBenefit(children, currentY, currentM, maxPIA_base);
    end
    
    % --- 4. Total Household Benefit (before MFB adjustment) ---
    B_total_pre_MFB = B_me(t) + B_sp(t) + B_kids(t);

    % --- 5. Apply Maximum Family Benefit (MFB) ---
    % MFB calculation is complex. Here, we apply a simplified approach:
    % Use the MFB limit associated with the primary worker (Me)
    MFB_limit = me.MFB_limit;
    
    if B_total_pre_MFB > MFB_limit
        % Prorate the dependent's benefits if MFB is exceeded
        reduction_amount = B_total_pre_MFB - MFB_limit;
        
        % The worker's (Me) benefit is usually protected from reduction.
        % The reduction falls first on spouse and children's benefits.
        
        % Dependent benefits subject to reduction
        B_dependents = B_sp(t) + B_kids(t);
        
        if B_dependents > 0
            % Prorate the reduction among spouse and children
            reduction_sp = reduction_amount * (B_sp(t) / B_dependents);
            reduction_kids = reduction_amount * (B_kids(t) / B_dependents);

            B_sp(t) = max(0, B_sp(t) - reduction_sp);
            B_kids(t) = max(0, B_kids(t) - reduction_kids);
        end
        B_HH(t) = B_me(t) + B_sp(t) + B_kids(t);
    else
        B_HH(t) = B_total_pre_MFB;
    end
    
    % --- 6. Cumulative Household Benefit ---
    if t == 1
        S_HH(t) = B_HH(t);
    else
        S_HH(t) = S_HH(t-1) + B_HH(t);
    end
end


%% =================== OUTPUTS ===================
M  = months;
Y  = years; % Return fractional years
B1 = B_me;
B2 = B_sp;
B3 = B_kids;
B4 = B_HH;
S  = S_HH;

%% =================== CONSOLE OUTPUT ===================
fprintf('\n--- Lifetime Benefits ---\n');
fprintf('Me:        $%0.0f\n', sum(B_me));
if hasSpouse
    fprintf('Spouse:    $%0.0f\n', sum(B_sp));
end
if hasChildren && ~isempty(children)
    fprintf('Children:  $%0.0f\n', sum(B_kids));
end
fprintf('Household: $%0.0f\n\n', S_HH(end));


%% =================== LOCAL FUNCTIONS ===================
function [months, ys, ms] = makeMonthGrid(yStart, yEnd)
% Creates a monthly time index grid from yStart to yEnd
  months = (yStart*12+1):(yEnd*12+12);
  ys     = floor(months/12);
  ms     = months - ys*12; ms(ms==0)=12;
end

function v = ifEmptyToInf(x)
% Helper function to replace empty inputs with Inf
  if isempty(x) || x == 0, v = inf; else, v = x; end
end

function AIME = computeAIME(bY,bM, earnTable, AWIfun)
% Computes Average Indexed Monthly Earnings (AIME)
  y60  = bY + 60;
  Eidx = zeros(size(earnTable,1),1);
  AWI_60 = AWIfun(y60); % Calculate AWI at age 60 once

  % Safety check: Cannot proceed if AWI at age 60 is NaN or 0
  if isnan(AWI_60) || AWI_60 == 0
      AIME = 0; % AIME cannot be calculated
      return;
  end

  for i=1:size(earnTable,1)
      y = earnTable(i,1); e = earnTable(i,2);
      if y <= y60
          AWI_y = AWIfun(y);
          % Robust check for NaN or Zero AWI for the earning year
          if isnan(AWI_y) || AWI_y == 0
              Eidx(i) = 0; % Treat as zero indexed earnings if AWI is invalid
          else
              Eidx(i) = e * (AWI_60 / AWI_y);
          end
      else
          Eidx(i) = e; % post-60 earnings are not indexed
      end
  end
  
  % Select the 35 highest indexed earning years
  if numel(Eidx) < 35, Eidx = [Eidx; zeros(35-numel(Eidx),1)]; end
  Es = sort(Eidx, 'descend');
  
  % AIME: Sum of 35 highest / 420 months (35 years * 12 months)
  AIME = floor(sum(Es(1:35))/420);
end

    function PIA = computePIA(bY,bM, earnTable, AWIfun)
% Computes Primary Insurance Amount (PIA) based on AIME
  if isempty(earnTable), PIA = 0; return; end
  
  AIME = computeAIME(bY,bM, earnTable, AWIfun);
  if isnan(AIME) || AIME == 0, PIA = 0; return; end % AIME이 NaN이면 PIA는 0
  
  % PIA bends points (simplified, based on 2024 values)
  y62 = bY + 62;
  AWI_62 = AWIfun(y62); % Calculate AWI at age 62
  AWI_2024 = AWIfun(2024); % Calculate AWI 2024

  % Robust safety check for AWI values used for indexing bend points
  if isnan(AWI_62) || isnan(AWI_2024) || AWI_2024 == 0
      % Fallback: If AWI is invalid, use 2024 unindexed bend points
      bp1 = 1174;
      bp2 = 7088;
  else
      % AWI indexation for bend points. (The redundant if/else removed)
      bp1 = 1174 * (AWI_62/AWI_2024); % First bend point
      bp2 = 7088 * (AWI_62/AWI_2024); % Second bend point
  end

  % PIA formula (90%-32%-15% of AIME)
  if AIME <= bp1
      PIA = 0.90 * AIME;
  elseif AIME <= bp2
      PIA = 0.90 * bp1 + 0.32 * (AIME - bp1);
  else
      PIA = 0.90 * bp1 + 0.32 * (bp2 - bp1) + 0.15 * (AIME - bp2);
  end
end

function benefit = computeBenefit(p, currentY, currentM, current_PIA)
% Computes the monthly benefit for the individual worker (Me)
  benefit = 0;
  
  % Check if worker is alive
  if (currentY - p.birthY) > p.deathAgeY || ((currentY - p.birthY) == p.deathAgeY && currentM > p.birthM)
      return; 
  end
  
  % Check if worker has claimed
  claimY = p.birthY + p.claimAgeY;
  
  if currentY > claimY || (currentY == claimY && currentM >= p.birthM)
      % Adjust for Early Retirement or Delayed Retirement
      FRA = p.birthY + 67; % Full Retirement Age (simplified to 67)
      
      % Calculate adjustment factor based on claim age vs FRA
      % This is a highly simplified adjustment factor (ARC/DRC)
      if p.claimAgeY < 67 % Early Retirement
          months_early = (67 - p.claimAgeY) * 12;
          adj_factor = 1 - (months_early * 0.00555); % Approx. 6.67% per year
      elseif p.claimAgeY > 67 % Delayed Retirement
          months_late = (p.claimAgeY - 67) * 12;
          adj_factor = 1 + (months_late * 0.00667); % 8% per year
      else % Full Retirement Age
          adj_factor = 1.0;
      end
      
      benefit = current_PIA * adj_factor;
  end
end

function benefit = computeSpousalBenefit(me, sp, currentY, currentM, sp_current_PIA, me_current_PIA)
% Computes the monthly benefit for the spouse
  benefit = 0;
  
  % Spouse must be alive and meet the claiming age criteria
  if (currentY - sp.birthY) > sp.deathAgeY || ((currentY - sp.birthY) == sp.deathAgeY && currentM > sp.birthM)
      return; 
  end

  % Spouse benefit is received only if the worker (Me) is also claiming
  me_claimY = me.birthY + me.claimAgeY;
  
  if currentY > me_claimY || (currentY == me_claimY && currentM >= me.birthM)
      % Spouse must also be claiming
      sp_claimY = sp.birthY + sp.claimAgeY;
      
      if currentY > sp_claimY || (currentY == sp_claimY && currentM >= sp.birthM)
          % 1. Spouse's Own Benefit (B_sp_own)
          B_sp_own = computeBenefit(sp, currentY, currentM, sp_current_PIA);
          
          % 2. Spousal Dependent Benefit (B_sp_dep)
          B_sp_dep = 0.5 * me_current_PIA; % 50% of worker's PIA
          
          % Spouse receives MAX(B_sp_own, B_sp_dep)
          % NOTE: Spousal benefit is the difference, not a simple max.
          
          % Total Spousal Benefit: own benefit + (spousal dep benefit - own benefit)
          % Spousal benefit is 0.5 * worker's PIA, reduced by own benefit
          B_sp_dep_total = max(0, B_sp_dep - B_sp_own);
          
          benefit = B_sp_own + B_sp_dep_total;
      end
  end
end

function totalBenefit = computeChildrenBenefit(children, currentY, currentM, maxPIA_base)
% Computes the total benefit for all children
  totalBenefit = 0;
  
  % Child receives benefit if:
  % 1. They are under 18 (or 19 if still in elementary/secondary school)
  % 2. They are disabled (not modeled here)
  
  B_per_child = 0.5 * maxPIA_base; % 50% of the worker's (or spouse's) PIA
  
  for i = 1:numel(children)
      c = children(i);
      child_age = (currentY - c.birthY) + (currentM - c.birthM)/12;
      
      % Simplified: Child eligible if age < 18
      if child_age < 18
          totalBenefit = totalBenefit + B_per_child;
      end
  end
end
end