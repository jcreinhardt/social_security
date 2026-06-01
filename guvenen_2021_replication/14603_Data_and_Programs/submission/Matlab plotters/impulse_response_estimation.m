clear; close all; clc;

user=3;		% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
mean=1;		% =1-normalization with mean
			% =0-normalization with median
write_excel=0;			% =1 update excel file
filename='impulse_moments_est';

npast=8; ncur=23;

% Defaults for plots
ftsize=20;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); set(0,'defaultLineMarkerSize',10);
set(0,'defaultlinelinewidth',2); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',22); lfsize=20;
mfcolor = [1 0.6 0.78; 0 1 1; 0.00 1.00 0.00; 0.8 0.8 0.8; 1.00 0.50 0.25; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0 0 1; 0.11 0.53 0.10; 0.0 0.0 0.0; 0.63 0.57 0.39; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor; %[0   1   0; 0 0 1; 0.99 0.53 0.06; 0.5 0.5 0.5; 1 0 0;  0    0    0; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
% colors = [0 0 1; 0 1 0; 1 0 0; 0.8 0.7 0.6; 0 0 0; 0 0.7 0.7; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.03; mrg_btm=0.115; mrg_lft=0.12;

folder=char('1_Feb_2016_ImpulseResponse_labor_estimation');
if(user==1) % serdar
    userdirectory=char('/a/foflx1/lcl/fof/research1/SERDAR/SSA-INCOME-RISK/EmpiricalResults/ImpulseResponse/');
	sep=char('/');
elseif(user==2) % f. karahan ny fed
    userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\ImpulseResponse\');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\subaxis');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
elseif(user==3) % f. karahan mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/ImpulseResponse/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
end
input  = [userdirectory 'Input' sep folder sep];
cd(input);

output = [userdirectory 'Output' sep 'Estimation'];
filename=[userdirectory 'Output' sep filename];
if mean==1
	K=importdata('impulseA_mean.txt');
	suf='mean';
elseif mean==0
	K=importdata('impulseA_med.txt');
	suf='median';
else
	disp('Wrong choice of mean')
	stop
end
results=K.data;
cd(output);

%% Fix an agebin, plot for income group 4 (31-50, normalized)
agebin=2; incrank=4; mod_ind=12;
j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
xx=-2:0.05:2; permy=0*xx; transity=-xx;

h=figure;
subaxis(1,1,1,'Margin',mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
xdata=results(j+1:j+ncur,4)-results(j+mod_ind,4);
data=xdata;
for l=1:5
	ydata=results(j+1:j+ncur,4+l)-results(j+mod_ind,4+l)-xdata;
	plot(xdata,ydata,style(l,:),'Color',colors(l,:),'MarkerFaceColor',mfcolor(l,:),...
		'MarkerEdgeColor',mecolor(l,:))
    data=[data ydata]; %#ok<*AGROW>
end
xlabel('$E[\Delta^{1}_{arc}Y^{i}_{t-1}]$')
ylabel('$E[\Delta^{k+1}_{arc}Y^{i}_{t-1} | \Delta^{1}_{arc}Y^{i}_{t-1}] - E[\Delta^{1}_{arc}Y^{i}_{t-1}]$'); axis([-2,2,-2,2]);
leg=legend('k=1','k=2','k=3','k=5','k=10','Location','NorthEast','AutoUpdate','off'); set(leg,'FontSize',lfsize);
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2);
annotation(figure(h),'textarrow',[0.275659824046921 0.275048931607254],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',18,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.384467253176931],...
    [0.85 0.74],'TextEdgeColor','none','FontWeight','bold','linewidth',1,'FontSize',18,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');
if agebin==1
	name = ['ImpResp_Median_young_norm_est_' suf];
    name2 = char(['ImpResp_Median_young_est_' suf]);
else
	name = ['ImpResp_Median_primeage_norm_est_' suf];
    name2 = char(['ImpResp_Median_prime_est_' suf]);
end
set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
xSize=9; ySize=8; xLeft = (21-xSize)/2; yTop = (30-ySize)/2;
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');


if write_excel==1
	tbl1 = table({'Shock size','Income change in k=1 years','Income change in k=2 years',...
		'Income change in k=3 years','Income change in k=5 years','Income change in k=10 years'});
	tbl2 = table({'P1-P2';'P3-P5';'P6-P10';'P11-P15';'P16-P20';'P21-P25';'P26-P30';...
		'P31-P35';'P36-P40';'P41-P45';'P46-P50';'P51-P55';'P56-P60';'P61-P65';...
		'P66-P70';'P71-P75';'P76-P80';'P81-P85';'P86-P90';'P91-P95';'P96-P98';'P99';'P100'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name2,'Range','B3','WriteVariableNames',false);
end

%% Fix an agebin and plot for 91-95th percentiles
agebin=2; incrank=7; mod_ind=12;
j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
xx=-2:0.05:2; permy=0*xx; transity=-xx;

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
xdata=results(j+1:j+ncur,4)-results(j+mod_ind,4);
data=xdata;
for l=1:5
	ydata=results(j+1:j+ncur,4+l)-results(j+mod_ind,4+l)-xdata;
	plot(xdata,ydata,style(l,:),'Color',colors(l,:),'MarkerFaceColor',mfcolor(l,:),...
		'MarkerEdgeColor',mecolor(l,:))
    data=[data ydata];
end
xlabel('$E[\Delta^{1}_{arc}Y^{i}_{t-1}]$')
ylabel('$E[\Delta^{k+1}_{arc}Y^{i}_{t-1} | \Delta^{1}_{arc}Y^{i}_{t-1}] - E[\Delta^{1}_{arc}Y^{i}_{t-1}]$'); axis([-2,2,-2,2]);
leg=legend('k=1','k=2','k=3','k=5','k=10','Location','NorthEast','AutoUpdate','off'); set(leg,'FontSize',lfsize);
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2);

annotation(figure(h),'textarrow',[0.275659824046921 0.275659824046921],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',18,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.414467253176931],...
    [0.779942528735632 0.715287356321839],'TextEdgeColor','none','FontSize',18,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');
set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
xSize=9; ySize=8; xLeft = (21-xSize)/2; yTop = (30-ySize)/2;
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])
if agebin==1
	name = ['ImpResp_90thPct_young_norm_est_' suf];
    name2 = char(['ImpResp_90thPct_young_est_' suf]);
else
	name = ['ImpResp_90thPct_primeage_norm_est_' suf];
    name2 = char(['ImpResp_90thPct_prime_est_' suf]);
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');


if write_excel==1
	tbl1 = table({'Shock size','Income change in k=1 years','Income change in k=2 years',...
		'Income change in k=3 years','Income change in k=5 years','Income change in k=10 years'});
	tbl2 = table({'P1-P2';'P3-P5';'P6-P10';'P11-P15';'P16-P20';'P21-P25';'P26-P30';...
		'P31-P35';'P36-P40';'P41-P45';'P46-P50';'P51-P55';'P56-P60';'P61-P65';...
		'P66-P70';'P71-P75';'P76-P80';'P81-P85';'P86-P90';'P91-P95';'P96-P98';'P99';'P100'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name2,'Range','B3','WriteVariableNames',false);
end

%% Fix an agebin and plot for 6-10th percentile
agebin=2; incrank=2; mod_ind=12;
j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
xx=-2:0.05:2; permy=0*xx; transity=-xx;

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
xdata=results(j+1:j+ncur,4)-results(j+mod_ind,4);
data=xdata;
for l=1:5
	ydata=results(j+1:j+ncur,4+l)-results(j+mod_ind,4+l)-xdata;
	plot(xdata,ydata,style(l,:),'Color',colors(l,:),'MarkerFaceColor',mfcolor(l,:),...
		'MarkerEdgeColor',mecolor(l,:))
    data=[data ydata];
end
xlabel('$E[\Delta^{1}_{arc}Y^{i}_{t-1}]$')
ylabel('$E[\Delta^{k+1}_{arc}Y^{i}_{t-1} | \Delta^{1}_{arc}Y^{i}_{t-1}] - E[\Delta^{1}_{arc}Y^{i}_{t-1}]$'); axis([-2,2,-2,2]);
leg=legend('k=1','k=2','k=3','k=5','k=10','Location','NorthEast','AutoUpdate','off'); set(leg,'FontSize',lfsize);
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2);
annotation(figure(h),'textarrow',[0.275659824046921 0.275659824046921],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',18,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.414467253176931],...
    [0.779942528735632 0.715287356321839],'TextEdgeColor','none','FontSize',18,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
xSize=9; ySize=8; xLeft = (21-xSize)/2; yTop = (30-ySize)/2;
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])
if agebin==1
	name = ['ImpResp_10thPct_young_norm_est_' suf];
    name2 = char(['ImpResp_10thPct_young_' suf]);
else
	name = ['ImpResp_10thPct_primeage_norm_est_' suf];
    name2 = char(['ImpResp_10thPct_prime_est_' suf]);
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');


if write_excel==1
	tbl1 = table({'Shock size','Income change in k=1 years','Income change in k=2 years',...
		'Income change in k=3 years','Income change in k=5 years','Income change in k=10 years'});
	tbl2 = table({'P1-P2';'P3-P5';'P6-P10';'P11-P15';'P16-P20';'P21-P25';'P26-P30';...
		'P31-P35';'P36-P40';'P41-P45';'P46-P50';'P51-P55';'P56-P60';'P61-P65';...
		'P66-P70';'P71-P75';'P76-P80';'P81-P85';'P86-P90';'P91-P95';'P96-P98';'P99';'P100'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name2,'Range','B3','WriteVariableNames',false);
end

%% Fix an agebin and future change. Plot butterfly (normalized)
agebin=2; F10=1; mod_ind=12;
xx=-2:0.05:2; permy=0*xx; transity=-xx;

% xdata=results(j+1:j+ncur,4)-results(j+mod_ind,4);
h=figure;
subaxis(1,1,1,'Margin',mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
indinc=[1 3 4 5 6 8]; data=[];
for i=1:length(indinc)
	incrank=indinc(i);
	j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
	resultsMODx = results(j+1:j+ncur,4)-results(j+mod_ind,4);
	resultsMODy = results(j+1:j+ncur,8+F10)-results(j+mod_ind,8+F10)-resultsMODx;
	plot(resultsMODx,resultsMODy,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),...
		'MarkerEdgeColor',mecolor(i,:))
    data=[data resultsMODx resultsMODy];
end
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2);
axis([-2,2,-2,2]); set(gca,'YTick',-2:0.5:2); set(gca,'YTick',-2:0.5:2);
if F10==1
    ylabel('$E[\Delta^{11}_{arc}Y^{i}_{t-1} | \Delta^{1}_{arc}Y^{i}_{t-1}] - E[\Delta^{1}_{arc}Y^{i}_{t-1}]$');
else
    ylabel('$E[\Delta^{6}_{arc}Y^{i}_{t-1} | \Delta^{1}_{arc}Y^{i}_{t-1}] - E[\Delta^{1}_{arc}Y^{i}_{t-1}]$');
end
xlabel('$E[\Delta^{1}_{arc}Y^{i}_{t-1}]$')
leg=legend('1-5%','11-30%','31-50%','51-70%','71-90%','96-100%','Location','NorthEast','AutoUpdate','off');
set(leg,'FontSize',lfsize);
set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
xSize=9; ySize=8; xLeft = (21-xSize)/2; yTop = (30-ySize)/2;
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])
if agebin==1
	name = ['butterfly_young_norm_est_' suf];
    name2 = ['butterfly_young_est_' suf];
else
	name = ['butterfly_primeage_norm_est_' suf];
    name2 = ['butterfly_prime_est_' suf];
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');

if write_excel==1
	tbl0 = table({'P1-P5','','P21-P25','','P46-P50','','P71-P75','','P96-P99','','P100'});
	tbl1 = table({'Shock size','Income change in 10 years','Shock size','Income change in 10 years',...
		'Shock size','Income change in 10 years','Shock size','Income change in 10 years'...
		'Shock size','Income change in 10 years','Shock size','Income change in 10 years'});
	tbl2 = table({'P1-P5';'P6-P10';'P11-P15';'P16-P20';'P21-P25';'P26-P30';...
		'P31-P35';'P46-P40';'P41-P45';'P46-P50';'P51-P55';'P56-P60';'P61-P65';...
		'P66-P70';'P71-P75';'P76-P80';'P81-P85';'P86-P90';'P91-P95';'P96-P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name2,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name2,'Range','B3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name2,'Range','B4','WriteVariableNames',false);
end
