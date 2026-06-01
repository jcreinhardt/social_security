clear; close all; clc;
user=3;				% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=1;		% =1 update excel file
k=5;
nmrkr=25;			% #markers in each plot
position=[0.1,0.1,0.50,0.68];

% varname=['$\Delta_{log}Y^i_{t,' num2str(k) '}$']; %['$(y_{t+' num2str(k) '}-y_{t})$'];
varname=['$\Delta_{log}^{' num2str(k) '}Y^i_{t}$'];

% Defaults for plots
ftsize=25;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); ms=20; set(0,'defaultLineMarkerSize',ms);
set(0,'defaultlinelinewidth',3.2); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',24); lfsize=30;
% Same colors for stayers and switchers
mfcolor = [1 0.6 0.78; 0.0 1.0 1.0; 0.00 1.00 0.00; 1 0.6 0.78; 0.0 1.0 1.0; 0.00 1.00 0.00; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0.0 0.0 1.0; 0.11 0.53 0.10; 1 0.0 0.00; 0.0 0.0 1.0; 0.11 0.53 0.10; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor;
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.03; mrg_btm=0.12; mrg_lft=0.07;

folder=char('10_May_2016_STAY_LABOR_EIN');
folder2=char('1_June_2016_STAY_LABOR_EIN');
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
elseif(user==3) % f. karahan mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/CrossSectional/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');
end
input  = [userdirectory 'Input' sep folder sep];
input2 = [userdirectory 'Input' sep folder2 sep];
output = [userdirectory 'Output' sep 'Stayers'];
filename = 'cross_moments_stay_switch.xlsx';
filename=[userdirectory 'Output' sep filename];
tlast=2012-k;
tbegin=1997;
for t=tbegin:tlast
	cd([input 'YRCHANGE' num2str(t) num2str(t+1)]);
	K=importdata(['Dreslaborch' num2str(t) num2str(t+k) 'stayIIv2.txt']);

	PRarr(t-tbegin+1,:,:)=K.data; %#ok<*SAGROW>
	n(:,t-tbegin+1)=PRarr(t-tbegin+1,:,4);
	sd(:,t-tbegin+1)=PRarr(t-tbegin+1,:,6);
	skew(:,t-tbegin+1)=PRarr(t-tbegin+1,:,7);
	kurt(:,t-tbegin+1)=PRarr(t-tbegin+1,:,8);

	cd([input2 'YRCHANGE' num2str(t) num2str(t+1)]);
	K2=importdata(['PC_reslaborch' num2str(t) num2str(t+k) '.txt']);
	PRarr2(t-tbegin+1,:,:)=K2.data;

	p1(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,4);
	p2(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,5);
	p5(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,6);
	p10(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,7);
	p12(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,8);
	p25(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,9);
	p37(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,10);
	p50(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,11);
	p62(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,12);
	p75(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,13);
	p87(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,14);
	p90(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,15);
	p95(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,16);
	p97(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,17);
	p99(:,t-tbegin+1)=PRarr2(t-tbegin+1,:,18);
end
kellys=((p90-p50)-(p50-p10))./(p90-p10);
hinkley=((p99-p50)-(p50-p1))./(p99-p1);
moors=((p87-p62)+(p37-p12))./(p75-p25); % for Gaussian, this is 1.23.
crows=(p97-p2)./(p75-p25);				% for Gaussian, this is 2.91.
p90_10=p90-p10;
for age=1:3
	nage(age,:)=mean(n((age-1)*200+1:age*200,:),2)';
	sdage(age,:)=mean(sd((age-1)*200+1:age*200,:),2)';
	p90_10age(age,:)=mean(p90_10((age-1)*200+1:age*200,:),2)';
	skewage(age,:)=mean(skew((age-1)*200+1:age*200,:),2)';
	kellyage(age,:)=mean(kellys((age-1)*200+1:age*200,:),2)';
	kurtage(age,:)=mean(kurt((age-1)*200+1:age*200,:),2)';
	hinkleyage(age,:)=mean(hinkley((age-1)*200+1:age*200,:),2)';
	moorsage(age,:)=mean(moors((age-1)*200+1:age*200,:),2)';
	crowsage(age,:)=mean(crows((age-1)*200+1:age*200,:),2)';
	p1age(age,:)=mean(p1((age-1)*200+1:age*200,:),2)';
	p5age(age,:)=mean(p5((age-1)*200+1:age*200,:),2)';
	p10age(age,:)=mean(p10((age-1)*200+1:age*200,:),2)';
	p25age(age,:)=mean(p25((age-1)*200+1:age*200,:),2)';
	p50age(age,:)=mean(p50((age-1)*200+1:age*200,:),2)';
	p75age(age,:)=mean(p75((age-1)*200+1:age*200,:),2)';
	p90age(age,:)=mean(p90((age-1)*200+1:age*200,:),2)';
	p95age(age,:)=mean(p95((age-1)*200+1:age*200,:),2)';
	p99age(age,:)=mean(p99((age-1)*200+1:age*200,:),2)';
end
cd(output);

%% Fraction of stayers by age group
for i=1:3
	frac_stay(i,:)=nage(i,2:2:200)./(nage(i,1:2:200)+nage(i,2:2:200));
end
h=figure;
subaxis(1,1,1,'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,frac_stay(1,:),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,frac_stay(2,:),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,frac_stay(3,:),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34','35-44','45-54');
set(leg,'FontSize',lfsize,'location','southeast');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
ylabel('Fraction of Job Stayers');
if k==1
	x1=0; x2=100; y1=0.15; y2=0.75; st=0.1;
else
	x1=0; x2=100; y1=0.05; y2=0.55; st=0.1;
end
axis([x1,x2,y1,y2]); set(gca,'YTick',y1:st:y2);
set(gca,'XTick',x1:20:x2); set(gca,'XTickLabel',x1:20:x2)
set(gcf,'units','normalized','position',position);
name='frac_stayers';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' frac_stay'];
	tbl0 = table({'Fraction of job stayers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

%% Cross-sectional moments for stayers and switchers
h=figure;
subaxis(1,1,1,'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,sdage(1,1:2:200),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,sdage(1,2:2:200),nmrkr,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,sdage(2,1:2:200),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,sdage(2,2:2:200),nmrkr,style(5,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,sdage(3,1:2:200),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,sdage(3,2:2:200),nmrkr,style(6,:),'Color',colors(6,:),...
	'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
leg=legend('Switchers, 25-34','Stayers, 25-34','Switchers, 35-44','Stayers, 35-44', ...
	'Switchers, 45-54','Stayers, 45-54');
set(leg,'FontSize',lfsize,'location','north');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Standard Deviation of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_StdDev_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' sdage(:,2:2:200)' sdage(:,1:2:200)'];
	tbl0 = table({'Standard deviation of earnings changes'});
	tbl3 = table({'Stayers'});
	tbl4 = table({'Switchers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B3','WriteVariableNames',false);
	writetable(tbl4,filename,'Sheet',name,'Range','E3','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A5','WriteVariableNames',false);
end


h=figure;
idx=1:100;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,smooth(idx,skewage(1,1:2:200),0.4,'loess'),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,smooth(idx,skewage(1,2:2:200),0.4,'loess'),nmrkr,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,smooth(idx,skewage(2,1:2:200),0.4,'loess'),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,smooth(idx,skewage(2,2:2:200),0.4,'loess'),nmrkr,style(5,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,smooth(idx,skewage(3,1:2:200),0.4,'loess'),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,smooth(idx,skewage(3,2:2:200),0.4,'loess'),nmrkr,style(6,:),'Color',colors(6,:),...
	'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('Switchers, 25-34','Stayers, 25-34','Switchers, 35-44', ...
% 	'Stayers, 35-44','Switchers, 45-54','Stayers, 45-54');
% set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Skewness of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Skew_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' skewage(:,2:2:200)' skewage(:,1:2:200)'];
	tbl0 = table({'Skewness of earnings changes'});
	tbl3 = table({'Stayers'});
	tbl4 = table({'Switchers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B3','WriteVariableNames',false);
	writetable(tbl4,filename,'Sheet',name,'Range','E3','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A5','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,kellyage(1,1:2:200),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,kellyage(1,2:2:200),nmrkr,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,kellyage(2,1:2:200),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,kellyage(2,2:2:200),nmrkr,style(5,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,kellyage(3,1:2:200),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,kellyage(3,2:2:200),nmrkr,style(6,:),'Color',colors(6,:),...
	'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('Switchers, 25-34','Stayers, 25-34','Switchers, 35-44','Stayers, 35-44', ...
% 	'Switchers, 45-54','Stayers, 45-54');
% set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Kelley Skewness of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Kelly_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kellyage(:,2:2:200)' kellyage(:,1:2:200)'];
	tbl0 = table({'Kelley Skewness of earnings changes'});
	tbl3 = table({'Stayers'});
	tbl4 = table({'Switchers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B3','WriteVariableNames',false);
	writetable(tbl4,filename,'Sheet',name,'Range','E3','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A5','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.055);
line_fewer_markers(1:100,kurtage(1,1:2:200),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,kurtage(1,2:2:200),nmrkr,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,kurtage(2,1:2:200),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,kurtage(2,2:2:200),nmrkr,style(5,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,kurtage(3,1:2:200),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,kurtage(3,2:2:200),nmrkr,style(6,:),'Color',colors(6,:),...
	'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
% leg=legend('Switchers, 25-34','Stayers, 25-34','Switchers, 35-44', ...
% 	'Stayers, 35-44','Switchers, 45-54','Stayers, 45-54');
% set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Kurtosis of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Kurt_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' kurtage(:,2:2:200)' kurtage(:,1:2:200)'];
	tbl0 = table({'Kurtosis of earnings changes'});
	tbl3 = table({'Stayers'});
	tbl4 = table({'Switchers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B3','WriteVariableNames',false);
	writetable(tbl4,filename,'Sheet',name,'Range','E3','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A5','WriteVariableNames',false);
end

%% Condensed versions
h=figure;
subaxis(1,1,1,'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.055);
line_fewer_markers(1:100,mean(sdage(1:3,1:2:200),1),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(sdage(1:3,2:2:200),1),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
leg=legend('Switchers','Stayers'); set(leg,'FontSize',lfsize,'location','north');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Standard Deviation of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_StdDev_stay_switch_condensed'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' mean(sdage(1:3,2:2:200),1)' mean(sdage(1:3,1:2:200),1)'];
	tbl0 = table({'Standard deviation of earnings changes'});
	tbl1 = table({'RE Pctile','Stayers','Switchers'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,smooth(idx,mean(skewage(1:3,1:2:200),1),0.4,'loess'),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,smooth(idx,mean(skewage(1:3,2:2:200),1),0.4,'loess'),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('Switchers','Stayers'); set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Skewness of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Skew_stay_switch_condensed'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' smooth(idx,mean(skewage(1:3,2:2:200),1),0.4,'loess') smooth(idx,mean(skewage(1:3,1:2:200),1),0.4,'loess')];
	tbl0 = table({'Skewness of earnings changes'});
	tbl1 = table({'RE Pctile','Stayers','Switchers'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
line_fewer_markers(1:100,mean(kellyage(1:3,1:2:200),1),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(kellyage(1:3,2:2:200),1),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
ref=refline(0,0); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
% leg=legend('Switchers','Stayers'); set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Kelley Skewness of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Kelly_stay_switch_condensed'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' mean(kellyage(1:3,2:2:200),1)' mean(kellyage(1:3,1:2:200),1)'];
	tbl0 = table({'Kelley skewness of earnings changes'});
	tbl1 = table({'RE Pctile','Stayers','Switchers'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.052);
line_fewer_markers(1:100,mean(kurtage(1,1:2:200),1),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(kurtage(1,2:2:200),1),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
% leg=legend('Switchers','Stayers'); set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Kurtosis of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Kurt_stay_switch_condensed'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' mean(kurtage(1:3,2:2:200),1)' mean(kurtage(1:3,1:2:200),1)'];
	tbl0 = table({'Kurtosis of earnings changes'});
	tbl1 = table({'RE Pctile','Stayers','Switchers'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

%% Percentile-based moments
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.06);
line_fewer_markers(1:100,p90_10age(1,1:2:200),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,p90_10age(1,2:2:200),nmrkr,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,p90_10age(2,1:2:200),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,p90_10age(2,2:2:200),nmrkr,style(5,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,p90_10age(3,1:2:200),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,p90_10age(3,2:2:200),nmrkr,style(6,:),'Color',colors(6,:),...
	'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
leg=legend('Switchers, 25-34','Stayers, 25-34','Switchers, 35-44','Stayers, 35-44', ...
	'Switchers, 45-54','Stayers, 45-54');
set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['P90-10 of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_P90_10_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' p90_10age(1,2:2:200)' p90_10age(2,2:2:200)' p90_10age(3,2:2:200)' p90_10age(1,1:2:200)' p90_10age(2,1:2:200)' p90_10age(3,1:2:200)'];
	tbl0 = table({'P90-P10 of earnings changes'});
	tbl3 = table({'Stayers'});
	tbl4 = table({'Switchers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B3','WriteVariableNames',false);
	writetable(tbl4,filename,'Sheet',name,'Range','E3','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A5','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.054);
line_fewer_markers(1:100,crowsage(1,1:2:200),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,crowsage(1,2:2:200),nmrkr,style(4,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,crowsage(2,1:2:200),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,crowsage(2,2:2:200),nmrkr,style(5,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,crowsage(3,1:2:200),nmrkr,style(3,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,crowsage(3,2:2:200),nmrkr,style(6,:),'Color',colors(6,:),...
	'MarkerFaceColor',mfcolor(6,:),'MarkerEdgeColor',mecolor(6,:),'MarkerSize',ms);
% ref=refline(0,2.91); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Crows Kurtosis of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Crows_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' crowsage(1,2:2:200)' crowsage(2,2:2:200)' crowsage(3,2:2:200)' crowsage(1,1:2:200)' crowsage(2,1:2:200)' crowsage(3,1:2:200)'];
	tbl0 = table({'Crow-Siddiqui of earnings changes'});
	tbl3 = table({'Stayers'});
	tbl4 = table({'Switchers'});
	tbl1 = table({'RE Pctile','25-34','35-44','45-54','25-34','35-44','45-54'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B3','WriteVariableNames',false);
	writetable(tbl4,filename,'Sheet',name,'Range','E3','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A5','WriteVariableNames',false);
end

%% Condensed versions
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.054);
line_fewer_markers(1:100,mean(p90_10age(1:3,1:2:200),1),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(p90_10age(1:3,2:2:200),1),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
leg=legend('Switchers','Stayers'); set(leg,'FontSize',lfsize,'location','best');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['P90-10 of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_P90_10_stay_switch_condensed'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' mean(p90_10age(1:3,2:2:200),1)' mean(p90_10age(1:3,1:2:200),1)'];
	tbl0 = table({'P90-P10 of earnings changes'});
	tbl1 = table({'RE Pctile','Stayers','Switchers'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.054);
line_fewer_markers(1:100,mean(crowsage(1:3,1:2:200),1),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,mean(crowsage(1:3,2:2:200),1),nmrkr,style(2,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
% ref=refline(0,2.91); get(ref,'Color'); set(ref,'Color','k'); ref.LineStyle='--'; ref.LineWidth=1.5;
xlabel('Percentiles of Recent Earnings Distribution','FontSize',34)
% ylabel(['Crows Kurtosis of ' varname]);
set(gcf,'units','normalized','position',position);
name=['L' num2str(k) '_Crows_stay_switch_condensed'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[(1:100)' mean(crowsage(1:3,2:2:200),1)' mean(crowsage(1:3,1:2:200),1)'];
	tbl0 = table({'Crow-Siddiqui of earnings changes'});
	tbl1 = table({'RE Pctile','Stayers','Switchers'});
	tbl2 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
end

%% Percentiles
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',0.043);
line_fewer_markers(1:100,p5age(2,1:2:200),nmrkr,style(1,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
line_fewer_markers(1:100,p5age(2,2:2:200),nmrkr,style(2,:),'Color',colors(1,:),...
	'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms);
line_fewer_markers(1:100,p10age(2,1:2:200),nmrkr,style(3,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,p10age(2,2:2:200),nmrkr,style(4,:),'Color',colors(2,:),...
	'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
line_fewer_markers(1:100,p50age(2,1:2:200),nmrkr,style(5,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,p50age(2,2:2:200),nmrkr,style(6,:),'Color',colors(3,:),...
	'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
line_fewer_markers(1:100,p90age(2,1:2:200),nmrkr,style(7,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,p90age(2,2:2:200),nmrkr,style(8,:),'Color',colors(4,:),...
	'MarkerFaceColor',mfcolor(4,:),'MarkerEdgeColor',mecolor(4,:),'MarkerSize',ms);
line_fewer_markers(1:100,p95age(2,1:2:200),nmrkr,style(9,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
line_fewer_markers(1:100,p95age(2,2:2:200),nmrkr,style(10,:),'Color',colors(5,:),...
	'MarkerFaceColor',mfcolor(5,:),'MarkerEdgeColor',mecolor(5,:),'MarkerSize',ms);
leg=legend('P5, switchers','P5, stayers','P10, switchers','P10, stayers',...
	'P50, switchers','P50, stayers','P90, switchers','P90, stayers',...
	'P95, switchers','P95, stayers');
set(leg,'FontSize',lfsize,'location','bestoutside','orientation','vertical');
xlabel('Percentiles of Recent Earnings Distribution','FontSize',32)
% ylabel(['Percentiles of ' varname]);
set(gcf,'units','normalized','position',[0.1,0.1,0.65,0.65]);
name=['L' num2str(k) '_Pctiles_stay_switch'];
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')
