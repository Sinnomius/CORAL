% benchmark_CORAL_ablation_fixed.m
%
% Corrected ablation study using the robust reference solution.

clear;
clc;

nRuns=20;
baseSeed=5000;

feasTol=1e-5;
successGapPercent=0.50;

nBinary=5;

xBounds=[
    320 430
    0.5 8.0
    0.0 1.0
    0.0 0.80
];

reference=exhaustive_superstructure_reference_fixed( ...
    'Display',false, ...
    'MultiStartN',30, ...
    'Seed',321, ...
    'FeasibilityTolerance',feasTol);

fRef=reference.best.f;
yRef=reference.best.y;

names=[
    "Basic"
    "Adaptive"
    "LocalNLP"
    "Full"
];

adaptiveFlag=[false true false true];
localFlag=[false false true true];

nCases=numel(names);

bestTAC=nan(nCases,1);
medianTAC=nan(nCases,1);
meanTAC=nan(nCases,1);
meanGap=nan(nCases,1);
medianGap=nan(nCases,1);
successRate=nan(nCases,1);
topologyRecoveryRate=nan(nCases,1);
feasibilityRate=nan(nCases,1);
medianEval=nan(nCases,1);
medianTime=nan(nCases,1);

for c=1:nCases

    TAC=nan(nRuns,1);
    gap=nan(nRuns,1);
    feasible=false(nRuns,1);
    topologyMatch=false(nRuns,1);
    ok=false(nRuns,1);
    evals=nan(nRuns,1);
    times=nan(nRuns,1);

    fprintf('\nCase %s\n',names(c));

    for r=1:nRuns

        opt=CORALSuperstructureOptimizer( ...
            @simple_process_superstructure, ...
            nBinary, ...
            xBounds, ...
            'ReefSize',70, ...
            'Seed',baseSeed+r, ...
            'AdaptiveOperators',adaptiveFlag(c), ...
            'LocalRefinement',localFlag(c), ...
            'BleachingThreshold',0.15, ...
            'BleachingFraction',0.20);

        t0=tic;

        res=opt.optimize( ...
            'MaxIterations',180, ...
            'Patience',50, ...
            'Verbose',false);

        times(r)=toc(t0);

        TAC(r)=res.best.f;
        gap(r)=100*(res.best.f-fRef)/max(abs(fRef),1e-12);
        evals(r)=res.evaluations;

        feasible(r)=res.best.v<=feasTol;
        topologyMatch(r)=isequal(res.best.y,yRef);

        ok(r)=feasible(r) && topologyMatch(r) && ...
              gap(r)<=successGapPercent;
    end

    mask=feasible;

    bestTAC(c)=min(TAC(mask));
    medianTAC(c)=median(TAC(mask));
    meanTAC(c)=mean(TAC(mask));

    meanGap(c)=mean(gap(mask));
    medianGap(c)=median(gap(mask));

    successRate(c)=100*mean(ok);
    topologyRecoveryRate(c)=100*mean(topologyMatch);
    feasibilityRate(c)=100*mean(feasible);

    medianEval(c)=median(evals);
    medianTime(c)=median(times);
end

ablationTable=table( ...
    names, ...
    adaptiveFlag', ...
    localFlag', ...
    bestTAC, ...
    medianTAC, ...
    meanTAC, ...
    meanGap, ...
    medianGap, ...
    feasibilityRate, ...
    topologyRecoveryRate, ...
    successRate, ...
    medianEval, ...
    medianTime, ...
    'VariableNames',{ ...
        'Configuration', ...
        'AdaptiveOperators', ...
        'LocalNLP', ...
        'BestTAC', ...
        'MedianTAC', ...
        'MeanTAC', ...
        'MeanGapPercent', ...
        'MedianGapPercent', ...
        'FeasibilityRatePercent', ...
        'TopologyRecoveryRatePercent', ...
        'SuccessRatePercent', ...
        'MedianEvaluations', ...
        'MedianRuntimeSeconds'});

disp(ablationTable);

writetable(ablationTable,'CORAL_ablation_summary_fixed.csv');

figure;
bar(categorical(names),successRate);
ylabel('Success rate [%]');
title('CORAL ablation study - corrected reference');
grid on;
