classdef CORALSuperstructureOptimizer < handle
    % Mixed-variable coral-inspired optimizer for process superstructures.

    properties
        ModelFcn
        XBounds
        NBinary
        NContinuous
        ReefSize = 80
        InitialOccupancy = 0.75
        SettlementAttempts = 4
        BroadcastFraction = 0.45
        BroodingFraction = 0.20
        TopologyMutationFraction = 0.15
        DifferentialFraction = 0.10
        BuddingFraction = 0.10
        DepredationFraction = 0.10
        DepredationProbability = 0.20
        MutationScale = 0.12
        TopologyMutationRate = 0.12
        DiversityWeight = 0.15
        NicheRadius = 1
        BleachingThreshold = 0.18
        BleachingFraction = 0.25
        LocalRefinement = true
        LocalRefineProbability = 0.20
        AdaptiveOperators = true
        OperatorLearningRate = 0.20
        Seed = []
    end

    properties (SetAccess = private)
        Lower
        Upper
        Span
        Evaluations = 0
        OperatorProbabilities
        OperatorSuccess
        OperatorTrials
    end

    methods
        function obj = CORALSuperstructureOptimizer(modelFcn, nBinary, xBounds, varargin)
            if ~isa(modelFcn,'function_handle')
                error('modelFcn must be a function handle.');
            end
            if ~ismatrix(xBounds) || size(xBounds,2) ~= 2
                error('xBounds must be N-by-2.');
            end
            if any(xBounds(:,1) >= xBounds(:,2))
                error('Each lower bound must be below its upper bound.');
            end

            obj.ModelFcn = modelFcn;
            obj.NBinary = nBinary;
            obj.XBounds = xBounds;
            obj.NContinuous = size(xBounds,1);

            p = inputParser;
            addParameter(p,'ReefSize',obj.ReefSize);
            addParameter(p,'InitialOccupancy',obj.InitialOccupancy);
            addParameter(p,'SettlementAttempts',obj.SettlementAttempts);
            addParameter(p,'BroadcastFraction',obj.BroadcastFraction);
            addParameter(p,'BroodingFraction',obj.BroodingFraction);
            addParameter(p,'TopologyMutationFraction',obj.TopologyMutationFraction);
            addParameter(p,'DifferentialFraction',obj.DifferentialFraction);
            addParameter(p,'BuddingFraction',obj.BuddingFraction);
            addParameter(p,'DepredationFraction',obj.DepredationFraction);
            addParameter(p,'DepredationProbability',obj.DepredationProbability);
            addParameter(p,'MutationScale',obj.MutationScale);
            addParameter(p,'TopologyMutationRate',obj.TopologyMutationRate);
            addParameter(p,'DiversityWeight',obj.DiversityWeight);
            addParameter(p,'NicheRadius',obj.NicheRadius);
            addParameter(p,'BleachingThreshold',obj.BleachingThreshold);
            addParameter(p,'BleachingFraction',obj.BleachingFraction);
            addParameter(p,'LocalRefinement',obj.LocalRefinement);
            addParameter(p,'LocalRefineProbability',obj.LocalRefineProbability);
            addParameter(p,'AdaptiveOperators',obj.AdaptiveOperators);
            addParameter(p,'OperatorLearningRate',obj.OperatorLearningRate);
            addParameter(p,'Seed',obj.Seed);
            parse(p,varargin{:});

            names = fieldnames(p.Results);
            for k = 1:numel(names)
                obj.(names{k}) = p.Results.(names{k});
            end

            obj.Lower = xBounds(:,1)';
            obj.Upper = xBounds(:,2)';
            obj.Span = obj.Upper - obj.Lower;

            if ~isempty(obj.Seed)
                rng(obj.Seed,'twister');
            end

            probs = [obj.BroadcastFraction obj.BroodingFraction ...
                     obj.TopologyMutationFraction obj.DifferentialFraction];
            obj.OperatorProbabilities = probs/sum(probs);
            obj.OperatorSuccess = zeros(1,4);
            obj.OperatorTrials = zeros(1,4);
        end

        function result = optimize(obj,varargin)
            p = inputParser;
            addParameter(p,'MaxIterations',250);
            addParameter(p,'Patience',60);
            addParameter(p,'Verbose',true);
            parse(p,varargin{:});

            maxIterations = p.Results.MaxIterations;
            patience = p.Results.Patience;
            verbose = p.Results.Verbose;

            obj.Evaluations = 0;
            obj.OperatorSuccess(:) = 0;
            obj.OperatorTrials(:) = 0;

            reef = repmat(obj.emptyCoral(),obj.ReefSize,1);
            occupied = false(obj.ReefSize,1);

            nInit = max(2,round(obj.InitialOccupancy*obj.ReefSize));
            cells = randperm(obj.ReefSize,nInit);

            for k = 1:nInit
                c = obj.evaluateCoral(obj.randomCoral());
                reef(cells(k)) = c;
                occupied(cells(k)) = true;
            end

            best = obj.getBest(reef,occupied);
            lastBest = best;
            stagnant = 0;

            histF = nan(maxIterations+1,1);
            histV = nan(maxIterations+1,1);
            histD = nan(maxIterations+1,1);
            histO = nan(maxIterations+1,1);

            histF(1)=best.f;
            histV(1)=best.v;
            histD(1)=obj.populationDiversity(reef,occupied);
            histO(1)=nnz(occupied);

            for it = 1:maxIterations
                scale = obj.MutationScale*(0.03^(it/maxIterations));

                if nnz(occupied) < 4
                    [reef,occupied] = obj.recolonize(reef,occupied,4);
                end

                occ = find(occupied);
                nLarvae = max(4,round(0.85*numel(occ)));

                for ell = 1:nLarvae
                    op = obj.selectOperator();

                    switch op
                        case 1
                            larva = obj.makeBroadcastLarva(reef,occ,scale);
                        case 2
                            larva = obj.makeBroodingLarva(reef,occ,scale);
                        case 3
                            larva = obj.makeTopologyLarva(reef,occ,scale);
                        otherwise
                            larva = obj.makeDifferentialLarva(reef,occ);
                    end

                    larva = obj.repairTopology(larva);
                    larva = obj.evaluateCoral(larva);

                    if obj.LocalRefinement && rand < obj.LocalRefineProbability
                        larva = obj.localRefine(larva);
                    end

                    obj.OperatorTrials(op)=obj.OperatorTrials(op)+1;
                    [reef,occupied,settled] = obj.settleLarva(larva,reef,occupied);
                    if settled
                        obj.OperatorSuccess(op)=obj.OperatorSuccess(op)+1;
                    end
                end

                occ = find(occupied);
                ranked = obj.rankCorals(reef,occ);
                nBuds = max(1,round(obj.BuddingFraction*numel(ranked)));

                for k = 1:min(nBuds,numel(ranked))
                    bud = reef(ranked(k));
                    bud.x = obj.repairX(bud.x + 0.25*scale.*obj.Span.*randn(1,obj.NContinuous));
                    bud = obj.evaluateCoral(bud);
                    if obj.LocalRefinement && rand < obj.LocalRefineProbability
                        bud = obj.localRefine(bud);
                    end
                    [reef,occupied] = obj.settleLarva(bud,reef,occupied);
                end

                [reef,occupied] = obj.depredate(reef,occupied);

                if obj.populationDiversity(reef,occupied) < obj.BleachingThreshold
                    [reef,occupied] = obj.bleachAndRecover(reef,occupied);
                end

                if obj.AdaptiveOperators && mod(it,10)==0
                    obj.updateOperatorProbabilities();
                end

                currentBest = obj.getBest(reef,occupied);
                if obj.isBetter(currentBest,best)
                    best = currentBest;
                end

                if obj.sameQuality(best,lastBest)
                    stagnant = stagnant+1;
                else
                    stagnant = 0;
                    lastBest = best;
                end

                histF(it+1)=best.f;
                histV(it+1)=best.v;
                histD(it+1)=obj.populationDiversity(reef,occupied);
                histO(it+1)=nnz(occupied);

                if verbose && (it==1 || mod(it,10)==0)
                    fprintf(['it=%4d | feas=%d | f=%10.5f | v=%9.3e | ', ...
                             'div=%5.3f | occ=%3d | ops=[%.2f %.2f %.2f %.2f]\n'], ...
                             it,best.feasible,best.f,best.v,histD(it+1),nnz(occupied), ...
                             obj.OperatorProbabilities(1),obj.OperatorProbabilities(2), ...
                             obj.OperatorProbabilities(3),obj.OperatorProbabilities(4));
                end

                if stagnant >= patience
                    break;
                end
            end

            result.best = best;
            result.iterations = it;
            result.evaluations = obj.Evaluations;
            result.history.bestF = histF(1:it+1);
            result.history.bestV = histV(1:it+1);
            result.history.diversity = histD(1:it+1);
            result.history.occupancy = histO(1:it+1);
            result.operatorProbabilities = obj.OperatorProbabilities;
        end
    end

    methods (Access=private)
        function c = emptyCoral(obj)
            c.y = zeros(1,obj.NBinary);
            c.x = zeros(1,obj.NContinuous);
            c.f = inf;
            c.v = inf;
            c.feasible = false;
            c.info = struct();
        end

        function c = randomCoral(obj)
            c = obj.emptyCoral();
            c.y = double(rand(1,obj.NBinary)<0.5);
            c.x = obj.Lower + rand(1,obj.NContinuous).*obj.Span;
            c = obj.repairTopology(c);
        end

        function c = repairTopology(obj,c)
            if all(c.y==0)
                c.y(randi(obj.NBinary))=1;
            end
            c.y = double(c.y>0.5);
            c.x = obj.repairX(c.x);
        end

        function x = repairX(obj,x)
            z = mod(x-obj.Lower,2.*obj.Span);
            x = obj.Lower + z;
            mask = z>obj.Span;
            x(mask) = obj.Upper(mask) - (z(mask)-obj.Span(mask));
            x = min(max(x,obj.Lower),obj.Upper);
        end

        function c = evaluateCoral(obj,c)
            [f,v,info] = obj.ModelFcn(c.y,c.x);
            obj.Evaluations = obj.Evaluations+1;
            if ~isfinite(f), f=1e12; end
            if ~isfinite(v), v=1e12; end
            c.f=f;
            c.v=max(0,v);
            c.feasible=(c.v<=1e-6);
            c.info=info;
        end

        function op = selectOperator(obj)
            r=rand;
            cs=cumsum(obj.OperatorProbabilities);
            op=find(r<=cs,1,'first');
        end

        function larva = makeBroadcastLarva(obj,reef,occ,scale)
            ids=occ(randperm(numel(occ),2));
            a=reef(ids(1));
            b=reef(ids(2));
            larva=obj.emptyCoral();

            mask=rand(1,obj.NBinary)<0.5;
            larva.y=b.y;
            larva.y(mask)=a.y(mask);

            alpha=rand(1,obj.NContinuous);
            larva.x=alpha.*a.x+(1-alpha).*b.x;
            larva.x=obj.repairX(larva.x+0.5*scale.*obj.Span.*randn(1,obj.NContinuous));
        end

        function larva = makeBroodingLarva(obj,reef,occ,scale)
            larva=reef(occ(randi(numel(occ))));
            larva.x=obj.repairX(larva.x+scale.*obj.Span.*randn(1,obj.NContinuous));
            flip=rand(1,obj.NBinary)<0.02;
            larva.y(flip)=1-larva.y(flip);
        end

        function larva = makeTopologyLarva(obj,reef,occ,scale)
            larva=reef(occ(randi(numel(occ))));
            flip=rand(1,obj.NBinary)<obj.TopologyMutationRate;
            if ~any(flip), flip(randi(obj.NBinary))=true; end
            larva.y(flip)=1-larva.y(flip);
            larva.x=obj.repairX(larva.x+0.5*scale.*obj.Span.*randn(1,obj.NContinuous));
        end

        function larva = makeDifferentialLarva(obj,reef,occ)
            ids=occ(randperm(numel(occ),3));
            a=reef(ids(1)); b=reef(ids(2)); c=reef(ids(3));
            F=0.5+0.3*rand;
            larva=a;
            larva.x=obj.repairX(a.x+F*(b.x-c.x));
            if rand<0.25
                j=randi(obj.NBinary);
                larva.y(j)=1-larva.y(j);
            end
        end

        function c = localRefine(obj,c)
            if exist('fmincon','file')~=2
                return;
            end

            yFixed=c.y;
            fun=@(x)obj.penalizedObjective(yFixed,x);
            options=optimoptions('fmincon','Display','off','Algorithm','sqp', ...
                'MaxIterations',40,'MaxFunctionEvaluations',250);

            try
                xnew=fmincon(fun,c.x,[],[],[],[],obj.Lower,obj.Upper,[],options);
                r=c;
                r.x=xnew;
                r=obj.evaluateCoral(r);
                if obj.isBetter(r,c), c=r; end
            catch
            end
        end

        function val = penalizedObjective(obj,y,x)
            [f,v,~]=obj.ModelFcn(y,x);
            val=f+1e5*v+1e6*v.^2;
        end

        function [reef,occupied,settled]=settleLarva(obj,larva,reef,occupied)
            settled=false;

            for k=1:obj.SettlementAttempts
                idx=randi(obj.ReefSize);

                if ~occupied(idx)
                    reef(idx)=larva;
                    occupied(idx)=true;
                    settled=true;
                    return;
                end

                resident=reef(idx);
                d=obj.hammingDistance(larva.y,resident.y);

                if obj.isBetter(larva,resident)
                    reef(idx)=larva;
                    settled=true;
                    return;
                elseif d>obj.NicheRadius && obj.similarQuality(larva,resident)
                    if rand<obj.DiversityWeight
                        reef(idx)=larva;
                        settled=true;
                        return;
                    end
                end
            end
        end

        function tf=isBetter(~,a,b)
            if a.feasible && ~b.feasible
                tf=true;
            elseif ~a.feasible && b.feasible
                tf=false;
            elseif ~a.feasible && ~b.feasible
                tf=a.v<b.v;
            else
                tf=a.f<b.f;
            end
        end

        function tf=similarQuality(~,a,b)
            if a.feasible && b.feasible
                tf=abs(a.f-b.f)/max(1,abs(b.f))<0.03;
            elseif ~a.feasible && ~b.feasible
                tf=abs(a.v-b.v)/max(1,abs(b.v))<0.10;
            else
                tf=false;
            end
        end

        function tf=sameQuality(~,a,b)
            tf=(a.feasible==b.feasible) && abs(a.f-b.f)<1e-8 && abs(a.v-b.v)<1e-8;
        end

        function ranked=rankCorals(obj,reef,occ)
            score=zeros(numel(occ),1);
            for k=1:numel(occ)
                c=reef(occ(k));
                if c.feasible
                    score(k)=c.f;
                else
                    score(k)=1e8+1e6*c.v+c.f;
                end
            end
            [~,ord]=sort(score,'ascend');
            ranked=occ(ord);
        end

        function best=getBest(obj,reef,occupied)
            occ=find(occupied);
            ranked=obj.rankCorals(reef,occ);
            best=reef(ranked(1));
        end

        function [reef,occupied]=depredate(obj,reef,occupied)
            occ=find(occupied);
            if numel(occ)<=3, return; end
            ranked=obj.rankCorals(reef,occ);
            n=max(1,round(obj.DepredationFraction*numel(ranked)));
            worst=ranked(end-n+1:end);
            for k=1:numel(worst)
                if rand<obj.DepredationProbability
                    occupied(worst(k))=false;
                end
            end
        end

        function d=hammingDistance(~,y1,y2)
            d=sum(y1~=y2);
        end

        function div=populationDiversity(obj,reef,occupied)
            occ=find(occupied);
            if numel(occ)<2
                div=0; return;
            end
            total=0; count=0;
            for i=1:numel(occ)-1
                for j=i+1:numel(occ)
                    total=total+obj.hammingDistance(reef(occ(i)).y,reef(occ(j)).y);
                    count=count+1;
                end
            end
            div=total/(count*max(1,obj.NBinary));
        end

        function [reef,occupied]=bleachAndRecover(obj,reef,occupied)
            occ=find(occupied);
            if numel(occ)<4
                [reef,occupied]=obj.recolonize(reef,occupied,4);
                return;
            end

            ranked=obj.rankCorals(reef,occ);
            start=max(2,round(numel(ranked)/2));
            pool=ranked(start:end);
            n=min(max(1,round(obj.BleachingFraction*numel(ranked))),numel(pool));
            if n>0
                ids=pool(randperm(numel(pool),n));
                occupied(ids)=false;
            end

            empties=find(~occupied);
            for k=1:numel(empties)
                c=obj.evaluateCoral(obj.randomCoral());
                reef(empties(k))=c;
                occupied(empties(k))=true;
            end
        end

        function [reef,occupied]=recolonize(obj,reef,occupied,minCount)
            while nnz(occupied)<minCount
                idx=find(~occupied,1,'first');
                c=obj.evaluateCoral(obj.randomCoral());
                reef(idx)=c;
                occupied(idx)=true;
            end
        end

        function updateOperatorProbabilities(obj)
            rate=(obj.OperatorSuccess+1)./(obj.OperatorTrials+2);
            target=rate/sum(rate);
            obj.OperatorProbabilities=(1-obj.OperatorLearningRate)*obj.OperatorProbabilities + ...
                                      obj.OperatorLearningRate*target;
            obj.OperatorProbabilities=max(obj.OperatorProbabilities,0.08);
            obj.OperatorProbabilities=obj.OperatorProbabilities/sum(obj.OperatorProbabilities);
            obj.OperatorSuccess(:)=0;
            obj.OperatorTrials(:)=0;
        end
    end
end
