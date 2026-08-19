function [TAC, violation, info] = simple_process_superstructure(y,x)
% Simple reactor-separator-recycle benchmark superstructure.
%
% y = [CSTR, PFR, Flash, Distillation, Recycle]
% x = [T, V, separator severity, recycle fraction]

    y=double(y>0.5);

    T=x(1);
    V=x(2);
    severity=x(3);
    r=x(4);

    logicViolation=0;
    logicViolation=logicViolation+abs((y(1)+y(2))-1);
    logicViolation=logicViolation+abs((y(3)+y(4))-1);

    if y(5)==0
        logicViolation=logicViolation+max(0,r-0.02);
        rEff=0;
    else
        rEff=r;
    end

    F0=100;
    k=0.035*exp(0.012*(T-330));

    if y(1)==1
        Xr=(k*V)/(1+k*V);
        reactorCapex=1200*V^0.62;
        reactorEnergy=8.0*max(T-330,0);
    elseif y(2)==1
        Xr=1-exp(-k*V);
        reactorCapex=1450*V^0.60;
        reactorEnergy=9.0*max(T-330,0);
    else
        Xr=0;
        reactorCapex=0;
        reactorEnergy=0;
    end

    Xoverall=1-(1-Xr)*(1-rEff);

    if y(3)==1
        recovery=min(0.92,0.55+0.40*severity);
        sepCapex=5500+5000*severity^1.4;
        sepEnergy=900*severity^1.6;
    elseif y(4)==1
        recovery=min(0.995,0.78+0.22*severity);
        sepCapex=10000+9000*severity^1.5;
        sepEnergy=1700*severity^1.7;
    else
        recovery=0;
        sepCapex=0;
        sepEnergy=0;
    end

    product=F0*Xoverall*recovery;

    recycleCost=2500*y(5)+3500*rEff^1.3;
    rawMaterialCost=12000*(1-0.25*rEff);
    annualCapex=0.18*(reactorCapex+sepCapex);
    utilityCost=25*(reactorEnergy+sepEnergy);
    productRevenue=220*product;

    TAC=annualCapex+rawMaterialCost+utilityCost+recycleCost-productRevenue;

    g1=max(0,75-product)/75;
    g2=max(0,0.80-Xoverall)/0.80;
    g3=max(0,T-430)/430;

    if y(3)==1
        g4=max(0,0.90-recovery)/0.90;
    else
        g4=0;
    end

    g5=max(0,rEff-0.75)/0.75;

    violation=logicViolation+g1+g2+g3+g4+g5;

    info.product=product;
    info.reactorConversion=Xr;
    info.overallConversion=Xoverall;
    info.recovery=recovery;
    info.annualCapex=annualCapex;
    info.utilityCost=utilityCost;
    info.rawMaterialCost=rawMaterialCost;
    info.recycleCost=recycleCost;
    info.productRevenue=productRevenue;
end
