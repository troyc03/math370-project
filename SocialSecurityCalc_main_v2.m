%% SocialSecurityCalc_main_v2.m - Social Security Difference-Equation Model (Monthly)
% Discrete-time (month) system for testing core logic.
% This script calls untitled_updated_v2.m
clear; clc; close all;

%% =================== USER INPUTS (TEST CASE) ===================
% Individual (you)
me.birthY = 1985; me.birthM = 9;
me.monthlyIncome = 6500;        % covered earnings ($/mo)
me.workStartY = 2008; me.workEndY = 2048;
me.claimAgeY = 62;              % you claim at this age (years)
me.deathAgeY = 90;              % optional; set [] for open-ended

% Spouse (toggle)
hasSpouse = false;
sp.birthY = 1986; sp.birthM = 3;
sp.monthlyIncome = 4200;
sp.workStartY = 2009; sp.workEndY = 2047;
sp.claimAgeY = 67;
sp.deathAgeY = 90;

% Children (toggle) - TEST CASE WITH MAX 9 CHILDREN
hasChildren = false;
children(1).birthY = 2015; children(1).birthM = 1; % Child 1
children(2).birthY = 2016; children(2).birthM = 5; % Child 2
children(3).birthY = 2017; children(3).birthM = 10; % Child 3
children(4).birthY = 2019; children(4).birthM = 3; % Child 4
children(5).birthY = 2020; children(5).birthM = 7; % Child 5
children(6).birthY = 2022; children(6).birthM = 11; % Child 6
children(7).birthY = 2024; children(7).birthM = 2; % Child 7
children(8).birthY = 2025; children(8).birthM = 8; % Child 8
children(9).birthY = 2050; children(9).birthM = 4; % Child 9

%% =================== RUN CALCULATION ===================
[months, years, B_me, B_sp, B_kids, B_HH, S_HH] = untitled_updated_v2(me, hasSpouse, sp, hasChildren, children);


%% =================== PLOTTING (Revised) ===================
figure(1);

% --- Plot 1: Monthly Benefit Flows ---
subplot(2,1,1);
plot(years, B_me, 'LineWidth', 2.0, 'Color', [0.1 0.1 0.9]), hold on; % Blue: Me
if hasSpouse, plot(years, B_sp, 'LineWidth', 2.0, 'Color', [0.9 0.1 0.1]); end % Red: Spouse
if hasChildren, plot(years, B_kids, 'LineWidth', 2.0, 'Color', [0.1 0.8 0.1]); end % Green: Children
plot(years, B_HH, 'k', 'LineWidth', 3.0); % Black: Household Total
hold off;
grid on;
xlabel('Year');
ylabel('Monthly Benefit ($/mo)');
title('Monthly Benefit Payments');

lg = {'Me'};
if hasSpouse, lg{end+1}='Spouse'; end
if hasChildren, lg{end+1}='Children'; end
lg{end+1}='Household Total';
legend(lg, 'Location', 'northwest');

% --- Plot 2: Household Lifetime Accumulation ---
subplot(2,1,2);
plot(years, S_HH, 'LineWidth', 2.5, 'Color', [0 0 0.5]);
grid on;
xlabel('Year');
ylabel('Cumulative Benefits ($)');
title('Household Lifetime Accumulation');