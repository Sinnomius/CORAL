% example_CORAL_superstructure.m
clear; clc;

% Binary topology:
% [CSTR, PFR, Flash, Distillation, Recycle]
nBinary=5;

% Continuous variables:
% [reactor temperature, reactor size, separation severity, recycle fraction]
xBounds=[
    320 430
    0.5 8.0
    0.0 1.0
    0.0 0.80
];

optimizer=CORALSuperstructureOptimizer( ...
    @simple_process_superstructure,nBinary,xBounds, ...
    'ReefSize',70, ...
    'Seed',42, ...
    'LocalRefinement',true, ...
    'AdaptiveOperators',true, ...
    'BleachingThreshold',0.15, ...
    'BleachingFraction',0.20);

result=optimizer.optimize( ...
    'MaxIterations',180, ...
    'Patience',50, ...
    'Verbose',true);

best=result.best;

fprintf('\n========================================\n');
fprintf('BEST CORAL SOLUTION\n');
fprintf('========================================\n');
fprintf('Feasible: %d\n',best.feasible);
fprintf('Objective TAC: %.4f\n',best.f);
fprintf('Constraint violation: %.3e\n',best.v);

fprintf('\nTopology:\n');
fprintf('  CSTR         = %d\n',best.y(1));
fprintf('  PFR          = %d\n',best.y(2));
fprintf('  Flash        = %d\n',best.y(3));
fprintf('  Distillation = %d\n',best.y(4));
fprintf('  Recycle      = %d\n',best.y(5));

fprintf('\nContinuous variables:\n');
fprintf('  Reactor T    = %.3f K\n',best.x(1));
fprintf('  Reactor size = %.3f\n',best.x(2));
fprintf('  Sep severity = %.3f\n',best.x(3));
fprintf('  Recycle frac = %.3f\n',best.x(4));

fprintf('\nPerformance:\n');
fprintf('  Product rate       = %.3f\n',best.info.product);
fprintf('  Reactor conversion = %.3f\n',best.info.reactorConversion);
fprintf('  Overall conversion = %.3f\n',best.info.overallConversion);
fprintf('  Recovery           = %.3f\n',best.info.recovery);

fprintf('\nIterations: %d\n',result.iterations);
fprintf('Model evaluations: %d\n',result.evaluations);

figure;
plot(0:numel(result.history.bestF)-1,result.history.bestF,'LineWidth',1.5);
xlabel('Iteration'); ylabel('Best TAC'); title('CORAL convergence'); grid on;

figure;
plot(0:numel(result.history.diversity)-1,result.history.diversity,'LineWidth',1.5);
xlabel('Iteration'); ylabel('Mean topology diversity'); title('Reef topology diversity'); grid on;

disp('Final adaptive operator probabilities:');
disp(result.operatorProbabilities);
