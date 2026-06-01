clear; close all; clc;
arc=1;
user=3;                 % user=1-serdar; user=2-karahan fed; user=3-karahan mac
write_excel=1;			% =1 update excel file

folder=char('8_Jan_2016_YRCHANGE_LABOR');
if(user==1) % serdar
	userdirectory=char('C:\Research\SSA-INCOME-RISK\EmpiricalResults\Revision2\CrossSectional\');
	sep=char('\');
elseif(user==2) % f. karahan ny fed
	userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\CrossSectional\');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\Matlab\subaxis\');
	addpath('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Matlab');
	addpath('C:\Users\rceyfk01\Dropbox\Matlab\export_fig');
elseif(user==3) % f. karahan mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/CrossSectional/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
end
filename='cross_moments_estimation.xlsx';
filename=[userdirectory 'Output' sep filename];

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

% input  = [userdirectory 'Input' sep folder sep];
input  = [userdirectory 'Input' sep];
output = [userdirectory 'Output' sep 'Estimation' sep];
if arc==1
	var2=char('D_resAlaborch');
	suf='arc';
else
	var2=char('D_reslaborch');
	suf='log';
end

cd(input)
K1=importdata('SdSkewKurt_L1.dat');
for age=1:3
	sd_final(1,age,:)	= K1((age-1)*13+1:age*13,1); %#ok<*SAGROW>
	skew_final(1,age,:) = K1((age-1)*13+1:age*13,2);
	kurt_final(1,age,:) = K1((age-1)*13+1:age*13,3);
end
sd1	  = reshape(sd_final(1,:,:),3,13)';
skew1 = reshape(skew_final(1,:,:),3,13)';
kurt1 = reshape(kurt_final(1,:,:),3,13)';

K5=importdata('SdSkewKurt_L5.dat');
for age=1:3
	sd_final(2,age,:)	= K5((age-1)*13+1:age*13,1);
	skew_final(2,age,:) = K5((age-1)*13+1:age*13,2);
	kurt_final(2,age,:) = K5((age-1)*13+1:age*13,3);
end
sd5	  = reshape(sd_final(2,:,:),3,13)';
skew5 = reshape(skew_final(2,:,:),3,13)';
kurt5 = reshape(kurt_final(2,:,:),3,13)';

cd(output); clc;

%% Plots
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(1:13,reshape(sd_final(1,1,:),1,13),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
plot(1:13,reshape(sd_final(1,2,:),1,13),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
plot(1:13,reshape(sd_final(1,3,:),1,13),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel('Standard Deviation of $\Delta_a y^i_t$');
xlim([1 13]); set(gca,'XTick',1:2:13);
% set(gca,'XTickLabel',{'1','2-10','11-20','21-30','31-40','41-50','51-60',...
% 	'61-70','71-80','81-90','91-95','96-99','100'});
set(gca,'XTickLabel',{'1','11-20','31-40','51-60','71-80','91-95','100'});
name='L1_Stdev_Estimation';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[reshape(sd_final(1,1,:),13,1) reshape(sd_final(1,2,:),13,1) reshape(sd_final(1,3,:),13,1)];
	tbl0 = table({'Standard deviation of annual changes'});
	tbl1 = table({'RE Pctile','25-34', '35-44', '45-54'});
	tbl2 = table({'P1';'P2-P10';'P11-P20';'P21-P30';'P31-P40';'P41-P50';'P51-P60';'P61-P70';'P71-P80';'P81-P90';'P91-P95';'P96-P99';'P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(1:13,reshape(sd_final(2,1,:),1,13),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
plot(1:13,reshape(sd_final(2,2,:),1,13),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
plot(1:13,reshape(sd_final(2,3,:),1,13),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel('Standard Deviation of $\Delta_a y^i_t$');
xlim([1 13]); set(gca,'XTick',1:2:13);
set(gca,'XTickLabel',{'1','11-20','31-40','51-60','71-80','91-95','100'});
name='L5_Stdev_Estimation';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[reshape(sd_final(2,1,:),13,1) reshape(sd_final(2,2,:),13,1) reshape(sd_final(2,3,:),13,1)];
	tbl0 = table({'Standard deviation of five-year changes'});
	tbl1 = table({'RE Pctile','25-34', '35-44', '45-54'});
	tbl2 = table({'P1';'P2-P10';'P11-P20';'P21-P30';'P31-P40';'P41-P50';'P51-P60';'P61-P70';'P71-P80';'P81-P90';'P91-P95';'P96-P99';'P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',1.05*mrg_lft);
plot(1:13,reshape(skew_final(1,1,:),1,13),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
plot(1:13,reshape(skew_final(1,2,:),1,13),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
plot(1:13,reshape(skew_final(1,3,:),1,13),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel('Skewness of $\Delta_a y^i_t$');
xlim([1 13]); set(gca,'XTick',1:2:13);
set(gca,'XTickLabel',{'1','11-20','31-40','51-60','71-80','91-95','100'});
name='L1_Skew_Estimation';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[reshape(skew_final(1,1,:),13,1) reshape(skew_final(1,2,:),13,1) reshape(skew_final(1,3,:),13,1)];
	tbl0 = table({'Skewness of annual changes'});
	tbl1 = table({'RE Pctile','25-34', '35-44', '45-54'});
	tbl2 = table({'P1';'P2-P10';'P11-P20';'P21-P30';'P31-P40';'P41-P50';'P51-P60';'P61-P70';'P71-P80';'P81-P90';'P91-P95';'P96-P99';'P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',1.05*mrg_lft);
plot(1:13,reshape(skew_final(2,1,:),1,13),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
plot(1:13,reshape(skew_final(2,2,:),1,13),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
plot(1:13,reshape(skew_final(2,3,:),1,13),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel('Skewness of $\Delta_a y^i_t$');
xlim([1 13]); set(gca,'XTick',1:2:13);
set(gca,'XTickLabel',{'1','11-20','31-40','51-60','71-80','91-95','100'});
name='L5_Skew_Estimation';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[reshape(skew_final(2,1,:),13,1) reshape(skew_final(2,2,:),13,1) reshape(skew_final(2,3,:),13,1)];
	tbl0 = table({'Skewness of five-year changes'});
	tbl1 = table({'RE Pctile','25-34', '35-44', '45-54'});
	tbl2 = table({'P1';'P2-P10';'P11-P20';'P21-P30';'P31-P40';'P41-P50';'P51-P60';'P61-P70';'P71-P80';'P81-P90';'P91-P95';'P96-P99';'P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(1:13,reshape(kurt_final(1,1,:),1,13),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
plot(1:13,reshape(kurt_final(1,2,:),1,13),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
plot(1:13,reshape(kurt_final(1,3,:),1,13),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel('Kurtosis of $\Delta_a y^i_t$');
xlim([1 13]); set(gca,'XTick',1:2:13);
set(gca,'XTickLabel',{'1','11-20','31-40','51-60','71-80','91-95','100'});
name='L1_Kurt_Estimation';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[reshape(kurt_final(1,1,:),13,1) reshape(kurt_final(1,2,:),13,1) reshape(kurt_final(1,3,:),13,1)];
	tbl0 = table({'Kurtosis of annual changes'});
	tbl1 = table({'RE Pctile','25-34', '35-44', '45-54'});
	tbl2 = table({'P1';'P2-P10';'P11-P20';'P21-P30';'P31-P40';'P41-P50';'P51-P60';'P61-P70';'P71-P80';'P81-P90';'P91-P95';'P96-P99';'P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B4','WriteVariableNames',false);
end


h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(1:13,reshape(kurt_final(2,1,:),1,13),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:),'MarkerSize',ms); hold on; grid on;
plot(1:13,reshape(kurt_final(2,2,:),1,13),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:),'MarkerSize',ms);
plot(1:13,reshape(kurt_final(2,3,:),1,13),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:),'MarkerSize',ms);
leg=legend('25-34', '35-44', '45-54', 'location', 'best');
set(leg,'FontSize',lfsize);
xlabel('Percentiles of Recent Earnings Distribution');
ylabel('Kurtosis of $\Delta_a y^i_t$');
xlim([1 13]); set(gca,'XTick',1:2:13);
set(gca,'XTickLabel',{'1','11-20','31-40','51-60','71-80','91-95','100'});
name='L5_Kurt_Estimation';
saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

if write_excel==1
	data=[reshape(kurt_final(2,1,:),13,1) reshape(kurt_final(2,2,:),13,1) reshape(kurt_final(2,3,:),13,1)];
	tbl0 = table({'Kurtosis of five-year changes'});
	tbl1 = table({'RE Pctile','25-34', '35-44', '45-54'});
	tbl2 = table({'P1';'P2-P10';'P11-P20';'P21-P30';'P31-P40';'P41-P50';'P51-P60';'P61-P70';'P71-P80';'P81-P90';'P91-P95';'P96-P99';'P100'});
	tbl3 = table(data);
	writetable(tbl0,filename,'Sheet',name,'Range','B2','WriteVariableNames',false);
	writetable(tbl1,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A4','WriteVariableNames',false);
	writetable(tbl3,filename,'Sheet',name,'Range','B4','WriteVariableNames',false);
end

%% Distribution of Shocks for Prime Age Males (various percentiles of the shock distribution)
% name='SdSkewKurt_L1.dat';
% dlmwrite(name,[reshape(reshape(sd_final(1,:,:),3,length(lbRE))',3*length(lbRE),1) ...
% 			   reshape(reshape(skew_final(1,:,:),3,length(lbRE))',3*length(lbRE),1) ...
% 			   reshape(reshape(kurt_final(1,:,:),3,length(lbRE))',3*length(lbRE),1)], ...
% 			   'delimiter','\t');
% 
% name='SdSkewKurt_L5.dat';
% dlmwrite(name,[reshape(reshape(sd_final(2,:,:),3,length(lbRE))',3*length(lbRE),1) ...
% 			   reshape(reshape(skew_final(2,:,:),3,length(lbRE))',3*length(lbRE),1) ...
% 			   reshape(reshape(kurt_final(2,:,:),3,length(lbRE))',3*length(lbRE),1)], ...
% 			   'delimiter','\t');