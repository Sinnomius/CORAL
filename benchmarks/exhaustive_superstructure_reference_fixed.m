function reference = exhaustive_superstructure_reference_fixed(varargin)
% EXHAUSTIVE_SUPERSTRUCTURE_REFERENCE_FIXED
%
% Robust reference solver for the simple CORAL superstructure.
%
% Key fixes relative to the earlier version:
% 1. Uses a consistent feasibility tolerance.
% 2. Uses explicit nonlinear inequalities instead of only the aggregated
%    violation scalar returned by the toy model.
% 3. Uses multiple starts per topology.
% 4. Re-evaluates every candidate with the process model.
% 5. Selects the best topology by feasibility first, then objective value.
%
% Usage:
%   reference = exhaustive_superstructure_reference_fixed;
%
% Optional name-value arguments:
%   'Display'              default true
%   'MultiStartN'          default 20
%   'Seed'                 default 123
%   'FeasibilityTolerance' default 1e-5
%
% Requires Optimization Toolbox (fmincon).

    p = inputParser;
    addParameter(p,'Display',true);
    addParameter(p,'MultiStartN',20);
    addParameter(p,'Seed',123);
    addParameter(p,'FeasibilityTolerance',1e-5);
    parse(p,varargin{:});

    doDisplay = p.Results.Display;
    nStarts   = p.Results.MultiStartN;
    feasTol   = p.Results.FeasibilityTolerance;

    rng(p.Results.Seed,'twister');

    if exist('fmincon','file') ~= 2
        error('This reference solver requires fmincon (Optimization Toolbox).');
    end

    % x = [T, V, separator severity, recycle fraction]
    xLB = [320 0.5 0.0 0.0];
    xUB = [430 8.0 1.0 0.80];

    % Eight admissible topologies:
    % one reactor, one separator, recycle on/off.
    topologies = zeros(8,5);
    row = 0;

    for reactor = 1:2
        for separator = 1:2
            for recycle = 0:1
                row = row + 1;

                y = zeros(1,5);
                y(reactor) = 1;
                y(2 + separator) = 1;
                y(5) = recycle;

                topologies(row,:) = y;
            end
        end
    end

    template = struct( ...
        'y',[], ...
        'x',[], ...
        'f',inf, ...
        'v',inf, ...
        'feasible',false, ...
        'info',struct(), ...
        'exitflag',NaN, ...
        'runtime',NaN);

    results = repmat(template,size(topologies,1),1);

    options = optimoptions('fmincon', ...
        'Display','off', ...
        'Algorithm','sqp', ...
        'MaxIterations',500, ...
        'MaxFunctionEvaluations',5000, ...
        'OptimalityTolerance',1e-10, ...
        'StepTolerance',1e-12, ...
        'ConstraintTolerance',1e-9);

    for i = 1:size(topologies,1)

        y = topologies(i,:);
        t0 = tic;

        lb = xLB;
        ub = xUB;

        % If recycle is disabled, force recycle fraction to zero.
        if y(5)==0
            lb(4)=0;
            ub(4)=0;
        end

        best = template;
        best.y = y;

        % Center + corners near active constraints + random starts.
        starts = zeros(nStarts,4);
        starts(1,:) = 0.5*(lb+ub);

        if nStarts >= 2
            starts(2,:) = [335, 7.5, 0.90, min(0.70,ub(4))];
            starts(2,:) = min(max(starts(2,:),lb),ub);
        end

        if nStarts >= 3
            starts(3,:) = [345, 8.0, 0.95, min(0.75,ub(4))];
            starts(3,:) = min(max(starts(3,:),lb),ub);
        end

        for s = 4:nStarts
            starts(s,:) = lb + rand(1,4).*(ub-lb);
        end

        for s = 1:nStarts

            x0 = starts(s,:);

            obj = @(x) local_objective(y,x);
            nonlcon = @(x) explicit_constraints(y,x);

            try
                [xopt,~,exitflag] = fmincon( ...
                    obj,x0,[],[],[],[],lb,ub,nonlcon,options);

                [fcheck,vcheck,info] = simple_process_superstructure(y,xopt);

                candidate.y = y;
                candidate.x = xopt;
                candidate.f = fcheck;
                candidate.v = vcheck;
                candidate.feasible = (vcheck <= feasTol);
                candidate.info = info;
                candidate.exitflag = exitflag;
                candidate.runtime = NaN;

                if is_better(candidate,best,feasTol)
                    best = candidate;
                end

            catch
                % Try next start.
            end
        end

        % Fallback evaluation if all starts fail.
        if isempty(best.x)
            xmid = 0.5*(lb+ub);
            [fmid,vmid,infomid] = simple_process_superstructure(y,xmid);

            best.x = xmid;
            best.f = fmid;
            best.v = vmid;
            best.feasible = (vmid <= feasTol);
            best.info = infomid;
            best.exitflag = -999;
        end

        best.runtime = toc(t0);
        results(i) = best;
    end

    % Global best: feasibility first, then objective.
    bestIdx = 1;

    for i = 2:numel(results)
        if is_better(results(i),results(bestIdx),feasTol)
            bestIdx = i;
        end
    end

    reference.best = results(bestIdx);
    reference.all = results;
    reference.topologies = topologies;
    reference.feasibilityTolerance = feasTol;

    reactor = strings(numel(results),1);
    separator = strings(numel(results),1);
    recycle = zeros(numel(results),1);
    TAC = zeros(numel(results),1);
    violation = zeros(numel(results),1);
    feasible = false(numel(results),1);
    product = zeros(numel(results),1);

    for i = 1:numel(results)
        y = results(i).y;

        if y(1)==1
            reactor(i)="CSTR";
        else
            reactor(i)="PFR";
        end

        if y(3)==1
            separator(i)="Flash";
        else
            separator(i)="Distillation";
        end

        recycle(i)=y(5);
        TAC(i)=results(i).f;
        violation(i)=results(i).v;
        feasible(i)=results(i).feasible;
        product(i)=results(i).info.product;
    end

    reference.table = table( ...
        reactor,separator,recycle,TAC,violation,feasible,product);

    if doDisplay
        fprintf('\n============================================================\n');
        fprintf('ROBUST EXHAUSTIVE / FMINCON REFERENCE\n');
        fprintf('============================================================\n');
        fprintf('Feasibility tolerance = %.3e\n\n',feasTol);
        disp(reference.table);

        b = reference.best;

        fprintf('\nBest topology:\n');
        fprintf('  CSTR         = %d\n',b.y(1));
        fprintf('  PFR          = %d\n',b.y(2));
        fprintf('  Flash        = %d\n',b.y(3));
        fprintf('  Distillation = %d\n',b.y(4));
        fprintf('  Recycle      = %d\n',b.y(5));

        fprintf('\nBest TAC       = %.10f\n',b.f);
        fprintf('Violation      = %.3e\n',b.v);
        fprintf('Feasible       = %d\n',b.feasible);
        fprintf('x              = [%.6f %.6f %.6f %.6f]\n',b.x);
        fprintf('============================================================\n\n');
    end
end


function f = local_objective(y,x)
    [f,~,~] = simple_process_superstructure(y,x);
end


function [c,ceq] = explicit_constraints(y,x)
% Explicit process inequalities c(x)<=0.
%
% Matches the physics encoded in simple_process_superstructure,
% but avoids feeding fmincon a nonsmooth aggregated violation metric.

    y = double(y>0.5);

    T = x(1);
    V = x(2);
    severity = x(3);
    r = x(4);

    F0 = 100;
    k = 0.035*exp(0.012*(T-330));

    if y(1)==1
        Xr = (k*V)/(1+k*V);
    elseif y(2)==1
        Xr = 1-exp(-k*V);
    else
        Xr = 0;
    end

    if y(5)==1
        rEff = r;
    else
        rEff = 0;
    end

    Xoverall = 1-(1-Xr)*(1-rEff);

    if y(3)==1
        recovery = min(0.92,0.55+0.40*severity);
    elseif y(4)==1
        recovery = min(0.995,0.78+0.22*severity);
    else
        recovery = 0;
    end

    product = F0*Xoverall*recovery;

    c = [
        75 - product            % product >= 75
        0.80 - Xoverall        % conversion >= 0.80
        T - 430                % T <= 430
        rEff - 0.75            % recycle <= 0.75
    ];

    % Flash-specific recovery requirement.
    if y(3)==1
        c(end+1,1) = 0.90 - recovery;
    end

    ceq = [];
end


function tf = is_better(a,b,feasTol)

    aFeas = (~isempty(a.x)) && (a.v <= feasTol);
    bFeas = (~isempty(b.x)) && (b.v <= feasTol);

    if aFeas && ~bFeas
        tf = true;
    elseif ~aFeas && bFeas
        tf = false;
    elseif ~aFeas && ~bFeas
        tf = a.v < b.v;
    else
        tf = a.f < b.f;
    end
end
