clear; clc; close all; 
user=3;					% user=1-serdar; user=2-karahan NY; user=3-karahan Mac
write_excel=1;			% =1 update excel file

% Defaults for plots
position=[0.15,0.15,0.50,0.58]; %position=[0.06,0.06,0.62,0.80];
ftsize=26;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); ms=17; set(0,'defaultLineMarkerSize',ms);
set(0,'defaultlinelinewidth',4); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',ftsize); lfsize=26;
mfcolor = [1 0.6 0.78; 0 1 1; 0.00 1.00 0.00; 0.8 0.8 0.8; 1.00 0.50 0.25; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
mecolor = [1 0.0 0.00; 0 0 1; 0.11 0.53 0.10; 0.0 0.0 0.0; 0.63 0.57 0.39; 0.6 0.2 0; 0.96 0.62 0.75; 0.94 0.84 0.25; 1 0 1];
colors  = mecolor;
colors(7,:) = [0.5 0.5 0.5];
colors(8,:) = [0.52 0.16 0.86];
style  = ['o-';'s-';'v-';'d-';'<-';'+-';'x-';'p-';'--';'*-';'>-';'-.'];
% Subaxis options
mrg=0.03; mrg_btm=0.13; mrg_lft=0.12;

userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/Histogram/');
sep=char('/');
addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
addpath('/Users/fatihkarahan/Dropbox/Matlab/line_fewer_markers');

folder=char('25_Sep_2019_EmpShr_byAge');
code   = [userdirectory 'Code' sep];
input  = [userdirectory 'Input' sep folder sep];
output = [userdirectory 'Output' sep];
cd(input);

filename='histogram_moments.xlsx';
filename=[userdirectory filename];

var={'labor';'totinc'};
mat=zeros(2,2,2,1500,4);
m=zeros(2,2,2); n=zeros(2,2,2);
for i=1:2
    for j=1:2
        for k=1:2
            K=importdata(['Emp_byAge_' var{i} '_ret_' num2str(55+(j-1)*5) '_mininc' num2str(k) '.txt']);
            temp=K.data;
            [m(i,j,k),n(i,j,k)]=size(temp);
            mat(i,j,k,1:m(i,j,k),1:n(i,j,k))=temp;
        end
    end
end
cd(output);
%% Employment CDF
% close all
% for i=1:2
%     for j=1:2
%         for k=1:2
%             if(j==1)
%                 Hmax=32;
%             else
%                 Hmax=37;
%             end
%             clear xx yy
%             name=['EmpCDF_' var{i} '_ret_' num2str(55+(j-1)*5) '_mininc' num2str(k)];
%             h=figure;
%             subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
%             hold on; grid on;
%             xx(:)=mat(i,j,k,1:Hmax,2);
%             yy(:)=cumsum(mat(i,j,k,1:Hmax,3))/sum(mat(i,j,k,1:Hmax,3));            
%             plot(xx,yy,...
%                 style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:), ...
%             'MarkerEdgeColor',mecolor(1,:))        
%             xlabel('Total Years Employed');
%             ylabel('Employment CDF');
%             axis tight
%             export_fig([name '.pdf'],'-nocrop','-transparent'); saveas(h,name,'fig'); 
%         end
%     end
% end
%% Average Employment by Decade by Total Employment
close all; clc; 
for i=1:1		% run only for labor income. to have total income, have the loop 1:2
	for j=2:2	% we show age 60 in the paper. for 55, go with j=1.
		for k=1:1	% k=1 for mininc1 (reported in the paper)
			if(j==1)
				Hmax=32;
				legs={'25-35','36-45','46-55'}; 
			else
				Hmax=37;
				legs={'25-35','36-45','46-60'}; 
			end
			clear xx temp_avg
			for h=1:Hmax-1
				temp_avg(h,:)=mat(i,j,k,(h-1)*Hmax+1:h*Hmax,4); %#ok<*SAGROW>
			end
			name=['AvgEmpbyDecade_' var{i} '_ret_' num2str(55+(j-1)*5) '_mininc' num2str(k)];
			h=figure;
			subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
			xx(:)=mat(i,j,k,1:Hmax,2);
			plot(xx,mean(temp_avg(1:11,:),1),style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:))        
			plot(xx,mean(temp_avg(12:21,:),1),style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:))        
			plot(xx,mean(temp_avg(22:Hmax-1,:),1),style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:))       
			xlabel('Total Years Employed'); ylabel('Average Employment'); xlim([0 36])
			leg=legend(legs,'Location','Best'); set(leg,'FontSize',lfsize);
			set(gcf,'units','normalized','position',position);
            export_fig([name '.pdf'],'-nocrop','-transparent'); saveas(h,name,'fig');

			if write_excel==1
				data=[xx' mean(temp_avg(1:11,:),1)' mean(temp_avg(12:21,:),1)' mean(temp_avg(22:Hmax-1,:),1)'];
				tbl1 = table({'Total Years Employed','25-35','36-45','46-60'}); %
				tbl2 = table(data);
				sheetname=['AvgEmpbyDec_' var{i} '_ret_' num2str(55+(j-1)*5) '_' num2str(k)];
				writetable(tbl1,filename,'Sheet',sheetname,'Range','A2','WriteVariableNames',false);
				writetable(tbl2,filename,'Sheet',sheetname,'Range','A3','WriteVariableNames',false);
			end
		end
	end
end

%% Fraction of Unemployed by Age by Total Employment
close all; clc; 
for i=1:1
	for j=2:2
		for k=1:1
			if(j==1)
				Hmax=32;
				age=25:1:55;
			else
				Hmax=37;
				age=25:1:60;
			end
			clear xx temp_avg temp_num temp_frac1 temp_frac2 temp_frac3
			temp_num(:)=mat(i,j,k,1:Hmax,3);
			for h=1:Hmax-1
				temp_avg(h,:)=mat(i,j,k,(h-1)*Hmax+1:h*Hmax,4);
				temp_tot=sum((1-temp_avg(h,:)).*temp_num);
				temp_frac1(h)=sum((1-temp_avg(h,Hmax-9:Hmax)).*temp_num(Hmax-9:Hmax))/temp_tot;
				temp_frac2(h)=sum((1-temp_avg(h,Hmax-14:Hmax)).*temp_num(Hmax-14:Hmax))/temp_tot;                
				temp_frac3(h)=sum((1-temp_avg(h,Hmax-19:Hmax)).*temp_num(Hmax-19:Hmax))/temp_tot;
			end
			name=['FracUnemp_' var{i} '_ret_' num2str(55+(j-1)*5) '_mininc' num2str(k)];
			h=figure;
			subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft); hold on; grid on;
			xx(:)=mat(i,j,k,1:Hmax,2);
			plot(age,temp_frac1,style(1,:),'Color',colors(1,:),'MarkerFaceColor',mfcolor(1,:),'MarkerEdgeColor',mecolor(1,:))        
            plot(age,temp_frac2,style(2,:),'Color',colors(2,:),'MarkerFaceColor',mfcolor(2,:),'MarkerEdgeColor',mecolor(2,:))        
            plot(age,temp_frac3,style(3,:),'Color',colors(3,:),'MarkerFaceColor',mfcolor(3,:),'MarkerEdgeColor',mecolor(3,:))       
            xlabel('Age'); ylabel('Fraction of Unemployed');
			leg=legend('Unemp<10','Unemp<15','Unemp<20','Location','Best'); set(leg,'FontSize',lfsize);
			set(gcf,'units','normalized','position',position);
			export_fig([name '.pdf'],'-nocrop','-transparent'); saveas(h,name,'fig');

			if write_excel==1
				data=[age' temp_frac1' temp_frac2' temp_frac3'];
				tbl1 = table({'Age','Unemp<10','Unemp<15','Unemp<20'}); %
				tbl2 = table(data);
				sheetname=['AvgEmpbyDec_' var{i} '_ret_' num2str(55+(j-1)*5) '_' num2str(k)];
				writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
				writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
			end
		end
	end
end