clear; close all; clc;
user=3;                 % user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=1;			% =1 update excel file

% Aspect ratio
position=[0.10,0.10,0.50,0.58];
% Defaults for plots
ftsize=25;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); ms=13; set(0,'defaultLineMarkerSize',ms);
set(0,'defaultlinelinewidth',3); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',24); lfsize=25;
mfcolor = [1 0.6 0.78; 0 1 1; 0.00 1.00 0.00; 0.8 0.8 0.8; 1.00 0.50 0.25; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0 0 1; 0.11 0.53 0.10; 0.0 0.0 0.0; 0.63 0.57 0.39; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor; %[0   1   0; 0 0 1; 0.99 0.53 0.06; 0.5 0.5 0.5; 1 0 0;  0    0    0; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.03; mrg_btm=0.115; mrg_lft=0.12;

% Set working directories
folder=char('13_Apr_2017_LT_INC_FRAC');
if(user==1)
	basedirec=char('/Users/serdar/Dropbox/SSA-INCOME-RISK/EmpiricalResults/');
	userdirectory=[basedirec 'Revision2/LifeCycleIncomeGrowth/'];
	addpath('/Users/serdar/Documents/MATLAB/subaxis');
	addpath('/Users/serdar/Dropbox/Home_School/computation/MATLAB/line_fewer_markers_v4');    
	addpath('/Users/serdar/Dropbox/Home_School/computation/MATLAB/export_fig');
	sep=char('/');
elseif(user==2)
	basedirec=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\');
	userdirectory=[basedirec 'LifeCycleIncomeGrowth\'];
	addpath('C:\Users\rceyfk01\Dropbox\subaxis');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
	addpath('C:\Users\rceyfk01\Dropbox\line_fewer_markers');
	sep=char('\');
elseif(user==3)
	basedirec=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/');
	userdirectory=[basedirec 'LifeCycleIncomeGrowth/'];
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
	sep=char('/');
end
input  = [userdirectory 'Input' sep folder sep];
output = [userdirectory 'Output'];
cd(input);

filename=char('incgrowth_moments.xlsx');
filename=[userdirectory 'Output' sep filename];

hmax=36;
N=100;

K=importdata('LT_Profile_FRAC.txt');
LT_FRAC=K.data;

j=1;
for h=1:36
	for i=1:N
		numLT_LABORA(i,h)=LT_FRAC(j,3);  %#ok<*SAGROW>
		avgLT_LABORA(i,h)=LT_FRAC(j,4);     
		avgLT_LABOR0(i,h)=LT_FRAC(j,6);
		avgLT_LABOR1(i,h)=LT_FRAC(j,8);    
		avgLT_TOTALA(i,h)=LT_FRAC(j,10); 
		avgLT_TOTAL0(i,h)=LT_FRAC(j,12);
		avgLT_TOTAL1(i,h)=LT_FRAC(j,14);        
		j=j+1;
	end
end

pct=1:1:100;
ages=25:1:60;
cd(output)

%% Average LT Income Growth
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.10);
hold on; grid on;
line_fewer_markers(pct,log(avgLT_LABORA(:,31))-log(avgLT_LABORA(:,1)),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
line_fewer_markers(pct,log(avgLT_LABOR1(:,31))-log(avgLT_LABOR1(:,1)),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:));
leg=legend('Benchmark','Labor income excluding zeros','Location','NorthWest'); set(leg,'FontSize',lfsize);
xlabel('Lifetime Income Percentiles'); ylabel('Growth in Average Income 25-55');
set(gcf,'units','normalized','position',position);
name='AVG_LABOR_GWTH_55_25'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
line_fewer_markers(pct,log(avgLT_LABORA(:,31))-log(avgLT_LABORA(:,6)),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
line_fewer_markers(pct,log(avgLT_LABOR1(:,31))-log(avgLT_LABOR1(:,6)),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:));
leg=legend('Benchmark','Labor income excluding zeros','Location','NorthWest'); set(leg,'FontSize',lfsize);
xlabel('Lifetime Income Percentiles'); ylabel('Growth in Average Income 30-55');
set(gcf,'units','normalized','position',position);
name='AVG_LABOR_GWTH_55_30'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

%% Average LT Income Growth
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
line_fewer_markers(pct,log(avgLT_TOTALA(:,31))-log(avgLT_TOTALA(:,1)),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
line_fewer_markers(pct,log(avgLT_TOTAL1(:,31))-log(avgLT_TOTAL1(:,1)),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:));
leg=legend('Benchmark','Total income excluding zeros','Location','NorthWest'); set(leg,'FontSize',lfsize);
xlabel('Lifetime Income Percentiles'); ylabel('Growth in Average Income 25-55');
set(gcf,'units','normalized','position',position);
name='AVG_TOTAL_GWTH_55_25'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
line_fewer_markers(pct,log(avgLT_TOTALA(:,31))-log(avgLT_TOTALA(:,6)),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
line_fewer_markers(pct,log(avgLT_TOTAL1(:,31))-log(avgLT_TOTAL1(:,6)),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:));
leg=legend('Benchmark','Total income excluding zeros','Location','NorthWest'); set(leg,'FontSize',lfsize);
xlabel('Lifetime Income Percentiles'); ylabel('Growth in Average Income 30-55');
set(gcf,'units','normalized','position',position);
name='AVG_TOTAL_GWTH_55_30'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

%% Comparing income growth with and without DI
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.10); hold on; grid on;
line_fewer_markers(pct,log(avgLT_LABORA(:,31))-log(avgLT_LABORA(:,1)),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
line_fewer_markers(pct,log(avgLT_TOTALA(:,31))-log(avgLT_TOTALA(:,1)),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:));
leg=legend('Labor income','Total income'); set(leg,'FontSize',lfsize,'Location','NorthWest');
xlabel('Lifetime Income Percentiles'); ylabel('Growth in Average Income 25-55');
set(gcf,'units','normalized','position',position);
name='Compare_INCG_GWTH_25_55'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

if write_excel==1
	data=[pct' log(avgLT_LABORA(:,31))-log(avgLT_LABORA(:,1)) log(avgLT_TOTALA(:,31))-log(avgLT_TOTALA(:,1))];
	tbl1 = table({'LT Pctile','Labor income','Total income'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
hold on; grid on;
line_fewer_markers(pct,log(avgLT_LABORA(:,31))-log(avgLT_LABORA(:,6)),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
line_fewer_markers(pct,log(avgLT_TOTALA(:,31))-log(avgLT_TOTALA(:,6)),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:));
leg=legend('Labor income','Total income'); set(leg,'FontSize',lfsize,'Location','NorthWest');
xlabel('Lifetime Income Percentiles'); ylabel('Growth in Average Income 30-55');
set(gcf,'units','normalized','position',position);
name='Compare_INCG_GWTH_30_55'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

if write_excel==1
	data=[pct' log(avgLT_LABORA(:,31))-log(avgLT_LABORA(:,6)) log(avgLT_TOTALA(:,31))-log(avgLT_TOTALA(:,6))];
	tbl1 = table({'LT Pctile','Labor income','Total income'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Fraction of Zero Incomes over the Life Cycle
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
line_fewer_markers(ages,avgLT_LABOR0(1,:),18,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
for i=2:6
    line_fewer_markers(ages,avgLT_LABOR0((i-1)*20,:),18,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),'MarkerEdgeColor',mecolor(i,:));
end
axis([25,60,0,0.7]); set(gca,'XTick',25:5:60); set(gca,'YTick',0:0.1:0.7);
leg=legend('1','20','40','60','80','100'); set(leg,'FontSize',lfsize,'Location','Best');
xlabel('Age'); ylabel('Fraction including zeros - Labor Income');
set(gcf,'units','normalized','position',position);
name='Frac_LABOR_w_zeros'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

if write_excel==1
	data=[ages' avgLT_LABOR0(1,:)' avgLT_LABOR0((2-1)*20,:)' avgLT_LABOR0((3-1)*20,:)' avgLT_LABOR0((4-1)*20,:)' avgLT_LABOR0((5-1)*20,:)' avgLT_LABOR0((6-1)*20,:)'];
	tbl1 = table({'Age','LE1','LE20','LE40','LE60','LE80','LE100'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
line_fewer_markers(ages,avgLT_TOTAL0(1,:),18,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
for i=2:6
    line_fewer_markers(ages,avgLT_TOTAL0((i-1)*20,:),18,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),'MarkerEdgeColor',mecolor(i,:));
end
axis([25,60,0,0.7]); set(gca,'XTick',25:5:60); set(gca,'YTick',0:0.1:0.7);
leg=legend('1','20','40','60','80','100','Location','NorthWest'); set(leg,'FontSize',lfsize);
xlabel('Age'); ylabel('Fraction including zeros - Total Income');
set(gcf,'units','normalized','position',position);
name='Frac_TOTAL_w_zeros'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');

if write_excel==1
	data=[ages' avgLT_TOTAL0(1,:)' avgLT_TOTAL0((2-1)*20,:)' avgLT_TOTAL0((3-1)*20,:)' avgLT_TOTAL0((4-1)*20,:)' avgLT_TOTAL0((5-1)*20,:)' avgLT_TOTAL0((6-1)*20,:)'];
	tbl1 = table({'Age','LE1','LE20','LE40','LE60','LE80','LE100'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Fraction of Aggregate Income That Goes to Income Groups
agg=sum(numLT_LABORA.*avgLT_LABORA);
frc(1,:)=sum(numLT_LABORA(1:10,:).*avgLT_LABORA(1:10,:))./agg;
frc(2,:)=sum(numLT_LABORA(11:30,:).*avgLT_LABORA(11:30,:))./agg;
frc(3,:)=sum(numLT_LABORA(31:50,:).*avgLT_LABORA(31:50,:))./agg;
frc(4,:)=sum(numLT_LABORA(51:70,:).*avgLT_LABORA(51:70,:))./agg;
frc(5,:)=sum(numLT_LABORA(71:90,:).*avgLT_LABORA(71:90,:))./agg;
frc(6,:)=sum(numLT_LABORA(91:95,:).*avgLT_LABORA(91:95,:))./agg;
frc(7 ,:)=sum(numLT_LABORA(96:100,:).*avgLT_LABORA(96:100,:))./agg;

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
line_fewer_markers(ages,frc(1,:),18,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));
for i=2:7
    line_fewer_markers(ages,frc(i,:),18,style(i,:),'Color',colors(i,:),'MarkerFaceColor',mfcolor(i,:),'MarkerEdgeColor',mecolor(i,:));
end
leg=legend('1-10','11-30','31-50','51-70','71-90','91-95','96-100','Location','NorthWest'); set(leg,'FontSize',lfsize);
xlabel('Age'); ylabel('\% of Aggregate Income');
set(gcf,'units','normalized','position',position);
name='Frac_AggInc_Age'; export_fig([name '.eps'],'-nocrop','-transparent'); saveas(h,name,'fig');
