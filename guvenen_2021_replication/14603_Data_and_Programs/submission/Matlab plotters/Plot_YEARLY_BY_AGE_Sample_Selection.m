clear; clc; close all; 
user=3;						% user=1-serdar; user=2-karahan (ny); user=3-karahan (mac)
write_excel=1;          % =1 update excel file

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
mrg=0.04; mrg_btm=0.13; mrg_lft=0.10;

folder=char('5_May_2017_CrossSection_SampleSelection');
if(user==1) % serdar
    userdirectory=char('C:\Research\SSA-INCOME-RISK\EmpiricalResults\Revision\CrossSectional\');
	sep=char('\');
elseif(user==2) % f. karahan ny
    userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Replication\CrossSectional\');
	sep=char('\');
	addpath('C:\Users\rceyfk01\Dropbox\subaxis\');
	addpath('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\Matlab');
	addpath('C:\Users\rceyfk01\Dropbox\export_fig');
elseif(user==3) % f. karahan mac
    userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/CrossSectional/');
	sep=char('/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Matlab');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
end
input  = [userdirectory 'Input' sep folder sep];
output = [userdirectory 'Output' sep 'Age'];
cd(output);
filename='cross_moments_BYAGE.xlsx';
filename=[userdirectory 'Output' sep filename];

K=importdata('selection_modified_byage_year.txt'); data=K.data; %#ok<*SAGROW>

% Store data
year=1996:2011;
for t=1:length(year)
	frac_dropped(t,:) = 100*data(6*(t-1)+1:6*t,3)';
end
cd(output)

%% Step 1 of sample selection average across years
h=figure;
subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
plot(1:6,mean(frac_dropped,1),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:)); grid on;
set(gca,'XTick',1:6); set(gca,'XTickLabel',{'30-34', '35-39', '40-44', '45-49', '50-54', '55-60'})
set(gca,'YTick',24:29);
xlabel('Age Group'); ylabel('Fraction dropped, \%');
name='Step1_mean_age'; saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');

if write_excel==1
	data=[(1:6)' mean(frac_dropped,1)'];
	tbl1 = table({'Age Group','Fraction dropped, \%'});
	tbl2 = table(data);
	writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
	writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
end