clear; clc; close all; 
user=3;					% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=0;			% =1 update excel file
arc=0; k=5; dib=0;
arc1=arc; k1=k;			% for comparisons
nmrkr=25;				% #markers in each plot
% position=[0.1,0.1,0.50,0.68];

% Defaults for plots
ftsize=20;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); ms=13; set(0,'defaultLineMarkerSize',ms);
set(0,'defaultlinelinewidth',2.5); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',ftsize); lfsize=21;
mfcolor = [1 0.6 0.78; 0 1 1; 0.00 1.00 0.00; 0.8 0.8 0.8; 1.00 0.50 0.25; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0 0 1; 0.11 0.53 0.10; 0.0 0.0 0.0; 0.63 0.57 0.39; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor; %[0   1   0; 0 0 1; 0.99 0.53 0.06; 0.5 0.5 0.5; 1 0 0;  0    0    0; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
% colors = [0 0 1; 0 1 0; 1 0 0; 0.8 0.7 0.6; 0 0 0; 0 0.7 0.7; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.03; mrg_btm=0.13; mrg_lft=0.115;

folder=char('24_Mar_2017_YRCHANGE_DIB');
if(user==1) % serdar
	userdirectory=char('C:\Research\SSA-INCOME-RISK\EmpiricalResults\Revision\CrossSectional\');
	sep=char('\');
elseif(user==2) % f. karahan nyfed
	userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\CrossSectional\');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\subaxis\');
	addpath('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Matlab');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
	addpath('C:\Users\rceyfk01\Dropbox\line_fewer_markers');
elseif(user==3) % f. karahan Mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/CrossSectional/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
end
code  = [userdirectory 'Code' sep];
input = [userdirectory 'Input' sep folder sep];
cd(code);

if arc==1
	output = [userdirectory 'Output' sep 'Arc' sep];
	suf='arc';
	if k==1
		varname='$\Delta_{arc}^{1}Y^i_{t}$';
	else
		varname='$\Delta_{arc}^{5}Y^i_{t}$';
	end
else
	output = [userdirectory 'Output' sep 'Log' sep];
	suf='log';
	if k==1
		varname='$\Delta_{log}^{1}y^i_{t}$';
	else
		varname='$\Delta_{log}^{5}y^i_{t}$';
	end
end
filename=['cross_moments_' suf '.xlsx'];
filename=[userdirectory 'Output' sep filename];
if dib==0
	suf2='labor';
elseif dib==1
	suf2='total';
else
	disp('error'); stop
end

[po,sdage,skewage,kurtage,p90_10,p90_50,p50_10,kellysage,...
	hinkleyage,moorsage,crowsage] = read_cross_moments(input,k,arc,dib);
dib1=0; cd(code);
[po_0,sdage_0,skewage_0,kurtage_0,p90_10_0,p90_50_0,p50_10_0,kellysage_0,...
	hinkleyage_0,moorsage_0,crowsage_0] = read_cross_moments(input,k1,arc1,dib1);
dib1=1; cd(code);
[po_1,sdage_1,skewage_1,kurtage_1,p90_10_1,p90_50_1,p50_10_1,kellysage_1,...
	hinkleyage_1,moorsage_1,crowsage_1] = read_cross_moments(input,k1,arc1,dib1);
varname_comp=varname;
if arc1==1
	suf_comp='arc';
else
	suf_comp='log';
end
cd(output);

%% Distribution of Shocks for Prime Age Males (various percentiles of the shock distribution)
set(0,'defaultAxesFontSize',18);
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',0.10,'MarginLeft',0.068);
line_fewer_markers(1:100,po(:,2),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,po(:,3),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,4),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,5),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,6),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,7),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,8),nmrkr,style(7,:),'Color',colors(7,:),'MarkerFaceColor',mfcolor(7,:),'MarkerEdgeColor',mecolor(7,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,9),nmrkr,style(8,:),'Color',colors(8,:),'MarkerFaceColor',mfcolor(8,:),'MarkerEdgeColor',mecolor(8,:),'MarkerSize',ms);

xlabel('Percentiles of Recent Earnings Distribution','fontsize',27)
ylabel(['Percentiles of  ' varname],'fontsize',27);
set(gca,'XTick',0:20:100); set(gca,'XTickLabel',0:20:100);
% if k==1
% 	set(gca,'YTick',-2.5:1:2.5); grid on;
% 	if arc==1
% 		x1=0; x2=100; y1=-2.5; y2=2.5; st=0.5;
% 	else
% 		x1=0; x2=100; y1=-3; y2=3; st=1;
% 	end
% else
% 	set(gca,'YTick',-2.5:1:2.5); grid on;
% 	if arc==1
% 		x1=0; x2=100; y1=-2.5; y2=2.5; st=0.5;
% 	else
% 		x1=0; x2=100; y1=-3; y2=3; st=1;
% 	end
% end
x1=0; x2=100;
% axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
leg=legend('P5','P10','P25','P50','P75','P90','P95','P99');
set(leg,'FontSize',23,'location','north','orientation','horizontal');
set(gcf,'units','normalized','position',[0.1,0.1,0.75,0.65]);
name=['L' num2str(k) '_PrimeAge_vase_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')
set(0,'defaultAxesFontSize',ftsize);

if write_excel==1
	data=[(1:100)' po(:,2:9)];
	tbl1 = table({'RE Pctile','P5','P10','P25','P50','P75','P90','P95','P99'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Standard Deviation of Shocks for All Age Groups
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,mean(sdage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(sdage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(sdage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Standard Deviation of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=0.4; y2=1.2; st=0.1;
	else
		x1=0; x2=100; y1=0.4; y2=0.9; st=0.1;
	end
else
	if arc==1
		x1=0; x2=100; y1=0.5; y2=1.4; st=0.1;
	else
		x1=0; x2=100; y1=0.6; y2=1.2; st=0.1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_StdDev_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' sdage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
line_fewer_markers(1:100,mean(p90_10(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['P90-P10 of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=0.4; y2=3.6; st=0.5;
	else
		x1=0; x2=100; y1=0.4; y2=2.2; st=0.3;
	end
else
	if arc==1
		x1=0; x2=100; y1=1.0; y2=4.0; st=0.4;
	else
		x1=0; x2=100; y1=0.8; y2=3.2; st=0.4;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_90_10_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' p90_10(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Standard Deviation: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.115);
line_fewer_markers(1:100,mean(sdage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(sdage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(sdage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(sdage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(sdage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(sdage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
leg=legend('25-34 Labor','25-34 Total','35-44 Labor','35-44 Total','45-54 Labor','45-54 Total');
set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Standard Deviation of ' varname_comp]);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
if k==1
	if arc==1
		x1=0; x2=100; y1=0.4; y2=1.2; st=0.1;
	else
		x1=0; x2=100; y1=0.4; y2=0.9; st=0.1;
	end
else
	if arc==1
		x1=0; x2=100; y1=0.5; y2=1.4; st=0.1;
	else
		x1=0; x2=100; y1=0.6; y2=1.1; st=0.1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_StdDev_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' sdage_0(1:6,:)' sdage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.115);
hold on; grid on;
line_fewer_markers(1:100,mean(p90_10_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(p90_10_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['P90-P10 of ' varname_comp]);
if k==1
	if arc==1
		x1=0; x2=100; y1=0.4; y2=3.6; st=0.5;
	else
		x1=0; x2=100; y1=0.4; y2=2.2; st=0.3;
	end
else
	if arc==1
		x1=0; x2=100; y1=0.8; y2=4.0; st=0.4;
	else
		x1=0; x2=100; y1=0.8; y2=3.2; st=0.4;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_90_10_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' p90_10_0(1:6,:)' p90_10_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Skewness of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.128);
line_fewer_markers(1:100,mean(skewage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on; %#ok<*UDIM>
line_fewer_markers(1:100,mean(skewage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(skewage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('25-34', '35-44', '45-54','location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel(['Skewness of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=-1.5; y2=0.5; st=0.5;
	else
		x1=0; x2=100; y1=-3.0; y2=0.5; st=0.5;
	end
else
	if arc==1
		x1=0; x2=100; y1=-1.2; y2=0.2; st=0.2;
	else
		x1=0; x2=100; y1=-2.5; y2=0.5; st=0.5;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Skew_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' skewage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Skewness of Shocks: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.128);
line_fewer_markers(1:100,mean(skewage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on; %#ok<*UDIM>
line_fewer_markers(1:100,mean(skewage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(skewage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(skewage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(skewage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(skewage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('25-34 Labor','25-34 Total','35-44 Labor',...
	'35-44 Total','45-54 Labor','45-54 Total');
set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution');
ylabel(['Skewness of ' varname_comp]);
if k==1
	if arc==1
		x1=0; x2=100; y1=-1.5; y2=0.5; st=0.5;
	else
		x1=0; x2=100; y1=-3.0; y2=0.5; st=0.5;
	end
else
	if arc==1
		x1=0; x2=100; y1=-1.2; y2=0.2; st=0.2;
	else
		x1=0; x2=100; y1=-2.5; y2=0.5; st=0.5;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_Skew_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' skewage_0(1:6,:)' skewage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Kelley's Skewness Measure of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.13); % ,'MarginLeft',0.145
line_fewer_markers(1:100,mean(kellysage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(kellysage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kellysage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;

% leg=legend('25-34','35-44','45-54','Location','Best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Kelley Skewness of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=-0.35; y2=0.05; st=0.1;
	else
		x1=0; x2=100; y1=-0.25; y2=0.05; st=0.05;
	end
else
	if arc==1
		x1=0; x2=100; y1=-0.7; y2=0.1; st=0.1;
	else
		x1=0; x2=100; y1=-0.5; y2=0.1; st=0.1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_KellySkew_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kellysage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Kelley's Skewness Measure of Shocks: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.145);
line_fewer_markers(1:100,mean(kellysage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(kellysage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kellysage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kellysage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kellysage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kellysage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34 Labor','25-34 Total','35-44 Labor',...
% 	'35-44 Total','45-54 Labor','45-54 Total');
% set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Kelley Skewness of ' varname_comp]);
if k==1
	if arc==1
		x1=0; x2=100; y1=-0.35; y2=0.05; st=0.1;
	else
		x1=0; x2=100; y1=-0.25; y2=0.05; st=0.05;
	end
else
	if arc==1
		x1=0; x2=100; y1=-0.7; y2=0.1; st=0.1;
	else
		x1=0; x2=100; y1=-0.5; y2=0.1; st=0.1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_KellySkew_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kellysage_0(1:6,:)' kellysage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Kelley's skewness decomposed: P90-P50 vs. P50-P10
p90_50_frac=p90_50./p90_10;
p50_10_frac=p50_10./p90_10;
for age=2:3
	p90_50_rel(age-1,:)=mean(p90_50(2+(age-2)*2+1:4+(age-2)*2,:),1)-mean(p90_50(1:2,:),1); %#ok<*SAGROW>
	p50_10_rel(age-1,:)=mean(p50_10(2+(age-2)*2+1:4+(age-2)*2,:),1)-mean(p50_10(1:2,:),1);
end

% Relative to age 25-29
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.127);  %,0.115
line_fewer_markers(1:100,p90_50_rel(1,:)',nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,p90_50_rel(2,:)',nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('35-44','45-54','Zero line','Location','Best'); % set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel(['P90-P50 of ' varname_comp ' (Relative to 25-34)']);
% ylabel({['P90-P50 ' varname_comp] '(Relative to 25-34)'},'FontSize',21);
if k==1
	if arc==1
		x1=0; x2=100; y1=-0.4; y2=0.1; st=0.1;
	else
		x1=0; x2=100; y1=-0.3; y2=0.1; st=0.1;
	end
else
	if arc==1
		x1=0; x2=100; y1=-0.5; y2=0.1; st=0.1;
	else
		x1=0; x2=100; y1=-0.4; y2=0.1; st=0.1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_90_50_rel_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data = [(1:100)' p90_50_rel(1:2,:)'];
	tbl1 = table({'RE Pctile','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.127);
line_fewer_markers(1:100,p50_10_rel(1,:)',nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,p50_10_rel(2,:)',nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
% plot(1:100,zeros(1,100),'--k','linewidth',1.5)
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('35-44','45-54'); set(leg,'FontSize',lfsize,'Location','Best');
xlabel('Percentiles of Recent Earnings Distribution');
ylabel(['P50-P10 of ' varname_comp ' (Relative to 25-34)']);
if k==1
	if arc==1
		x1=0; x2=100; y1=-0.2; y2=0.2; st=0.1;
	else
		x1=0; x2=100; y1=-0.3; y2=0.2; st=0.1;
	end
else
	if arc==1
		x1=0; x2=100; y1=-0.2; y2=0.6; st=0.2;
	else
		x1=0; x2=100; y1=-0.4; y2=0.4; st=0.2;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_50_10_rel_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data = [(1:100)' p50_10_rel(1:2,:)'];
	tbl1 = table({'RE Pctile','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Kurtosis of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.105);
line_fewer_markers(1:100,mean(kurtage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(kurtage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kurtage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Kurtosis of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=0; y2=15; st=3;
	else
		x1=0; x2=100; y1=0; y2=30; st=5;
	end
else
	if arc==1
		x1=0; x2=100; y1=0; y2=8; st=2;
	else
		x1=0; x2=100; y1=2; y2=18; st=4;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Kurtosis_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kurtage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Kurtosis of Shocks: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.105);
line_fewer_markers(1:100,mean(kurtage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(kurtage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kurtage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kurtage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kurtage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kurtage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
leg=legend('25-34 Labor','25-34 Total','35-44 Labor',...
	'35-44 Total','45-54 Labor','45-54 Total');
set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Kurtosis of ' varname_comp]);
if k==1
	if arc==1
		x1=0; x2=100; y1=0; y2=15; st=3;
	else
		x1=0; x2=100; y1=0; y2=30; st=5;
	end
else
	if arc==1
		x1=0; x2=100; y1=0; y2=8; st=2;
	else
		x1=0; x2=100; y1=2; y2=18; st=4;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_Kurtosis_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kurtage_0(1:6,:)' kurtage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Alternative measures of skewness and kurtosis
% Hinkley
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.145);
line_fewer_markers(1:100,mean(hinkleyage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(hinkleyage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(hinkleyage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('25-34','35-44','45-54','Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Hinkley Skewness of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=-0.3; y2=0.1; st=0.1;
	else
		x1=0; x2=100; y1=-0.3; y2=0.05; st=0.1;
	end
else
	if arc==1
		x1=0; x2=100; y1=-0.2; y2=0.1; st=0.05;
	else
		x1=0; x2=100; y1=-0.5; y2=0.1; st=0.1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Hinkley_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' hinkleyage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Hinkley Skewness: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.145);
line_fewer_markers(1:100,mean(hinkleyage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(hinkleyage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(hinkleyage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(hinkleyage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(hinkleyage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(hinkleyage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
% ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('25-34 Labor','25-34 Total','35-44 Labor',...
	'35-44 Total','45-54 Labor','45-54 Total');
set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Hinkley Skewness of ' varname_comp]);
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_Hinkley_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' hinkleyage_0(1:6,:)' hinkleyage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Moors kurtosis
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.112);
line_fewer_markers(1:100,mean(moorsage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(moorsage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(moorsage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,1.23); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
if k==1
	leg=legend('25-34','35-44','45-54','Gaussian','Location','best'); set(leg,'FontSize',lfsize);
end
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Moors Kurtosis of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=1; y2=3.5; st=0.5;
	else
		x1=0; x2=100; y1=1; y2=3; st=0.5;
	end
else
	if arc==1
		x1=0; x2=100; y1=0.5; y2=3; st=0.5;
	else
		x1=0; x2=100; y1=1; y2=2.5; st=0.5;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Moors_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' moorsage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Moors kurtosis: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.112);
line_fewer_markers(1:100,mean(moorsage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(moorsage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(moorsage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(moorsage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(moorsage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(moorsage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
% ref=refline(0,1.23); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34 Labor','25-34 Total','35-44 Labor',...
% 	'35-44 Total','45-54 Labor','45-54 Total');
% set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Moors Kurtosis of ' varname_comp]);
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_Moors_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' moorsage_0(1:6,:)' moorsage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Crow-Siddiqui
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.105);
line_fewer_markers(1:100,mean(crowsage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(crowsage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(crowsage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,2.91); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34','35-44','45-54','Gaussian','Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Crows Kurtosis of ' varname]);
if k==1
	if arc==1
		x1=0; x2=100; y1=2; y2=20; st=3;
	else
		x1=0; x2=100; y1=2; y2=16; st=3;
	end
else
	if arc==1
		x1=0; x2=100; y1=0; y2=10; st=2;
	else
		x1=0; x2=100; y1=2; y2=10; st=1;
	end
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
% set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Crows_' suf2 '_' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' crowsage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
%% Crow-Siddiqui: Comparison
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.105);
line_fewer_markers(1:100,mean(crowsage_0(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(crowsage_1(1:2,:),1),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(crowsage_0(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(crowsage_1(3:4,:),1),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(crowsage_0(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(crowsage_1(5:6,:),1),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
% ref=refline(0,2.91); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34 Labor','25-34 Total','35-44 Labor',...
% 	'35-44 Total','45-54 Labor','45-54 Total');
% set(leg,'FontSize',lfsize,'location', 'best');
xlabel('Percentiles of Recent Earnings Distribution')
ylabel(['Crows Kurtosis of ' varname_comp]);
% set(gcf,'units','normalized','position',position);
name=['Compare_L' num2str(k1) '_Crows_' suf_comp];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' crowsage_0(1:6,:)' crowsage_1(1:6,:)'];	% Labor-Total
	tbl1 = table({'RE Pctile',...
		'25-29 Labor','30-34 Labor','35-39 Labor','40-44 Labor','45-49 Labor','50-54 Labor',...
		'25-29 Total','30-34 Total','35-39 Total','40-44 Total','45-49 Total','50-54 Total'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end