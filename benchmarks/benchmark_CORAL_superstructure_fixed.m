% benchmark_CORAL_superstructure_fixed.m
%
% Corrected 30-run CORAL benchmark.
%
% Uses the robust reference solver and a consistent feasibility tolerance.

clear;
clc;

%% Settings
nRuns = 30;
baseSeed = 1000;

reefSize = 70;
maxIterations = 180;
patience = 50;

feasTol = 1e-5;
successGapPercent = 0.50;

useLocalRefinement = true;
useAdaptiveOperators = true;

%% Problem
nBinary = 5;

xBounds = [
    320 430
    0.5 8.0
    0.0 1.0
    0.0 0.80
];

%% Robust reference
fprintf('Computing robust reference solution...\n');

reference = exhaustive_superstructure_reference_fixed( ...
    'Display',true, ...
    'MultiStartN',30, ...
    'Seed',321, ...
    'FeasibilityTolerance',feasTol);

fRef = reference.best.f;
yRef = reference.best.y;

fprintf('Reference TAC = %.10f\n',fRef);
fprintf('Reference topology = [%d %d %d %d %d]\n\n',yRef);

%% Storage
runNumber = (1:nRuns)';
seed = zeros(nRuns,1);
TAC = nan(nRuns,1);
violation = nan(nRuns,1);
feasible = false(nRuns,1);
topologyMatch = false(nRuns,1);
gapPercent = nan(nRuns,1);
evaluations = nan(nRuns,1);
runtime = nan(nRuns,1);
iterations = nan(nRuns,1);
success = false(nRuns,1);

bestY = nan(nRuns,nBinary);
bestX = nan(nRuns,size(xBounds,1));
allHistory = cell(nRuns,1);

%% Runs
fprintf('Running CORAL benchmark (%d runs)...\n\n',nRuns);

for r = 1:nRuns

    seed(r)=baseSeed+r;

    optimizer=CORALSuperstructureOptimizer( ...
        @simple_process_superstructure, ...
        nBinary, ...
        xBounds, ...
        'ReefSize',reefSize, ...
        'Seed',seed(r), ...
        'LocalRefinement',useLocalRefinement, ...
        'AdaptiveOperators',useAdaptiveOperators, ...
        'BleachingThreshold',0.15, ...
        'BleachingFraction',0.20);

    t0=tic;

    result=optimizer.optimize( ...
        'MaxIterations',maxIterations, ...
        'Patience',patience, ...
        'Verbose',false);

    runtime(r)=toc(t0);

    b=result.best;

    TAC(r)=b.f;
    violation(r)=b.v;
    feasible(r)=(b.v<=feasTol);
    topologyMatch(r)=isequal(b.y,yRef);

    gapPercent(r)=100*(b.f-fRef)/max(abs(fRef),1e-12);

    evaluations(r)=result.evaluations;
    iterations(r)=result.iterations;
    bestY(r,:)=b.y;
    bestX(r,:)=b.x;
    allHistory{r}=result.history.bestF;

    success(r)=feasible(r) && topologyMatch(r) && ...
               gapPercent(r)<=successGapPercent;

    fprintf(['run=%2d seed=%4d | feas=%d | TAC=%11.5f | gap=%7.3f%% | ', ...
             'topology=%d | eval=%6d | time=%7.3fs | success=%d\n'], ...
             r,seed(r),feasible(r),TAC(r),gapPercent(r), ...
             topologyMatch(r),evaluations(r),runtime(r),success(r));
end

%% Statistics
feasibleTAC=TAC(feasible);
feasibleGaps=gapPercent(feasible);

fprintf('\n============================================================\n');
fprintf('CORRECTED CORAL BENCHMARK SUMMARY\n');
fprintf('============================================================\n');
fprintf('Runs                         : %d\n',nRuns);
fprintf('Reference TAC                : %.10f\n',fRef);
fprintf('Feasible runs                : %d / %d (%.1f%%)\n', ...
    nnz(feasible),nRuns,100*mean(feasible));
fprintf('Reference topology recovered : %d / %d (%.1f%%)\n', ...
    nnz(topologyMatch),nRuns,100*mean(topologyMatch));
fprintf('Successful runs              : %d / %d (%.1f%%)\n', ...
    nnz(success),nRuns,100*mean(success));

if ~isempty(feasibleTAC)
    fprintf('\nFeasible TAC statistics:\n');
    fprintf('  Best     : %.10f\n',min(feasibleTAC));
    fprintf('  Median   : %.10f\n',median(feasibleTAC));
    fprintf('  Mean     : %.10f\n',mean(feasibleTAC));
    fprintf('  Worst    : %.10f\n',max(feasibleTAC));
    fprintf('  Std.dev. : %.10f\n',std(feasibleTAC));

    fprintf('\nFeasible relative gap statistics [%%]:\n');
    fprintf('  Best     : %.6f\n',min(feasibleGaps));
    fprintf('  Median   : %.6f\n',median(feasibleGaps));
    fprintf('  Mean     : %.6f\n',mean(feasibleGaps));
    fprintf('  Worst    : %.6f\n',max(feasibleGaps));
end

fprintf('\nComputational effort:\n');
fprintf('  Median evaluations : %.0f\n',median(evaluations));
fprintf('  Mean evaluations   : %.1f\n',mean(evaluations));
fprintf('  Median runtime [s] : %.4f\n',median(runtime));
fprintf('  Mean runtime [s]   : %.4f\n',mean(runtime));
fprintf('============================================================\n');

%% Results table
resultsTable=table( ...
    runNumber,seed,TAC,violation,feasible,topologyMatch,gapPercent, ...
    evaluations,runtime,iterations,success);

disp(resultsTable);

%% Topology frequency
topologyLabels=strings(nRuns,1);

for r=1:nRuns

    if bestY(r,1)==1
        R="CSTR";
    else
        R="PFR";
    end

    if bestY(r,3)==1
        S="Flash";
    else
        S="Distillation";
    end

    if bestY(r,5)==1
        Rec="Recycle";
    else
        Rec="NoRecycle";
    end

    topologyLabels(r)=R+"-"+S+"-"+Rec;
end

[G,topologyNames]=findgroups(topologyLabels);
frequency=splitapply(@numel,topologyLabels,G);

topologyFrequencyTable=table(topologyNames,frequency);
topologyFrequencyTable=sortrows(topologyFrequencyTable,'frequency','descend');

fprintf('\nTopology frequencies:\n');
disp(topologyFrequencyTable);

%% CSV export
writetable(resultsTable,'CORAL_benchmark_runs_fixed.csv');
writetable(topologyFrequencyTable,'CORAL_topology_frequencies_fixed.csv');
writetable(reference.table,'CORAL_reference_topologies_fixed.csv');

%% Figures
figure;
plot(runNumber,TAC,'o','LineWidth',1.2);
hold on;
yline(fRef,'--','Reference');
xlabel('Run');
ylabel('Best TAC');
title('CORAL repeated-run performance');
grid on;

figure;
bar(runNumber,gapPercent);
hold on;
yline(successGapPercent,'--','Success threshold');
xlabel('Run');
ylabel('Relative gap to corrected reference [%]');
title('CORAL relative optimality gap');
grid on;

figure;
hold on;

maxLen=max(cellfun(@numel,allHistory));

for r=1:nRuns
    h=allHistory{r};
    plot(0:numel(h)-1,h,'LineWidth',0.6);
end

yline(fRef,'--','Reference','LineWidth',1.5);
xlabel('Iteration');
ylabel('Best TAC');
title('CORAL convergence over repeated runs');
grid on;

H=nan(nRuns,maxLen);

for r=1:nRuns
    h=allHistory{r};
    H(r,1:numel(h))=h;

    if numel(h)<maxLen
        H(r,numel(h)+1:end)=h(end);
    end
end

medH=median(H,1,'omitnan');
q25=prctile(H,25,1);
q75=prctile(H,75,1);

figure;
xIter=0:maxLen-1;

fill([xIter fliplr(xIter)], ...
     [q25 fliplr(q75)], ...
     [0.85 0.85 0.85], ...
     'EdgeColor','none');

hold on;
plot(xIter,medH,'LineWidth',1.8);
yline(fRef,'--','Reference','LineWidth',1.5);

xlabel('Iteration');
ylabel('Best TAC');
title('Median CORAL convergence with interquartile band');
grid on;

fprintf('\nCorrected CSV files written:\n');
fprintf('  CORAL_benchmark_runs_fixed.csv\n');
fprintf('  CORAL_topology_frequencies_fixed.csv\n');
fprintf('  CORAL_reference_topologies_fixed.csv\n');
