function animate_CORAL_reef(result,varargin)
% ANIMATE_CORAL_REEF  Animate CORAL reef evolution.
%
% Marker color = topology/species
% Marker size  = relative objective quality
% Filled       = feasible coral
% Open         = infeasible coral
% Green ring   = new settlement/budding
% Red X        = depredation/bleaching
%
% Example:
% animate_CORAL_reef(result,'FramePause',0.12,'SaveVideo',true);

    p=inputParser;
    addParameter(p,'FramePause',0.15);
    addParameter(p,'FrameStep',1);
    addParameter(p,'SaveVideo',false);
    addParameter(p,'VideoFile','CORAL_reef_growth.mp4');
    addParameter(p,'SaveGIF',false);
    addParameter(p,'GIFFile','CORAL_reef_growth.gif');
    addParameter(p,'ShowEvents',true);
    parse(p,varargin{:});

    if ~isfield(result,'reefHistory') || isempty(result.reefHistory)
        error('No reef history found. Run with RecordReefHistory=true.');
    end

    reefHistory=result.reefHistory;
    if isfield(result,'eventHistory')
        eventHistory=result.eventHistory;
    else
        eventHistory={};
    end

    reefSize=numel(reefHistory{1}.occupied);
    nCols=ceil(sqrt(reefSize));
    nRows=ceil(reefSize/nCols);
    [gx,gy]=meshgrid(1:nCols,1:nRows);
    gx=gx(:); gy=gy(:);
    gx=gx(1:reefSize); gy=gy(1:reefSize);

    topologyKeys=strings(0,1);
    for k=1:numel(reefHistory)
        snap=reefHistory{k};
        occ=find(snap.occupied);
        for q=1:numel(occ)
            key=topologyKey(snap.y(occ(q),:));
            if ~any(topologyKeys==key)
                topologyKeys(end+1,1)=key; %#ok<AGROW>
            end
        end
    end

    cmap=lines(max(1,numel(topologyKeys)));

    fig=figure('Name','CORAL reef growth','Color','w');
    ax=axes(fig);

    if p.Results.SaveVideo
        vid=VideoWriter(p.Results.VideoFile,'MPEG-4');
        vid.FrameRate=max(1,round(1/max(p.Results.FramePause,0.02)));
        open(vid);
    else
        vid=[];
    end

    gifFirst=true;
    frames=1:p.Results.FrameStep:numel(reefHistory);
    if frames(end)~=numel(reefHistory)
        frames(end+1)=numel(reefHistory);
    end

    for kk=1:numel(frames)
        idx=frames(kk);
        snap=reefHistory{idx};

        cla(ax);
        hold(ax,'on');
        scatter(ax,gx,gy,230,[0.94 0.94 0.94],'filled', ...
            'MarkerEdgeColor',[0.82 0.82 0.82]);

        occ=find(snap.occupied);
        if isempty(occ)
            bestF=NaN;
        else
            ff=snap.f(occ);
            bestF=min(ff(isfinite(ff)));
        end

        if ~isempty(occ)
            ff=snap.f(occ);
            finite=ff(isfinite(ff));
            if isempty(finite)
                fmin=0; fmax=1;
            else
                fmin=min(finite); fmax=max(finite);
            end

            for s=1:numel(topologyKeys)
                ids=[];
                for q=1:numel(occ)
                    if topologyKey(snap.y(occ(q),:))==topologyKeys(s)
                        ids(end+1)=occ(q); %#ok<AGROW>
                    end
                end
                if isempty(ids), continue; end

                sizes=zeros(size(ids));
                for q=1:numel(ids)
                    fv=snap.f(ids(q));
                    if ~isfinite(fv) || fmax==fmin
                        quality=0.5;
                    else
                        quality=1-(fv-fmin)/(fmax-fmin);
                    end
                    sizes(q)=90+180*quality;
                end

                feas=snap.feasible(ids);
                if any(feas)
                    scatter(ax,gx(ids(feas)),gy(ids(feas)),sizes(feas), ...
                        repmat(cmap(s,:),sum(feas),1),'filled', ...
                        'MarkerEdgeColor',[0.15 0.15 0.15], ...
                        'DisplayName',char(topologyKeys(s)));
                end
                if any(~feas)
                    scatter(ax,gx(ids(~feas)),gy(ids(~feas)),sizes(~feas), ...
                        repmat(cmap(s,:),sum(~feas),1), ...
                        'MarkerEdgeColor',cmap(s,:),'LineWidth',1.5, ...
                        'DisplayName',[char(topologyKeys(s)) ' infeasible']);
                end
            end
        end

        eventText='';
        if p.Results.ShowEvents && ~isempty(eventHistory) && idx<=numel(eventHistory)
            ev=eventHistory{idx};
            greenCells=unique([ev.settlementCells ev.buddingCells]);
            redCells=unique([ev.depredationCells ev.bleachedCells]);

            if ~isempty(greenCells)
                scatter(ax,gx(greenCells),gy(greenCells),330,'o', ...
                    'MarkerEdgeColor',[0 0.55 0.1],'LineWidth',2);
            end
            if ~isempty(redCells)
                scatter(ax,gx(redCells),gy(redCells),180,'x', ...
                    'MarkerEdgeColor',[0.75 0 0],'LineWidth',2);
            end

            if ev.bleachingTriggered
                eventText=' | BLEACHING / RECOLONIZATION';
            elseif ~isempty(ev.depredationCells)
                eventText=' | depredation';
            elseif ~isempty(greenCells)
                eventText=' | settlement';
            end
        end

        title(ax,sprintf('CORAL reef - iteration %d | occupied %d/%d | best f = %.5g%s', ...
            snap.iteration,numel(occ),reefSize,bestF,eventText));

        axis(ax,'equal');
        axis(ax,[0.4 nCols+0.6 0.4 nRows+0.6]);
        set(ax,'YDir','reverse','XTick',1:nCols,'YTick',1:nRows);
        xlabel(ax,'Reef column');
        ylabel(ax,'Reef row');
        box(ax,'on');

        if numel(topologyKeys)<=8
            legend(ax,'Location','eastoutside');
        end

        drawnow;
        frame=getframe(fig);

        if p.Results.SaveVideo
            writeVideo(vid,frame);
        end

        if p.Results.SaveGIF
            [im,map]=rgb2ind(frame2im(frame),256);
            if gifFirst
                imwrite(im,map,p.Results.GIFFile,'gif','Loopcount',inf, ...
                    'DelayTime',p.Results.FramePause);
                gifFirst=false;
            else
                imwrite(im,map,p.Results.GIFFile,'gif','WriteMode','append', ...
                    'DelayTime',p.Results.FramePause);
            end
        end

        pause(p.Results.FramePause);
    end

    if p.Results.SaveVideo
        close(vid);
        fprintf('Saved video: %s\n',p.Results.VideoFile);
    end
    if p.Results.SaveGIF
        fprintf('Saved GIF: %s\n',p.Results.GIFFile);
    end
end

function key=topologyKey(y)
    y=double(y(:)'>0.5);
    key=join(string(y),'');
end
