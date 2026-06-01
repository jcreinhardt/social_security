clear; clc; close all;
user=3;					% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=1;		% =1 update excel file
nyr=5; k=(nyr+1)/2;		% nyr=1,3,5 (paper reports nyr=5)
nmrkr=25;				% #markers in each plot
position=[0.1,0.1,0.50,0.68];

% Defaults for plots
ftsize=25;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); ms=19; set(0,'defaultLineMarkerSize',ms);
set(0,'defaultlinelinewidth',3.2); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',24); lfsize=30;
mfcolor = [1 0.6 0.78; 0 1 1; 0.00 1.00 0.00; 0.8 0.8 0.8; 1.00 0.50 0.25; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0 0 1; 0.11 0.53 0.10; 0.0 0.0 0.0; 0.63 0.57 0.39; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor; %[0   1   0; 0 0 1; 0.99 0.53 0.06; 0.5 0.5 0.5; 1 0 0;  0    0    0; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
% colors = [0 0 1; 0 1 0; 1 0 0; 0.8 0.7 0.6; 0 0 0; 0 0.7 0.7; 1 0.5 0.25; 0.5 0.5 0; 1 0 1];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.03; mrg_btm=0.12; mrg_lft=0.06;

folder=char('6_Apr_2017_YRCHANGE_LABOR_NYR');
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
elseif(user==3) % f. karahan minn fed
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/CrossSectional/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
end
input  = [userdirectory 'Input' sep folder sep];
cd(input);

K=importdata('avgch_NYR.txt'); data=K.data; %#ok<*SAGROW>
output = [userdirectory 'Output' sep 'NYR' sep 'wrtRE'];
suf=['_NYR_RE_' num2str(nyr)];
% varname=['$\sum\limits_{j=0}^' num2str(nyr-1) 'Y_{t+j} - \overline{Y}$'];
varname='Average future inc. - Average past inc.';
filename=['cross_moments_NYR_past' suf '.xlsx'];
filename=[userdirectory 'Output' sep filename];

% Store percentiles
ind=2+(k-1)*15+1;
p1=data(:,ind);  ind=ind+1;
p2=data(:,ind);  ind=ind+1;
p5=data(:,ind);  ind=ind+1;
p10=data(:,ind); ind=ind+1;
p12=data(:,ind); ind=ind+1;
p25=data(:,ind); ind=ind+1;
p37=data(:,ind); ind=ind+1;
p50=data(:,ind); ind=ind+1;
p62=data(:,ind); ind=ind+1;
p75=data(:,ind); ind=ind+1;
p87=data(:,ind); ind=ind+1;
p90=data(:,ind); ind=ind+1;
p95=data(:,ind); ind=ind+1;
p97=data(:,ind); ind=ind+1;
p99=data(:,ind);
% Store centralized moments
ind=47+(k-1)*7+3;
sd=data(:,ind);   ind=ind+1;
skew=data(:,ind); ind=ind+1;
kurt=data(:,ind);
for age=1:7
	p1age(age,:)=mean(p1((age-1)*100+1:age*100,:),2)';
	p2age(age,:)=mean(p2((age-1)*100+1:age*100,:),2)';
	p5age(age,:)=mean(p5((age-1)*100+1:age*100,:),2)';
	p10age(age,:)=mean(p10((age-1)*100+1:age*100,:),2)';
	p12age(age,:)=mean(p12((age-1)*100+1:age*100,:),2)';
	p25age(age,:)=mean(p25((age-1)*100+1:age*100,:),2)';
	p37age(age,:)=mean(p37((age-1)*100+1:age*100,:),2)';
	p50age(age,:)=mean(p50((age-1)*100+1:age*100,:),2)';
	p62age(age,:)=mean(p62((age-1)*100+1:age*100,:),2)';
	p75age(age,:)=mean(p75((age-1)*100+1:age*100,:),2)';
	p87age(age,:)=mean(p87((age-1)*100+1:age*100,:),2)';
	p90age(age,:)=mean(p90((age-1)*100+1:age*100,:),2)';
	p95age(age,:)=mean(p95((age-1)*100+1:age*100,:),2)';
	p97age(age,:)=mean(p97((age-1)*100+1:age*100,:),2)';
	p99age(age,:)=mean(p99((age-1)*100+1:age*100,:),2)';
	sdage(age,:)=mean(sd((age-1)*100+1:age*100,:),2)';
	skewage(age,:)=mean(skew((age-1)*100+1:age*100,:),2)';
	kurtage(age,:)=mean(kurt((age-1)*100+1:age*100,:),2)';
end

% Compute some moments for young and prime age
py(:,1)=mean(p1age(1:2,:),1)';  py(:,2)=mean(p5age(1:2,:),1)';
py(:,3)=mean(p10age(1:2,:),1)'; py(:,4)=mean(p25age(1:2,:),1)';
py(:,5)=mean(p50age(1:2,:),1)'; py(:,6)=mean(p75age(1:2,:),1)';
py(:,7)=mean(p90age(1:2,:),1)'; py(:,8)=mean(p95age(1:2,:),1)';
py(:,9)=mean(p99age(1:2,:),1)';

po(:,1)=mean(p1age(3:6,:),1)'; po(:,2)=mean(p5age(3:6,:),1)';
po(:,3)=mean(p10age(3:6,:),1)'; po(:,4)=mean(p25age(3:6,:),1)';
po(:,5)=mean(p50age(3:6,:),1)'; po(:,6)=mean(p75age(3:6,:),1)';
po(:,7)=mean(p90age(3:6,:),1)'; po(:,8)=mean(p95age(3:6,:),1)';
po(:,9)=mean(p99age(3:6,:),1)';

py(:,1)=mean(p1age(1:2,:),1)';  py(:,2)=mean(p5age(1:2,:),1)';
py(:,3)=mean(p10age(1:2,:),1)'; py(:,4)=mean(p25age(1:2,:),1)';
py(:,5)=mean(p50age(1:2,:),1)'; py(:,6)=mean(p75age(1:2,:),1)';
py(:,7)=mean(p90age(1:2,:),1)'; py(:,8)=mean(p95age(1:2,:),1)';
py(:,9)=mean(p99age(1:2,:),1)';

po(:,1)=mean(p1age(3:6,:),1)';  po(:,2)=mean(p5age(3:6,:),1)';
po(:,3)=mean(p10age(3:6,:),1)'; po(:,4)=mean(p25age(3:6,:),1)';
po(:,5)=mean(p50age(3:6,:),1)'; po(:,6)=mean(p75age(3:6,:),1)';
po(:,7)=mean(p90age(3:6,:),1)'; po(:,8)=mean(p95age(3:6,:),1)';
po(:,9)=mean(p99age(3:6,:),1)';

piy(1,:)=py(1,:); pio(1,:)=po(1,:);
piy(2,:)=mean(py(2:10,:),1); pio(2,:)=mean(po(2:10,:),1);
for j=1:8
    piy(2+j,:)=mean(py(10*j+1:10*(j+1),:),1);
    pio(2+j,:)=mean(po(10*j+1:10*(j+1),:),1);
end
piy(11,:)=mean(py(91:95,:),1); pio(11,:)=mean(po(91:95,:),1);
piy(12,:)=mean(py(96:99,:),1); pio(12,:)=mean(po(96:99,:),1);
piy(13,:)=py(100,:); pio(13,:)=po(100,:);

sdy=mean(sdage(1:2,:),1); sdo=mean(sdage(3:6,:),1);

% Percentile-based moments
kellys=((p90-p50)-(p50-p10))./(p90-p10);
hinkley=((p99-p50)-(p50-p1))./(p99-p1);
moors=((p87-p62)+(p37-p12))./(p75-p25); % for Gaussian, this is 1.23.
crows=(p97-p2)./(p75-p25);				% for Gaussian, this is 2.91.
p90_10=p90age-p10age;
p90_50=p90age-p50age;
p50_10=p50age-p10age;
for age=1:7
	kellysage(age,:)=mean(kellys((age-1)*100+1:age*100,:),2)';
	hinkleyage(age,:)=mean(hinkley((age-1)*100+1:age*100,:),2)';
	moorsage(age,:)=mean(moors((age-1)*100+1:age*100,:),2)';
	crowsage(age,:)=mean(crows((age-1)*100+1:age*100,:),2)';
end

p10y=mean(p10age(1:2,:),1); p10o=mean(p10age(3:6,:),1);
p50y=mean(p50age(1:2,:),1); p50o=mean(p50age(3:6,:),1);
p90y=mean(p90age(1:2,:),1); p90o=mean(p90age(3:6,:),1);

cd(output);

%% Distribution of Shocks for Prime Age Males (various percentiles of the shock distribution)
% set(0,'defaultAxesFontSize',15);
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',0.12,'MarginLeft',0.04);
line_fewer_markers(1:100,po(:,2),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,po(:,3),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,4),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,5),nmrkr,style(4,:),'Color',colors(4,:),'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,6),nmrkr,style(5,:),'Color',colors(5,:),'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,7),nmrkr,style(6,:),'Color',colors(6,:),'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,8),nmrkr,style(7,:),'Color',colors(7,:),'MarkerFaceColor',mfcolor(7,:),'MarkerEdgeColor',mecolor(7,:),'MarkerSize',ms);
line_fewer_markers(1:100,po(:,9),nmrkr,style(8,:),'Color',colors(8,:),'MarkerFaceColor',mfcolor(8,:),'MarkerEdgeColor',mecolor(8,:),'MarkerSize',ms);

xlabel('Percentiles of Recent Earnings (RE) Distribution','fontsize',27)
% ylabel('Percentiles','fontsize',26); % ylabel(['Percentiles of  ' varname],'fontsize',26);
x1=0; x2=100; % axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
leg=legend('P5','P10','P25','P50','P75','P90','P95','P99');
set(leg,'FontSize',23,'location','north','orientation','horizontal');
set(gcf,'units','normalized','position',[0.1,0.1,0.75,0.65]);
name=['PrimeAge_vase' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')
% set(0,'defaultAxesFontSize',13);

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
leg=legend('25-34', '35-44', '45-54', 'location', 'best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('Standard Deviation'); % ylabel(['Standard Deviation of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['StdDev' suf];
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
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('P90-P10'); % ylabel(['P90-P10 of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['P90_10' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' p90_10(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Skewness of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.065);
line_fewer_markers(1:100,mean(skewage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on; %#ok<*UDIM>
line_fewer_markers(1:100,mean(skewage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(skewage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34', '35-44', '45-54','location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34);
% ylabel('Skewness'); % ylabel(['Skewness of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['Skew' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' skewage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Kelley's Skewness Measure of Shocks
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.073);
line_fewer_markers(1:100,mean(kellysage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(kellysage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kellysage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34','35-44','45-54','Location','Best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('Kelley Skewness'); % ylabel(['Kelley Skewness of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['KellySkew' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kellysage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Kelley's skewness decomposed: P90-P50 vs. P50-P10
p90_50_frac=p90_50./p90_10;
p50_10_frac=p50_10./p90_10;
for age=2:3
	p90_50_rel(age-1,:)=mean(p90_50(2+(age-2)*2+1:4+(age-2)*2,:),1)-mean(p90_50(1:2,:),1);
	p50_10_rel(age-1,:)=mean(p50_10(2+(age-2)*2+1:4+(age-2)*2,:),1)-mean(p50_10(1:2,:),1);
end

% Relative to age 25-29
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.08);
line_fewer_markers(1:100,p90_50_rel(1,:)',nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,p90_50_rel(2,:)',nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('35-44','45-54','Zero line','Location','Best'); % set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34);
% ylabel('P90-P50 (Relative to P90-P50 at age 25-34)','FontSize',13);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['P90_50_rel' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data = [(1:100)' p90_50_rel(1:2,:)'];
	tbl1 = table({'RE Pctile','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.08);
line_fewer_markers(1:100,p50_10_rel(1,:)',nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,p50_10_rel(2,:)',nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('35-44','45-54','Zero line','Location','Best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34);
% ylabel('P50-P10 (Relative to P50-P10 at age 25-34)','FontSize',13);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['P50_10_rel' suf];
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
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,mean(kurtage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(kurtage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(kurtage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
% leg=legend('25-34', '35-44', '45-54', 'Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('Kurtosis'); % ylabel(['Kurtosis of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['Kurtosis' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kurtage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Alternative measures of skewness and kurtosis
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.065);
line_fewer_markers(1:100,mean(hinkleyage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(hinkleyage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(hinkleyage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
leg=legend('25-34','35-44','45-54','Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('Hinkley Skewness'); % ylabel(['Hinkley Skewness of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['Hinkley' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' hinkleyage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Moors kurtosis
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,mean(moorsage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(moorsage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(moorsage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,1.23); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34','35-44','45-54','Gaussian','Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('Moors Kurtosis'); % ylabel(['Moors Kurtosis of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['Moors' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' moorsage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end

%% Crow-Siddiqui
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.04);
line_fewer_markers(1:100,mean(crowsage(1:2,:),1),nmrkr,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);  hold on; grid on;
line_fewer_markers(1:100,mean(crowsage(3:4,:),1),nmrkr,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,mean(crowsage(5:6,:),1),nmrkr,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
ref=refline(0,2.91); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('25-34','35-44','45-54','Gaussian','Location','best'); set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel('Crows Kurtosis'); % ylabel(['Crows Kurtosis of ' varname]);
x1=0; x2=100; set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name=['Crows' suf];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' crowsage(1:6,:)'];
	tbl1 = table({'RE Pctile','25-29','30-34','35-39','40-44','45-49','50-54'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end
