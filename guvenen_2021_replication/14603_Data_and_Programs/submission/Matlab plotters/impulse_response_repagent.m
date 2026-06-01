clear; close all; clc;
user=3;					% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=1;			% =1 update excel file

dib=0; suf='log';
if dib==0
	suf2='labor';
elseif dib==1
	suf2='total';
else
	disp('error'); stop
end
filename=['impulse_moments_' suf '.xlsx'];

% Defaults for plots
ftsize=22;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); set(0,'defaultLineMarkerSize',10);
set(0,'defaultlinelinewidth',3); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',22); lfsize=23; ansize=24;
mfcolor = [1 0.6 0.78; 0 1 1; 0.00 1.00 0.00; 0.8 0.8 0.8; 1.00 0.50 0.25; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0 0 1; 0.11 0.53 0.10; 0.0 0.0 0.0; 0.63 0.57 0.39; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor; %[0   1   0; 0 0 1; 0.99 0.53 0.06; 0.5 0.5 0.5; 1 0 0;  0    0    0; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
% colors = [0 0 1; 0 1 0; 1 0 0; 0.8 0.7 0.6; 0 0 0; 0 0.7 0.7; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.027; mrg_btm=0.11; mrg_lft=0.125;
% Positioning
xSize=9; ySize=8.8; xLeft = (21-xSize)/2; yTop = (30-ySize)/2;

folder=char('22_Mar_2017_ImpulseResponse_labor_repagent_DIB');
if(user==1) % serdar
	userdirectory=char('C:\Research\SSA-INCOME-RISK\EmpiricalResults\Revision\ImpulseResponse\');
	sep=char('\');
elseif(user==2) % f. karahan nyfed
	userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\ImpulseResponse\');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\subaxis\');
	addpath('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Matlab');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
elseif(user==3) % f. karahan Mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/ImpulseResponse/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
end
input  = [userdirectory 'Input' sep folder sep];
cd(input);

output = [userdirectory 'Output' sep 'RepAgent' sep];
filename=[userdirectory 'Output' sep filename];

K=importdata('impulse_repagent.txt');
results=K.data;
npast=21; ncur=20;
cd(output);

%% Plot as impulse response. For a guy with median income:
agebin=2; incrank=10; mod_ind=10;
j =(agebin-1)*npast*ncur+(incrank-1)*ncur;
x=[-1 0 1 2 3 5 10];

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;

indy=(5+dib*6):(9+dib*6);
for i=1:ncur
	n = mod(i,5)+1;
	ydata = [0 results(j+i,4+dib*6)-results(j+mod_ind,4+dib*6) ...
			results(j+i,indy)-results(j+mod_ind,indy)+...
			results(j+i,4+dib*6)-results(j+mod_ind,4+dib*6)];
	plot(x,ydata,style(mod(i,length(style))+1,:),'Color',colors(mod(i,length(colors))+1,:),...
		'MarkerFaceColor',mfcolor(mod(i,length(colors))+1,:),'MarkerEdgeColor',mecolor(mod(i,length(colors))+1,:))
end
xlim([-1 10]);
xlabel('$k$','FontSize',28); ylabel('$\log E[Y^{i}_{t+k}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+k}-y_{t}$');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name = ['impresponse_DSGE_median_young_' suf2 '_' suf];
else
	name = ['impresponse_DSGE_median_primeage_' suf2 '_' suf];
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

%% Plot as impulse response. For a guy at 10p of RE distribution:
agebin=2; incrank=2; mod_ind=10;
j =(agebin-1)*npast*ncur+(incrank-1)*ncur;
x=[-1 0 1 2 3 5 10];

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;

indy=(5+dib*6):(9+dib*6);
for i=1:ncur
	n = mod(i,5)+1;
	ydata = [0 results(j+i,4+dib*6)-results(j+mod_ind,4+dib*6) ...
			results(j+i,indy)-results(j+mod_ind,indy)+...
			results(j+i,4+dib*6)-results(j+mod_ind,4+dib*6)];
	plot(x,ydata,style(mod(i,length(style))+1,:),'Color',colors(mod(i,length(colors))+1,:),...
		'MarkerFaceColor',mfcolor(mod(i,length(colors))+1,:),'MarkerEdgeColor',mecolor(mod(i,length(colors))+1,:))
end
xlim([-1 10]);
xlabel('$k$','FontSize',28); ylabel('$\log E[Y^{i}_{t+k}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+k}-y_{t}$');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name = ['impresponse_DSGE_10p_young_' suf2 '_' suf ];
else
	name = ['impresponse_DSGE_10p_primeage_' suf2 '_' suf];
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

%% Plot as impulse response. For a guy at 90p of RE distribution:
agebin=2; incrank=19; mod_ind=10;
j =(agebin-1)*npast*ncur+(incrank-1)*ncur;
x=[-1 0 1 2 3 5 10];

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;

indy=(5+dib*6):(9+dib*6);
for i=1:ncur
	n = mod(i,5)+1;
	ydata = [0 results(j+i,4+dib*6)-results(j+mod_ind,4+dib*6) ...
			results(j+i,indy)-results(j+mod_ind,indy)+...
			results(j+i,4+dib*6)-results(j+mod_ind,4+dib*6)];
	plot(x,ydata,style(mod(i,length(style))+1,:),'Color',colors(mod(i,length(colors))+1,:),...
		'MarkerFaceColor',mfcolor(mod(i,length(colors))+1,:),'MarkerEdgeColor',mecolor(mod(i,length(colors))+1,:))
end
xlim([-1 10]);
xlabel('$k$','FontSize',28); ylabel('$\log E[Y^{i}_{t+k}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+k}-y_{t}$');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name = ['impresponse_DSGE_90p_young_' suf2 '_' suf];
else
	name = ['impresponse_DSGE_90p_primeage_' suf2 '_' suf];
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

%% Fix an agebin, plot for the median income group (normalized)
agebin=2; incrank=10; mod_ind=10;
j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
xx=-2.2:0.05:2.2; permy=0*xx; transity=-xx;
indy=(5+dib*6):(9+dib*6);

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
xdata = results(j+1:j+ncur,4+dib*6)-results(j+mod_ind,4+dib*6);
data=xdata;
for i=1:length(indy)
	ydata = results(j+1:j+ncur,indy(i))-results(j+mod_ind,indy(i));
	plot(xdata,ydata,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),...
		'MarkerEdgeColor',mecolor(i,:))
	data=[data ydata]; %#ok<*AGROW>
end
xlabel('$y_{t}-y_{t-1}$','FontSize',28); ylabel('$\log E[Y^{i}_{t+k}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+k}-y_{t}$');
axis([-1.3,1.3,-1.3,1.3])
leg=legend('k=1', 'k=2', 'k=3', 'k=5', 'k=10', 'Location','NorthEast','AutoUpdate','off');
set(leg,'FontSize',lfsize,'FontName','Times New Roman');
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2)

annotation(figure(h),'textarrow',[0.275659824046921 0.275048931607254],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.384467253176931],...
    [0.85 0.74],'TextEdgeColor','none','FontWeight','bold','linewidth',1,'FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');
set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name = char(['ImpResp_Median_young_normalized_' suf2 '_' suf]);
	name2 = char(['ImpResp_Median_young_' suf2 '_' suf]);
else
	name = char(['ImpResp_Median_primeage_normalized_' suf2 '_' suf]);
	name2 = char(['ImpResp_Median_prime_' suf2 '_' suf]);
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	tbl1 = table({'Shock size','Income change in k=1 years','Income change in k=2 years',...
		'Income change in k=3 years','Income change in k=5 years','Income change in k=10 years'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
end

%% Fix an agebin and plot for 90th percentile
agebin=2; incrank=19; mod_ind=10;
j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
xx=-1.5:0.05:1.5; permy=0*xx; transity=-xx;
indy=(5+dib*6):(9+dib*6);

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;

xdata = results(j+1:j+ncur,4+dib*6)-results(j+mod_ind,4+dib*6);
data=xdata;
for i=1:length(indy)
	ydata = results(j+1:j+ncur,indy(i))-results(j+mod_ind,indy(i));
	plot(xdata,ydata,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),...
		'MarkerEdgeColor',mecolor(i,:))
	data=[data ydata];
end
xlabel('$y_{t}-y_{t-1}$','FontSize',28); ylabel('$\log E[Y^{i}_{t+k}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+k}-y_{t}$');
if agebin==1
    axis([-1.5,1.5,-1.5,1.5])
else
    axis([-1.5,1.5,-1.5,1.5])
end
leg=legend('k=1', 'k=2', 'k=3', 'k=5', 'k=10', 'Location','NorthEast','AutoUpdate','off');
set(leg,'FontSize',lfsize,'FontName','Times New Roman');
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2)

annotation(figure(h),'textarrow',[0.275659824046921 0.275659824046921],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.414467253176931],...
    [0.779942528735632 0.715287356321839],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name = ['ImpResp_90thPct_young_normalized_' suf2 '_' suf];
	name2 = char(['ImpResp_90_young_' suf2 '_' suf]);
else
	name = ['ImpResp_90thPct_primeage_normalized_' suf2 '_' suf];
	name2 = char(['ImpResp_90_prime_' suf2 '_' suf]);
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	tbl1 = table({'Shock size','Income change in k=1 years','Income change in k=2 years',...
		'Income change in k=3 years','Income change in k=5 years','Income change in k=10 years'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
end

%% Fix an agebin and plot for 10th percentile
agebin=2; incrank=2; mod_ind=10;
j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
xx=-2:0.05:2; permy=0*xx; transity=-xx;

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;

xdata = results(j+1:j+ncur,4+dib*6)-results(j+mod_ind,4+dib*6);
data=xdata;
for i=1:length(indy)
	ydata = results(j+1:j+ncur,indy(i))-results(j+mod_ind,indy(i));
	plot(xdata,ydata,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),...
		'MarkerEdgeColor',mecolor(i,:))
	data=[data ydata];
end
xlabel('$y_{t}-y_{t-1}$','FontSize',28); ylabel('$\log E[Y^{i}_{t+k}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+k}-y_{t}$');
axis([-2,2,-1.8,2])
leg=legend('k=1', 'k=2', 'k=3', 'k=5', 'k=10', 'Location','NorthEast','AutoUpdate','Off');
set(leg,'FontSize',lfsize,'FontName','Times New Roman');
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2)

annotation(figure(h),'textarrow',[0.275659824046921 0.275659824046921],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.414467253176931],...
    [0.779942528735632 0.715287356321839],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name  = ['ImpResp_10thPct_young_normalized_' suf2 '_' suf];
	name2 = char(['ImpResp_10_young_' suf2 '_' suf]);
else
	name  = ['ImpResp_10thPct_primeage_normalized_' suf2 '_' suf];
	name2 = char(['ImpResp_10_prime_' suf2 '_' suf]);
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	tbl1 = table({'Shock size','Income change in k=1 years','Income change in k=2 years',...
		'Income change in k=3 years','Income change in k=5 years','Income change in k=10 years'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
end

%% Fix an agebin and future change. Plot butterfly (normalized)
agebin=2; F10=1; mod_ind=10;
xx=-2:0.05:2; permy=0*xx; transity=-xx;

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;

indinc=[1 5 10 15 20 21]; data=[];
for i=1:length(indinc)
	incrank=indinc(i);
	j=(agebin-1)*npast*ncur+(incrank-1)*ncur;
	resultsMODx = results(j+1:j+ncur,4+dib*6)-results(j+mod_ind,4+dib*6);
	resultsMODy = results(j+1:j+ncur,8+dib*6+F10)-results(j+mod_ind,8+dib*6+F10);
	plot(resultsMODx,resultsMODy,style(i,:),'Color',colors(i,:),...
		'MarkerFaceColor',mfcolor(i,:),'MarkerEdgeColor',mecolor(i,:))
	data=[data resultsMODx resultsMODy];
end
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2);

axis([-2.0,2.0,-2.0,2.0]); set(gca,'YTick',-2.0:0.5:2.0); set(gca,'YTick',-2:0.5:2);
if F10==1
    ylabel('$\log E[Y^{i}_{t+10}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+10}-y_{t}$');
else
    ylabel('$\log E[Y^{i}_{t+5}] - \log E[Y^{i}_{t}]$','FontSize',28); %ylabel('$y_{t+5}-y_{t}$');
end
xlabel('$y_{t}-y_{t-1}$','FontSize',28);
plot(xx,permy,'--k','linewidth',2); plot(xx,transity,'--k','linewidth',2)

leg=legend('1-5%','21-25%','46-50%','71-75%','96-99%','100%','Location','NorthEast');
set(leg,'FontSize',lfsize,'FontName','Times New Roman');

annotation(figure(h),'textarrow',[0.275659824046921 0.275659824046921],...
    [0.42664420842496 0.517972856512764],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Permanent');
annotation(figure(h),'textarrow',[0.456500488758553 0.414467253176931],...
    [0.779942528735632 0.715287356321839],'TextEdgeColor','none','FontSize',ansize,...
    'FontName','Times New Roman','FontWeight','bold','linewidth',1,...
    'String','Transitory');

set(gcf,'PaperPositionMode','auto'); set(gcf,'PaperUnits','inches')
set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
set(gcf,'Position',[100 100 xSize*70 ySize*70])

if agebin==1
	name = ['butterfly_young_norm_' suf2 '_' suf];
	name2 = ['butterfly_young_' suf2 '_' suf];
else
	name  = ['butterfly_primeage_norm_' suf2 '_' suf];
	name2 = ['butterfly_prime_' suf2 '_' suf];
end
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

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
