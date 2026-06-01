clear; clc; close all; 
user=3;					% user=1-serdar; user=2-karahan (minn); user=3-karahan (ny)
write_excel=1;          % =1 update excel file
arc=0; k=5;	% k=1,5
if arc==1
	stop	% not reported in the paper
end

age=25:54;
age_ind=1:30;
if k==5
	age=25:54;
	age_ind=1:30;
end

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
mrg=0.03; mrg_btm=0.13; mrg_lft=0.14;

folder=char('12_Apr_2017_YRCHANGE_LABOR_BYAGE');
if(user==1) % serdar
    userdirectory=char('C:\Research\SSA-INCOME-RISK\EmpiricalResults\Revision\CrossSectional\');
	sep=char('\');
elseif(user==2) % f. karahan NY
    userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\CrossSectional\');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\subaxis\');
	addpath('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Matlab');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
elseif(user==3) % f. karahan Mac
    userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/CrossSectional/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
end
input  = [userdirectory 'Input' sep folder sep];
cd(input);

K=importdata(['L' num2str(k) '.txt']); data=K.data; %#ok<*SAGROW>
output = [userdirectory 'Output' sep 'Age'];
suf=['_BYAGE_L' num2str(k)];
varname=['$y_{t+' num2str(k) '}-y_{t}$'];
filename='cross_moments_BYAGE.xlsx';
filename=[userdirectory 'Output' sep filename];
cd(output)

% Store percentiles
if arc==0
	ind=2;
elseif arc==1
	ind=17;
end
p1=data(age_ind,ind);  ind=ind+1;
p2=data(age_ind,ind);  ind=ind+1;
p5=data(age_ind,ind);  ind=ind+1;
p10=data(age_ind,ind); ind=ind+1;
p12=data(age_ind,ind); ind=ind+1;
p25=data(age_ind,ind); ind=ind+1;
p37=data(age_ind,ind); ind=ind+1;
p50=data(age_ind,ind); ind=ind+1;
p62=data(age_ind,ind); ind=ind+1;
p75=data(age_ind,ind); ind=ind+1;
p87=data(age_ind,ind); ind=ind+1;
p90=data(age_ind,ind); ind=ind+1;
p95=data(age_ind,ind); ind=ind+1;
p97=data(age_ind,ind); ind=ind+1;
p99=data(age_ind,ind);
% Store centralized moments
if arc==0
	ind=34;
elseif arc==1
	ind=41;
end
sd=data(age_ind,ind);   ind=ind+1;
skew=data(age_ind,ind); ind=ind+1;
kurt=data(age_ind,ind);

% Percentile-based moments
kellys=((p90-p50)-(p50-p10))./(p90-p10);
hinkley=((p99-p50)-(p50-p1))./(p99-p1);
moors=((p87-p62)+(p37-p12))./(p75-p25); % for Gaussian, this is 1.23.
crows=(p97-p2)./(p75-p25);				% for Gaussian, this is 2.91.
p90_10=p90-p10;

cd(output);

%% Distribution of Shocks for Prime Age Males (various percentiles of the shock distribution)
set(0,'defaultAxesFontSize',15);
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',0.10,'MarginLeft',0.068);
plot(age,p5, style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); hold on; grid on;
plot(age,p10,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:))
plot(age,p25,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:))
plot(age,p50,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:))
plot(age,p75,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:))
plot(age,p90,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:))
plot(age,p95,style(7,:),'Color',colors(7,:),'MarkerFaceColor',mfcolor(7,:),'MarkerEdgeColor',mecolor(7,:))
plot(age,p99,style(8,:),'Color',colors(8,:),'MarkerFaceColor',mfcolor(8,:),'MarkerEdgeColor',mecolor(8,:))

xlabel('Age','fontsize',27)
ylabel(['Percentiles of  ' varname],'fontsize',26);
x1=25; x2=55; set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
leg=legend('P5','P10','P25','P50','P75','P90','P95','P99');
set(leg,'FontSize',23,'location','best','orientation','horizontal');
name=['PrimeAge_vase' suf];
set(gcf,'units','normalized','position',[0.1,0.1,0.75,0.65]);
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')
set(0,'defaultAxesFontSize',ftsize);

if write_excel==1
	data=[age' p5 p10 p25 p50 p75 p90 p95 p99];
	tbl1 = table({'Age','P5','P10','P25','P50','P75','P90','P95','P99'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Standard Deviation of Shocks for All Age Groups
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,sd,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
xlabel('Age'); ylabel(['Standard Deviation of ' varname]);
% x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
name=['StdDev' suf];
% saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[age' sd];
	tbl1 = table({'Age','Standard deviation'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,p90_10,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
xlabel('Age'); ylabel(['P90-P10 of ' varname]);
x1=25; x2=55; set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
name=['P90_10' suf];
% saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[age' p90_10];
	tbl1 = table({'Age','P90-P10'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Skewness of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);

plot(age,skew,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:));  grid on; %#ok<*UDIM>
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-29', '30-34', '35-39', '40-44', '45-49', '50-54','location','best');
% set(leg,'FontSize',lfsize);
xlabel('Age'); ylabel(['Skewness of ' varname]);
x1=25; x2=55; y1=-1.8; y2=0.3; st=0.3;
set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
name=['Skew' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[age' skew];
	tbl1 = table({'Age','Skewness'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Kelly's Skewness Measure of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,kellys,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;

% leg=legend('25-29','30-34','35-39','40-44','45-49','50-54','Location','Best');
% set(leg,'FontSize',lfsize);
xlabel('Age'); ylabel(['Kelley Skewness of ' varname]);
x1=25; x2=55; set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
name=['KellySkew' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[age' kellys];
	tbl1 = table({'Age','Kelley Measure'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Kurtosis of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,kurt,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
xlabel('Age'); ylabel(['Kurtosis of ' varname]);
x1=25; x2=55;
if k==1
	y1=7; y2=17; st=2;
else
	y1=5; y2=15; st=2;
end
set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
name=['Kurtosis' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[age' kurt];
	tbl1 = table({'Age','Kurtosis'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Alternative measures of skewness and kurtosis
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,hinkley,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
xlabel('Age'); ylabel(['Hinkley Skewness of ' varname]);
x1=25; x2=55;
if k==1
	y1=-0.25; y2=0.05; st=0.05;
else
	y1=-0.30; y2=0.05; st=0.05;
end
set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
name=['Hinkley' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

%% Moors kurtosis
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,moors,style(1,:),'Color',colors(1,:)); grid on;
ref=refline(0,1.23); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
xlabel('Age'); ylabel(['Moors Kurtosis of ' varname]);
x1=25; x2=55;
if k==1
	y1=1; y2=3.5; st=0.5;
else
	y1=1; y2=3; st=0.5;
end
set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
name=['Moors' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

%% Crow-Siddiqui
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(age,crows,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
ref=refline(0,2.91); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
xlabel('Age'); ylabel(['Crows Kurtosis of ' varname]);
x1=25; x2=55; y1=2; y2=14; st=2;
set(gca,'XTick',x1:5:x2); set(gca,'XTickLabel',x1:5:x2)
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
name=['Crows' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[age' crows];
	tbl1 = table({'Age','Crow-Siddiqui Measure'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end