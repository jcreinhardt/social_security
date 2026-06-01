clear; clc; close all; 
user=3;					% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=1;			% =1 update excel file

% Aspect ratio
position=[0.1,0.1,0.50,0.68];
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
mrg=0.03; mrg_btm=0.115; mrg_lft=0.13;

folder=char('13_Jan_2016_LifeCycleProfile_LABOR');
folder2=char('19_Jan_2016_LifeCycleProfile_LABOR_addendum');
folder3=char('1_Feb_2016_LABOR_YBAR_DISPERSION');
folder4=char('11_Mar_2016 LTIncProfile_LABOR_ROBUST');
if(user==1) % serdar
	userdirectory=char('/Users/serdar/Dropbox/SSA-INCOME-RISK/EmpiricalResults/Revision2/LifecycleIncomeGrowth/');
    direc=char('/Users/serdar/Dropbox/SSA-INCOME-RISK/FORTRAN/ECMARevision/Benchmark/Run2');
    addpath('/Users/serdar/Documents/MATLAB/subaxis');
	addpath('/Users/serdar/Dropbox/Home_School/computation/MATLAB/export_fig');
	addpath('/Users/serdar/Dropbox/Home_School/computation/MATLAB/line_fewer_markers_v4');    
	sep=char('/');
elseif(user==2) % f. karahan nyfed
	userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\LifecycleIncomeGrowth\');
	direc=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\FORTRAN\ECMARevision\Benchmark\Run2');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\subaxis\');
	addpath('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Matlab');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
	addpath('C:\Users\rceyfk01\Dropbox\line_fewer_markers');
elseif(user==3) % f. karahan Mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/LifecycleIncomeGrowth/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
end
input  = [userdirectory 'Input' sep folder sep];
input2 = [userdirectory 'Input' sep folder2 sep];
input3 = [userdirectory 'Input' sep folder3 sep];
input4 = [userdirectory 'Input' sep folder4 sep];
output = [userdirectory 'Output' sep];
cd(input);

% Read in data & compute relevant statistics
H=36; Npct=100; meanLTinc=NaN(100,H); meanLTinc_imp=NaN(100,H);
K=importdata('LifeCycleProfile_LABOR.txt'); results=K.data;
cd(input2);
K2=importdata('fraction_topcoded.txt'); results2=K2.data;
cd(input3);
temp=xlsread('agedum_nocoh.xlsx','agedumlabor');
age_profile=temp(1:36,1);
cd(input4);
K3=importdata('LTInc_Profile_LABOR_IMPT_PM.txt'); results3=K3.data;
cd(input);

p50LTinc=NaN(100,H); p10meanLTinc=NaN(100,H); p90LTinc=NaN(100,H);
for i=1:Npct
    for age=1:36
        % Non-imputed data
        meanLTinc(i,age)=results(100*(age-1)+i,4);
        p50LTinc(i,age)=results(100*(age-1)+i,14);
        p90LTinc(i,age)=results(100*(age-1)+i,16);
        p10meanLTinc(i,age)=results(100*(age-1)+i,12);

        % Imputed data
        meanLTinc_imp(i,age)=results3(100*(age-1)+i,4);
    end
end

filename=char('incgrowth_moments.xlsx');
filename=[userdirectory 'Output' sep filename];
if write_excel==1
    cd(output)
    name='income_levels';
    data=[(1:100)' meanLTinc];
	tbl1 = table({'LT pctile'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

% Non-imputed data
meanLTinc2555=log(meanLTinc(:,31))-log(meanLTinc(:,1));
p50LTinc2555=log(p50LTinc(:,31))-log(p50LTinc(:,1));
meanLTinc3055=log(meanLTinc(:,31))-log(meanLTinc(:,6));
p50LTinc3055=log(p50LTinc(:,31))-log(p50LTinc(:,6));
meanLTinc3555=log(meanLTinc(:,31))-log(meanLTinc(:,11));
p50LTinc3555=log(p50LTinc(:,31))-log(p50LTinc(:,11));
meanLTinc3050=log(meanLTinc(:,26))-log(meanLTinc(:,6));
p50LTinc3050=log(p50LTinc(:,26))-log(p50LTinc(:,6));
meanLTinc2535=log(meanLTinc(:,11))-log(meanLTinc(:,1));
meanLTinc3545=log(meanLTinc(:,21))-log(meanLTinc(:,11));
meanLTinc4555=log(meanLTinc(:,31))-log(meanLTinc(:,21));

% Imputed data
meanLTinc2555_imp=log(meanLTinc_imp(:,31))-log(meanLTinc_imp(:,1));

% These are income groups for the estimation
meanLTi(1,:)=meanLTinc(1,:);
meanLTi(2,:)=mean(meanLTinc(2:5,:),1);
meanLTi(3,:)=mean(meanLTinc(6:10,:),1);
for j=1:8
    meanLTi(3+j,:)=mean(meanLTinc(10*j+1:10*(j+1),:),1);
end
meanLTi(12,:)=mean(meanLTinc(91:95,:),1);
meanLTi(13,:)=mean(meanLTinc(96:97,:),1);
meanLTi(14,:)=mean(meanLTinc(98:99,:),1);
meanLTi(15,:)=meanLTinc(100,:);

frac_topcode=zeros(Npct,19);
for i=1:Npct
for age=1:19
	frac_topcode(i,age)=results2(100*(age-1)+i,4);
end
end
cd([userdirectory 'Input'])
dvarlny=dlmread('var_lny.dat');

cdf_shrt=[  6	6.57
14	14.37
20	20.54
25	28.05
30	39.93
33	52.82
36	100];
cdf_all=[0	1.03
1.0000008	1.2
1.0285704	1.56
1.0588248	1.94
1.090908	2.31
2.0000016	2.49
2.0571444	2.84
2.117646	3.19
2.1818196	3.55
2.9999988	3.69
3.0857148	3.98
3.1764708	4.29
3.2727276	4.6
3.9999996	4.73
4.1142852	5
4.2352956	5.28
4.3636356	5.56
5.0000004	5.67
5.1428556	5.92
5.2941168	6.19
5.4545472	6.45
6.0000012	6.57
6.1714296	6.81
6.3529416	7.06
6.5454552	7.32
6.9999984	7.43
7.2	7.67
7.4117664	7.93
7.6363632	8.18
7.9999992	8.3
8.2285704	8.54
8.4705876	8.79
8.7272712	9.05
9	9.17
9.2571444	9.41
9.5294124	9.67
9.8181828	9.94
10.0000008	10.06
10.2857148	10.32
10.5882372	10.6
10.9090908	10.88
11.0000016	11.01
11.3142852	11.28
11.6470584	11.56
11.9999988	11.98
12.3428592	12.27
12.7058832	12.57
12.9999996	12.71
13.0909104	13.01
13.3714296	13.31
13.7647044	13.62
14.0000004	13.76
14.1818184	14.08
14.4	14.37
14.8235292	14.69
15.0000012	14.84
15.2727264	15.17
15.4285704	15.47
15.882354	15.8
15.9999984	15.95
16.363638	16.29
16.4571444	16.61
16.9411752	16.95
16.9999992	17.11
17.454546	17.47
17.4857148	17.8
18	18.33
18.5142852	18.68
18.545454	19.06
19.0000008	19.23
19.0588248	19.61
19.5428592	19.97
19.6363656	20.36
20.0000016	20.54
20.117646	20.93
20.5714296	21.31
20.7272736	21.74
20.9999988	21.93
21.1764708	22.35
21.6	22.76
21.8181816	23.21
21.9999996	23.42
22.2352956	23.88
22.628574	24.31
22.9090896	24.8
23.0000004	25.02
23.2941168	25.5
23.6571444	25.97
24.0000012	26.74
24.3529416	27.27
24.6857148	27.79
24.9999984	28.05
25.0909092	28.63
25.4117664	29.18
25.7142852	29.75
25.9999992	30.03
26.1818172	30.65
26.4705876	31.27
26.7428592	31.89
27	32.18
27.2727288	32.85
27.5294124	33.51
27.7714296	34.15
28.0000008	34.48
28.3636368	35.23
28.5882336	35.96
28.8	36.68
29.0000016	37.05
29.4545448	37.87
29.6470584	38.69
29.8285704	39.53
29.9999988	39.93
30.5454564	40.89
30.7058832	41.85
30.8571444	42.82
30.9999996	43.31
31.6363644	44.47
31.7647044	45.66
31.8857148	46.85
32.0000004	47.47
32.7272724	48.99
32.8235292	50.51
32.9142852	52.04
33.0000012	52.82
33.8181804	54.94
33.882354	57.05
33.9428556	59.14
33.9999984	60.2
34.909092	63.88
34.9411752	67.54
34.9714296	71.1
34.9999992	72.89
36	100];
cdh_shr=cdf_all;
cdh_shr(:,1)=cdh_shr(:,1)/36;
temp=cdf_all;
temp(:,1)=round(cdf_all(:,1),0);
cdf36(1,:)=temp(1,:);
j=1;
for i=2:133
    if(cdf36(j,1)==temp(i,1))
            cdf36(j,2)=temp(i,2);
    else
            j=j+1;
           cdf36(j,:)=temp(i,:);        
    end
end
cd(output);

%% Employment CDF
dcdf_imp=interp1q(cdh_shr(:,1),cdh_shr(:,2),[6 14 20 25 30 33 36]'/36);
dcdf_imp=[0;dcdf_imp];

h=figure;
subaxis(1,1,1, 'Margin', 0.02,'MarginBottom',mrg_btm,'MarginLeft',0.06);
hold on; grid on;
plot(cdf36(:,1),cdf36(:,2)/100,style(1,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:), ...
'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms)
% plot(0:(length(dcdf_imp)-1),dcdf_imp,style(1,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),...
% 	'MarkerEdgeColor',mecolor(4,:),'MarkerSize',11);
xlim([0 36]); set(gca,'XTick',0:5:35);
% set(gca,'XTickLabels',[0 6 14 20 25 30 33 36]); %[0 0.17 0.39 0.56 0.69 0.83 0.92 1.00] [6 14 20 25 30 33 36]/36
xlabel('Total Years Employed','FontSize',32); %xlabel('Fraction of Lifetime Employed')
% ylabel('Employment CDF')
% leg=legend('US Data'); set(leg,'FontSize',lfsize,'Location','NorthWest');
% annotation('textbox',[.4 0.02 .1 .2],'String','(A) Employment CDF','FitBoxToText','on','EdgeColor','none');
set(gcf,'units','normalized','position',position);
name='emp36_cdf_fk';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');

if write_excel==1
	data=[cdf36(:,1) cdf36(:,2)/100];
	tbl1 = table({'Total Years Employed','CDF'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Life cycle inequality profile
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.10);
plot(25:60,dvarlny,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
grid on;
x1=25; x2=60; y1=0.4; y2=1.2; st=0.1;
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',25:5:60); set(gca,'XTickLabel',25:5:60);
xlabel('Age'); ylabel('Cross-Sectional Variance of Log Earnings');
set(gcf,'units','normalized','position',position);
name='varlny_profile';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(25:60)' dvarlny];
	tbl1 = table({'Age','Variance of log earnings'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Life cycle profile of earnings
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.115);
hold on; grid on;
plot(25:60,age_profile,style(4,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms); xlim([24 61]);
plot(23:57,max(age_profile)*ones(1,35),'--','Color',[0 0 0],'linewidth',0.5)
plot(23:28,age_profile(1)*ones(1,6),'--','Color',[0 0 0],'linewidth',0.5)
x1=22; x2=62; y1=9.5; y2=10.6; st=0.2;
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',25:5:60); set(gca,'XTickLabel',25:5:60);
xlabel('Age'); ylabel('Average Log Earnings');
xarr = [0.18 0.18]; yarr = [0.19 0.9];
txtar = annotation('doublearrow',xarr,yarr,'linewidth',0.5,...
	'linestyle','--','color',[1 0 0]); %#ok<NASGU>
xbox = [0.19 0.19 0.5 0.5];
txtar = annotation('textbox','position',xbox,'String',{'154%' 'rise'},...
	'fontsize',26,'linestyle','none','fontweight','bold'); %#ok<NASGU>
set(gcf,'units','normalized','position',position);
name='FIG_AGE_PROFILE_LABOR_INCOME_MALES_2';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	name2='FIG_AGE_PROFILE_LABOR_INCOME';
	data=[(25:60)' age_profile];
	tbl1 = table({'Age','Mean earnings'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name2,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name2,'Range','A3','WriteVariableNames',false);
end

%% Life cycle profile of earnings with a quartic fit
xage=(1:36)/10;
p=polyfit(xage,age_profile',4);
fit=polyval(p,xage);

figure;
% h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.115);
hold on; grid on;
plot(25:60,age_profile,style(4,:),'Color',colors(1,:)); xlim([24 61]);
plot(25:60,age_profile,style(1,:),'Color',colors(3,:)); xlim([24 61]);
plot(23:57,max(age_profile)*ones(1,35),style(2,:),'Color',colors(5,:),'linewidth',0.5)
plot(23:28,age_profile(1)*ones(1,6),style(2,:),'Color',colors(5,:),'linewidth',0.5)
x1=22; x2=62; y1=9.5; y2=10.6; st=0.2;
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',25:5:60); set(gca,'XTickLabel',25:5:60);
xlabel('Age'); ylabel('Average Log Earnings');
xarr = [0.18 0.18]; yarr = [0.20 0.9];
txtar = annotation('doublearrow',xarr,yarr,'linewidth',0.5,...
	'linestyle','--','color',colors(3,:)); %#ok<NASGU>
xbox = [0.19 0.19 0.5 0.5];
txtar = annotation('textbox','position',xbox,'String',{'154%' 'rise'},...
	'fontsize',24,'linestyle','none','fontweight','bold'); %#ok<NASGU>
set(gcf,'units','normalized','position',position);
% name='FIG_AGE_PROFILE_LABOR_INCOME_MALES_2_polynomial';
% saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

%% Income growth 25-55 (non-imputed)
temp=0.85*ones(100,1);

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.04);
hold on; grid on;
line_fewer_markers(1:100,meanLTinc2555,25,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
plot(1:100,temp,'-','Color',[1 0 0]);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k','linewidth',1.5,'linestyle','--');
xlabel('Percentiles of Lifetime Earnings Distribution','FontSize',32);
% ylabel('$\log(\overline{Y}_{55})-\log(\overline{Y}_{25})$');
x1=0; x2=100; y1=-1; y2=4; st=1;
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
x50 = [0.47 0.45]; y50 = [0.53 0.44];
txtar = annotation('textarrow',x50,y50,'String','150% Income Growth from Pooled Regression',...
	'fontsize',28,'linewidth',0.5,'fontweight','bold'); %#ok<NASGU>
x1 = [0.77 0.95]; y1=[0.79 0.84];
txtar2 = annotation('textarrow',x1,y1,'String',{'Top 1%:', '2700% increase'},...
	'fontsize',28,'linewidth',0.5,'fontweight','bold','HorizontalAlignment','center',...
	'VerticalAlignment','middle'); %#ok<NASGU>
x2 = [0.605 0.515]; y2=[0.19 0.34];
txtar3 = annotation('textarrow',x2,y2,'String',{'Median worker:','60% increase'},...
	'fontsize',28,'linewidth',0.5,'fontweight','bold','HorizontalAlignment','center',...
	'VerticalAlignment','middle'); %#ok<NASGU>
% pbaspect([1.5 1 1]);
set(gcf,'units','normalized','position',position);
name='Income_Growth_25_55';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' temp*size(meanLTinc2555) meanLTinc2555];
	tbl1 = table({'LE percentile','Income Growth 25-55','Income Growth from Pooled Regression'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Income growth 25-55 (imputed)
temp=0.85*ones(100,1);

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.04);
hold on; grid on;
line_fewer_markers(1:100,meanLTinc2555_imp,25,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
plot(1:100,temp,'-','Color',[1 0 0]);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k','linewidth',1.5,'linestyle','--');
xlabel('Percentiles of Lifetime Earnings Distribution','FontSize',32);
% ylabel('$\log(\overline{Y}_{55})-\log(\overline{Y}_{25})$');
x1=0; x2=100; y1=-1; y2=4; st=1;
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
x50 = [0.47 0.45]; y50 = [0.53 0.44];
txtar = annotation('textarrow',x50,y50,'String','150% Income Growth from Pooled Regression',...
	'fontsize',28,'linewidth',0.5,'fontweight','bold');
x1 = [0.77 0.95]; y1=[0.78 0.83];
txtar2 = annotation('textarrow',x1,y1,'String',{'Top 1%:', '2700% increase'},...
	'fontsize',28,'linewidth',0.5,'fontweight','bold','HorizontalAlignment','center',...
	'VerticalAlignment','middle');
x2 = [0.605 0.515]; y2=[0.19 0.34];
txtar3 = annotation('textarrow',x2,y2,'String',{'Median worker:','60% increase'},...
	'fontsize',28,'linewidth',0.5,'fontweight','bold','HorizontalAlignment','center',...
	'VerticalAlignment','middle');
% pbaspect([1.5 1 1]);
set(gcf,'units','normalized','position',position);
name='Income_Growth_25_55_imp';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

% if write_excel==1
% 	data=[(1:100)' meanLTinc2555_imp];
% 	xlswrite('incgrowth_moments.xlsx',{'LE percentile','Income Growth 25-55 (imputed)'},name,'A2');
% 	xlswrite('incgrowth_moments.xlsx',data,name,'A3');
% end

%% Imputed vs. Non-imputed: Income growth 25-55
% temp=0.85*ones(100,1);

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.09);
hold on; grid on;
line_fewer_markers(1:100,meanLTinc2555_imp,25,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,meanLTinc2555,25,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k','linewidth',1.5,'linestyle','--');
xlabel('Percentiles of Lifetime Earnings Distribution','FontSize',32);
ylabel('$\log(\overline{Y}_{55})-\log(\overline{Y}_{25})$');
x1=0; x2=100; y1=-1; y2=4; st=1;
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
leg=legend('Imputed data','Non-imputed data'); set(leg,'FontSize',lfsize,'Location','Best');
set(gcf,'units','normalized','position',position);
name='Income_Growth_25_55_imp_nonimp';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' meanLTinc2555 meanLTinc2555_imp];
	tbl1 = table({'Income Growth 25-55'});
	tbl2 = table({'LE percentile','Non-imputed','Imputed'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

%% Different starting ages
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.09);
hold on; grid on;
line_fewer_markers(1:100,meanLTinc2555,25,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,meanLTinc3055,25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,meanLTinc3555,25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k','linewidth',1.5,'linestyle','--');
x1=0; x2=100; y1=-1; y2=4; st=1; axis([x1,x2,y1,y2]);
set(gca,'YTick',y1:st:y2); set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
xlabel('Percentiles of Lifetime Earnings Distribution','FontSize',32); ylabel('Average Income Growth (in logs)');
leg=legend('Overall, 25-55','30-55','35-55','Zero line','location','nw'); set(leg,'FontSize',lfsize);
set(gcf,'units','normalized','position',position);
name='IncomeGrowth1';
saveas(h,[name '.fig'],'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' meanLTinc2555 meanLTinc3055 meanLTinc3555];
	tbl1 = table({'Lifetime Income Growth with different starting ages'});
	tbl2 = table({'LE percentile','25-55','30-55','35-55'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

%% By Decades
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.09);
hold on; grid on;
line_fewer_markers(1:100,meanLTinc2555,25,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,meanLTinc2535,25,style(1,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,meanLTinc3545,25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,meanLTinc4555,25,'-','Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k','linewidth',1.5,'linestyle','--');
x1=0; x2=100; y1=-1; y2=4; st=1; axis([x1,x2,y1,y2]);
set(gca,'YTick',y1:st:y2); set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
xlabel('Percentiles of Lifetime Earnings Distribution','FontSize',32); ylabel('Average Income Growth (in logs)');
leg=legend('Overall, 25-55','25-35','35-45','45-55','Zero line','location','northwest'); set(leg,'FontSize',lfsize);
set(gcf,'units','normalized','position',position);
name='IncomeGrowth2';
saveas(h,[name '.fig'],'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' meanLTinc2555 meanLTinc2535 meanLTinc3545 meanLTinc4555];
	tbl1 = table({'Income Growth by Decades'});
	tbl2 = table({'LE percentile','25-55','25-34','35-44','45-55'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

%% Fraction top coded
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.09);
hold on; grid on;
line_fewer_markers(1:100,100*frac_topcode(:,1),25,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,100*frac_topcode(:,6),25,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,100*frac_topcode(:,11),25,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,100*frac_topcode(:,16),25,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
xlabel('Percentiles of Lifetime Earnings Distribution','FontSize',32);
ylabel('Fraction of top-coded observations, $\%$');
leg=legend('25','30','35','40','location','northwest'); set(leg,'FontSize',lfsize);
x1=0; x2=100; y1=0; y2=10; st=2; axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2);
set(gcf,'units','normalized','position',position);
name='frac_topcoded';
saveas(h,[name '.fig'],'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' 100*frac_topcode(:,1) 100*frac_topcode(:,6) 100*frac_topcode(:,11) 100*frac_topcode(:,16)];
	tbl1 = table({'Percentage of top-coded observations by age'});
	tbl2 = table({'LE percentile','Age 25','Age 30','Age 35','Age 40'});
	tbl3 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end