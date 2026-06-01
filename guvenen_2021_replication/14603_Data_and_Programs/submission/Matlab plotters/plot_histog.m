function plot_histog(year,overall_pop)
%year= % 1997 2005 2009 2012
%overall_pop % 1 all sample, o/w conditional on income and age
close all; clc;
stdnorm=normrnd(0,1,100000,1);
user=4;
write_excel=1;			% =1 update excel file
filename='histogram_moments.xlsx';

% Plot options
mrg=0.03; mrg_btm=0.135; mrg_lft=0.115;
ftsize=20;
set(0,'defaultTextFontName','Times New Roman'); set(0,'defaultAxesFontName','Times New Roman');
set(0,'defaultTextInterpreter','latex'); ms=13; set(0,'defaultLineMarkerSize',ms);
set(0,'defaultlinelinewidth',4); set(0,'defaultTextFontSize',ftsize);
set(0,'defaultAxesFontSize',ftsize); lfsize=21;

if(user==1) % serdar
	userdirectory=char('/Users/serdar/Dropbox/SSA-INCOME-RISK/');
    addpath('/Users/serdar/Documents/MATLAB/subaxis');
    addpath('/Users/serdar/Dropbox/Home_School/computation/MATLAB/export_fig');
    addpath('/Users/serdar/Dropbox/Home_School/computation/MATLAB/line_fewer_markers_v4');    
	sep=char('/');
elseif(user==2) % f. guvenen
	userdirectory=char('/Users/fatihguvenen/Dropbox/RESEARCH/PROJECTS/JAE-SONG/SSA-INCOME-RISK/');
	sep=char('/');
elseif(user==3) % f. karahan
	userdirectory=char('C:\Users\rceyfk01\Dropbox\SSA-INCOME-RISK\');
	addpath('C:\Users\rceyfk01\Dropbox\Matlab\subaxis');
	addpath('C:\Users\rceyfk01\Dropbox\Matlab\export_fig');
	sep=char('\');
elseif(user==4) % f. karahan mac
	userdirectory=char('/Users/fatihkarahan/Dropbox/SSA-INCOME-RISK/Replication/Final/Histogram/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/subaxis/');
	addpath('/Users/fatihkarahan/Dropbox/Matlab/export_fig');
	sep=char('/');
end
folder=char('7_Jan_2016_Labor_Chg_Hist');
code   = [userdirectory 'Code' sep];
input  = [userdirectory 'Input' sep folder sep];
output = [userdirectory 'Output' sep];
filename=[userdirectory filename];

if (overall_pop==1)
	file=['hist_labor_all' num2str(year) '.txt'];
	K=importdata([input file]);
	results=K.data;
	cd(output);
	for ch=1:1
		if(ch==1)
			chg=char('Log_');
		else
			chg=char('Arc_');
		end
		for lag=1:2
			x=(ch-1)*4 + (lag-1)*2+2;
			y=(ch-1)*4 + (lag-1)*2+1;
			[mean,sd,skew,kurt,median]=sum_stat2(results(:,x), results(:,y));
			h=figure;
			subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
			hold on; grid on;
			plot(results(:,x)-median,results(:,y),'b-')
			if(ch==1)
				normalpdf=pdf('Normal',results(:,x),mean,sd);
				plot(results(:,x),normalpdf,'r--')
% 				axis([-3*sd,3*sd,0,max(results(:,(lag-1)*2+1))+0.5])
				axis([-2.5,2.5,0,max(results(:,(lag-1)*2+1))+0.5])
			else
				sdn=fsolve(@(x) std(2*(exp(x*stdnorm)-1)./(exp(x*stdnorm)+1))-sd,sd);
				[fn,xn]=ksdensity(2*(exp(sdn*stdnorm+mean)-1)./(exp(sdn*stdnorm+mean)+1));
				plot(xn, fn,'r--')
				axis([-2,2,0,max(results(:,(lag-1)*2+1))+0.5])
				skew_g=skewness(2*(exp(sdn*stdnorm+mean)-1)./(exp(sdn*stdnorm+mean)+1));
				kurt_g=kurtosis(2*(exp(sdn*stdnorm+mean)-1)./(exp(sdn*stdnorm+mean)+1));            
			end
% 			leg=legend(['All Sample, Year: ' num2str(year)],'Normal Dist.');
			leg=legend('US Data',['$$\mathcal{N} (0,' num2str(sd,'% 5.2f') ')$$']);
			set(leg,'FontSize',lfsize,'FontName','Times New Roman','Interpreter','latex');
			if(ch==1)
				if(lag==1)
					xlabel('One-year change, $y_{t+1}-y_{t}$','FontSize',25)
					ylim([0 3.5])
				else
					xlabel('Five-year change, $y_{t+5}-y_{t}$','FontSize',25)
					ylim([0 1.4])
				end
				else
				if(lag==1)
					xlabel('$2(Y_{t+1}-Y_{t})/(Y_{t+1}+Y_{t})$','FontSize',25)
				else
					xlabel('$2(Y_{t+5}-Y_{t})/(Y_{t+5}+Y_{t})$','FontSize',25)
				end
			end
			ylabel('Density')
			if(ch==1)
				annotation('textbox', [0.15,0.55 0.05 0.10],'String', ...
					{['St. Dev.    =  ' num2str(sd,'% 5.2f')];['Skewness = ' num2str(skew,'% 5.2f')]; ...
					['Kurtosis   =  ' num2str(kurt,'% 5.2f')]},'FontName','Times New Roman','FontSize',lfsize, ...
					'BackgroundColor','w','FitBoxToText','on','linewidth',0.5);
			else
				annotation('textbox', [0.15,0.60 0.05 0.10],'String', ...
					{['St. Dev.    =  ' num2str(sd,'% 5.2f')];['Skewness = ' num2str(skew,'% 5.2f')]; ...
					['Kurtosis   =  ' num2str(kurt,'% 5.2f')];['Skewness of Normal = ' num2str(skew_g,'% 5.2f')]; ...
					['Kurtosis of Normal = ' num2str(kurt_g,'% 5.2f')]},'FontName','Times New Roman','FontSize',lfsize, ...
					'BackgroundColor','w','FitBoxToText','on','linewidth',0.5);
			end
			name=[chg 'Hist_L' num2str((lag-1)*4+1) 'Yr' num2str(year) '_All'];
			saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

            if write_excel==1
				data=[results(:,x)-median results(:,y)];    %,results(:,x),normalpdf
				tbl1 = table({'Log earnings change','Density'});
				tbl2 = table(data);
				writetable(tbl1,filename,'Sheet',name,'Range','A2','WriteVariableNames',false);
				writetable(tbl2,filename,'Sheet',name,'Range','A3','WriteVariableNames',false);
            end

			if(ch==1 && lag==1)	% (lag==1 || lag==2)
				h=figure;
				subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
				hold on; grid on;
				plot(results(:,x),log(results(:,y)),'b-')
% 				lnnormalpdf=log(pdf('Normal',results(:,x),mean,sd));
% 				plot(results(:,x),lnnormalpdf,'r-');
				if lag==1
					lnnormalpdf=log(pdf('Normal',-2.1:0.001:2.1,mean,sd));
					plot(-2.1:0.001:2.1,lnnormalpdf,'r-.');
				else
					lnnormalpdf=log(pdf('Normal',-3.7:0.001:3.7,mean,sd));
					plot(-3.7:0.001:3.7,lnnormalpdf,'r-.');
				end

				% Fit line to the tails
				indLmax=find(results(:,x)<=-1); indRmin=find(results(:,x)>=1);
				indL(2)=indLmax(end); indR(1)=indRmin(1);
				indLmin=find(results(:,x)>=-4); indRmax=find(results(:,x)<=4);
				indL(1)=indLmin(1); indR(2)=indRmax(end);
				disp([indL indR length(results(:,x))]);
				% Plot the left tail
				PL = polyfit(results(indL(1):indL(2),x),log(results(indL(1):indL(2),y)),1); disp(PL)
				yfitL = PL(1)*results(indL(1):indL(2),x)+PL(2);
				plot(results(indL(1):indL(2),x),yfitL,'k-.','linewidth',3.5);
				% Plot the right tail
				PR = polyfit(results(indR(1):indR(2),x),log(results(indR(1):indR(2),y)),1); disp(PL)
				yfitR = PR(1)*results(indR(1):indR(2),x)+PR(2);
				plot(results(indR(1):indR(2),x),yfitR,'k-.','linewidth',3.5);			

				textL=[' Slope = ' sprintf('%1.2f', PL(1))];
				textR=[' Slope = ' sprintf('%1.2f', PR(1))];
				xbox = [0.2286 0.3089]; ybox = [0.719 0.5286];
				annotation('textarrow',xbox,ybox,'String',textL,'linewidth',0.5,'fontsize',20);
				xbox = [0.8107 0.7536]; ybox = [0.7143 0.5167];
				annotation('textarrow',xbox,ybox,'String',textR,'linewidth',0.5,'fontsize',20);

% 				figtextL=[' Left tail coefs (c0 & c1): ' num2str(PL(2)) ' ' num2str(PL(1))];
% 				figtextR=[' Right tail coefs (c0 & c1): ' num2str(PR(2)) ' ' num2str(PR(1))];
% 				xbox = [0.14 0.19 0.1 0.1];
% 				annotation('textbox','position',xbox,'String',figtextL,...
% 					'fontsize',13,'linestyle','none');
% 				xbox = [0.14 0.14 0.1 0.1];
% 				annotation('textbox','position',xbox,'String',figtextR,...
% 					'fontsize',13,'linestyle','none');

				axis([-4 4 -10 2]);
				if lag==1
					xlabel('$y_{t+1}-y_{t}$','FontSize',25);
				else
					xlabel('$y_{t+5}-y_{t}$','FontSize',25);
				end
				ylabel('Log Density');
				if lag==1
					leg=legend('US Data','$$\mathcal{N} (0,0.51)$$');
				else
					leg=legend('US Data','$$\mathcal{N} (0,0.78)$$');
				end
				set(leg,'FontSize',lfsize,'FontName','Times New Roman','location','NorthWest','Interpreter','latex');
				name=[chg 'LN_Hist_L' num2str((lag-1)*4+1) 'Yr' num2str(year) '_All_pareto'];
				saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent');

				display(['Concentration measures,  ' num2str(year) ', L' num2str((lag-1)*4+1)])
				display('             Data    Normal Distn') %#ok<*DISPLAYPROG>
				center_data=data_cdf1(results(:,x),results(:,y),0.194)-data_cdf1(results(:,x),results(:,y),-0.144);
				center_norm=normcdf(0.194,0,sd)-normcdf(-0.144,0,sd);
				shoulder_data=data_cdf1(results(:,x),results(:,y),-0.144)-data_cdf1(results(:,x),results(:,y),-1.278)+...
					data_cdf(results(:,x),results(:,y),1.121)-data_cdf(results(:,x),results(:,y),0.194);
				shoulder_norm=normcdf(-0.144,0,sd)-normcdf(-1.278,0,sd)+...
					normcdf(1.121,0,sd)-normcdf(0.194,0,sd);
				tail_data=data_cdf1(results(:,x),results(:,y),-1.278)+...
					1-data_cdf1(results(:,x),results(:,y),1.121);
				tail_norm=normcdf(-1.278,0,sd)+1-normcdf(1.121,0,sd);
				display(['Center   = ' num2str(center_data,'% 5.3f') '    ' num2str(center_norm,'% 5.3f')...
					'  ' num2str(center_data/center_norm,'% 5.3f')])
				display(['Shoulder = ' num2str(shoulder_data,'% 5.3f') '    ' num2str(shoulder_norm,'% 5.3f')...
					'  ' num2str(shoulder_data/shoulder_norm,'% 5.3f')])
				display(['Tails    = ' num2str(tail_data,'% 5.3f') '    ' num2str(tail_norm,'% 5.3f')...
					'  ' num2str(tail_data/tail_norm,'% 5.3f')])
			end

			display(['Overall Population,  ' num2str(year) ', L' num2str((lag-1)*4+1)])
			display('             Data    Normal Distn') %#ok<*DISPLAYPROG>
			display(['|x|<0.05 = ' num2str(data_cdf(results(:,x), results(:,y),0.05),'% 5.3f') '    ' num2str(normcdf(0.05,0,sd)-normcdf(-0.05,0,sd),'% 5.3f')])
			display(['|x|<0.10 = ' num2str(data_cdf(results(:,x), results(:,y),0.1),'% 5.3f') '    ' num2str(normcdf(0.1,0,sd)-normcdf(-0.1,0,sd),'% 5.3f')])
			display(['|x|<0.20 = ' num2str(data_cdf(results(:,x), results(:,y),0.2),'% 5.3f') '    ' num2str(normcdf(0.2,0,sd)-normcdf(-0.2,0,sd),'% 5.3f')])
			display(['|x|<0.50 = ' num2str(data_cdf(results(:,x), results(:,y),0.5),'% 5.3f') '    ' num2str(normcdf(0.5,0,sd)-normcdf(-0.5,0,sd),'% 5.3f')])
			display(['|x|<1.00 = ' num2str(data_cdf(results(:,x), results(:,y),1),'% 5.3f') '     ' num2str(normcdf(1,0,sd)-normcdf(-1,0,sd),'% 5.3f')])
			display(['|x|<1.50 = ' num2str(data_cdf(results(:,x), results(:,y),1.5),'% 5.3f') '    ' num2str(normcdf(1.5,0,sd)-normcdf(-1.5,0,sd),'% 5.3f')])
			display([' x > 0.25 = ' num2str(1-data_cdf1(results(:,x),results(:,y),0.25),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
			display([' x <-0.25 = ' num2str(data_cdf1(results(:,x), results(:,y),-0.25),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])
			display([' x > 0.5 = ' num2str(1-data_cdf1(results(:,x),results(:,y),0.5),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
			display([' x <-0.5 = ' num2str(data_cdf1(results(:,x), results(:,y),-0.5),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])
			display([' x > 1.0 = ' num2str(1-data_cdf1(results(:,x),results(:,y),1.0),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
			display([' x <-1.0 = ' num2str(data_cdf1(results(:,x), results(:,y),-1.0),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])
			display([' x > 1.5 = ' num2str(1-data_cdf1(results(:,x),results(:,y),1.5),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
			display([' x <-1.5 = ' num2str(data_cdf1(results(:,x), results(:,y),-1.5),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])
% 			pause
		end
% 		stop
	end
else
	file=['hist_labor_incrankage' num2str(year) '.txt'];
% 	disp(input)
	K=importdata([input file]);
	results=K.data;
	cd(output);
	for age=1:2
		for pct=1:3
			close all; clc;
			for ch=1:2
				for lag=1:2
					if(ch==1)
						chg=char('Log_');
					else
						chg=char('Arc_');
					end
					x=(age-1)*24+(pct-1)*8+(ch-1)*4 +(lag-1)*2+2;
					y=(age-1)*24+(pct-1)*8+(ch-1)*4 +(lag-1)*2+1;
					[mean,sd,skew,kurt]=sum_stat(results(:,x), results(:,y));
					h=figure;
					subaxis(1,1,1, 'Margin', mrg,'MarginBottom',mrg_btm,'MarginLeft',mrg_lft);
					hold on; grid on;
					plot(results(:,x),results(:,y),'b-')
					if(ch==1)
						normalpdf=pdf('Normal',results(:,x),mean,sd);
						plot(results(:,x),normalpdf,'r--')
						axis([-3,3,0,max(results(:,y))+0.5])
					else
						sdn=fsolve(@(x) std(2*(exp(x*stdnorm)-1)./(exp(x*stdnorm)+1))-sd,sd);
						[fn,xn]=ksdensity(2*(exp(sdn*stdnorm+mean)-1)./(exp(sdn*stdnorm+mean)+1));
						plot(xn,fn,'r--')
						axis([-2,2,0,max(results(:,y))+0.5])
						skew_g=skewness(2*(exp(sdn*stdnorm+mean)-1)./(exp(sdn*stdnorm+mean)+1));
						kurt_g=kurtosis(2*(exp(sdn*stdnorm+mean)-1)./(exp(sdn*stdnorm+mean)+1));
					end
					if(age==1)
						agech=char('25-34');
					else
						agech=char('45-50');
					end
					leg=legend([agech ', ' num2str((pct-1)*40+10) 'th pctile, Year: ' num2str(year)]...
						,'Normal Dist.');
					set(leg,'FontName','Times New Roman','FontSize',lfsize);
					if(ch==1)
						if(lag==1)
							xlabel('$y_{t+1}-y_{t}$')
						else
							xlabel('$y_{t+5}-y_{t}$')
						end
					else
						if(lag==1)
							xlabel('$2(Y_{t+1}-Y_{t})/(Y_{t+1}+Y_{t})$')
						else
							xlabel('$2(Y_{t+5}-Y_{t})/(Y_{t+5}+Y_{t})$')
						end
					end
					ylabel('Density')
					if(ch==1) 
						annotation('textbox', [0.15,0.30 0.05 0.10],'String', ...
							{['St. Dev. = ' num2str(sd,'% 5.2f')];['Skewness = ' num2str(skew,'% 5.2f')]; ...
							['Kurtosis = ' num2str(kurt,'% 5.2f')]},'FontName','Times New Roman','FontSize',14, ...
							'BackgroundColor','w','FitBoxToText','on','linewidth',0.5);
					else
						annotation('textbox', [0.15,0.60 0.05 0.10],'String', ...
							{['St. Dev. = ' num2str(sd,'% 5.2f')];['Skewness = ' num2str(skew,'% 5.2f')]; ...
							['Kurtosis = ' num2str(kurt,'% 5.2f')];['Skewness of Normal = ' num2str(skew_g,'% 5.2f')]; ...
							['Kurtosis of Normal = ' num2str(kurt_g,'% 5.2f')]},'FontName','Times New Roman','FontSize',14, ...
							'BackgroundColor','w','FitBoxToText','on','linewidth',0.5);
					end
					name=[chg 'Hist_L' num2str((lag-1)*4+1) 'Age' num2str(age) 'Pct' num2str((pct-1)*40+10) 'Yr' num2str(year)];
					saveas(h,name,'fig'); export_fig([name '.eps'],'-nocrop','-transparent')

					display(['Age:' agech ', ' num2str((pct-1)*40+10) 'th Percentile, ' num2str(year) ', L' num2str((lag-1)*4+1)])
					display('             Data    Normal Distn')
					display(['|x|<0.05 = ' num2str(data_cdf(results(:,x), results(:,y),0.05),'% 5.3f') '    ' num2str(normcdf(0.05,0,sd)-normcdf(-0.05,0,sd),'% 5.3f')])       
					display(['|x|<0.10 = ' num2str(data_cdf(results(:,x), results(:,y),0.1),'% 5.3f') '    ' num2str(normcdf(0.1,0,sd)-normcdf(-0.1,0,sd),'% 5.3f')])
					display(['|x|<0.20 = ' num2str(data_cdf(results(:,x), results(:,y),0.2),'% 5.3f') '    ' num2str(normcdf(0.2,0,sd)-normcdf(-0.2,0,sd),'% 5.3f')]) 
					display(['|x|<0.50 = ' num2str(data_cdf(results(:,x), results(:,y),0.5),'% 5.3f') '    ' num2str(normcdf(0.5,0,sd)-normcdf(-0.5,0,sd),'% 5.3f')]) 
					display(['|x|<1.00 = ' num2str(data_cdf(results(:,x), results(:,y),1),'% 5.3f') '    ' num2str(normcdf(1,0,sd)-normcdf(-1,0,sd),'% 5.3f')]) 
					display(['|x|<1.50 = ' num2str(data_cdf(results(:,x), results(:,y),1.5),'% 5.3f') '    ' num2str(normcdf(1.5,0,sd)-normcdf(-1.5,0,sd),'% 5.3f')])               
					display([' x > 0.25 = ' num2str(1-data_cdf1(results(:,x),results(:,y),0.25),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
					display([' x <-0.25 = ' num2str(data_cdf1(results(:,x), results(:,y),-0.25),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])         
					display([' x > 0.5 = ' num2str(1-data_cdf1(results(:,x),results(:,y),0.5),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
					display([' x <-0.5 = ' num2str(data_cdf1(results(:,x), results(:,y),-0.5),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])         
					display([' x > 1.0 = ' num2str(1-data_cdf1(results(:,x),results(:,y),1.0),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
					display([' x <-1.0 = ' num2str(data_cdf1(results(:,x), results(:,y),-1.0),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])
					display([' x > 1.5 = ' num2str(1-data_cdf1(results(:,x),results(:,y),1.5),'% 5.3f') '    ' num2str(1-normcdf(1.0,0,sd),'% 5.3f')])
					display([' x <-1.5 = ' num2str(data_cdf1(results(:,x), results(:,y),-1.5),'% 5.3f') '    ' num2str(normcdf(-1.0,0,sd),'% 5.3f')])       
				end
			end
		end
	end
end
cd(code);

	function [mean,sd,skew,kurt,median]=sum_stat2(x,fx)
		[m,n]=size(x);
		dx=ones(m,n)*(x(2)-x(1));
		fx=fx/dot(dx,fx);
		mean=dot(x.*fx,dx);
		sd=sqrt(dot(((x-mean).^2).*fx,dx));
		skew=dot(((x-mean).^3).*fx,dx)/sd^3;
		kurt=dot(((x-mean).^4).*fx,dx)/sd^4;
% 		disp(size(fx)); disp(size(dx))
		dx=(x(2)-x(1)); fx=fx/(dx*sum(fx));
		cdf=cumsum(dx*fx);
		I = find(cdf<=0.5);
		median=x(I(end)+1); %disp([x(I(end)) x(I(end)+1)]); stop
	end
	function [mean,sd,skew,kurt]=sum_stat(x,fx)
		[m,n]=size(x);
		dx=ones(m,n)*(x(2)-x(1));
		fx=fx/dot(dx,fx);
		mean=dot(x.*fx,dx);
		sd=sqrt(dot(((x-mean).^2).*fx,dx));
		skew=dot(((x-mean).^3).*fx,dx)/sd^3;
		kurt=dot(((x-mean).^4).*fx,dx)/sd^4; 
	end
	function data_prob=data_cdf(x,fx,ch)
		[~,~]=size(x);
		dx=(x(2)-x(1));
		fx=fx/(dx*sum(fx));

		I = find(x<ch);
		[m,~]=size(I);
		j=I(m);
		data_prob_u=dx*sum(fx(1:j))+(fx(j)+(ch-x(j))*(fx(j+1)-fx(j))/dx)*(ch-x(j));

		I = find(x<-ch);
		[m,~]=size(I);
		j=I(m);
		data_prob_l=dx*sum(fx(1:j))+(fx(j)+(-ch-x(j))*(fx(j+1)-fx(j))/dx)*(-ch-x(j));
		data_prob=data_prob_u-data_prob_l;
	end
	function data_prob=data_cdf1(x,fx,ch)
		[~,~]=size(x);
		dx=(x(2)-x(1));
		fx=fx/(dx*sum(fx));

		I = find(x<ch);
		[m,~]=size(I);
		j=I(m);
		data_prob=dx*sum(fx(1:j))+(fx(j)+(ch-x(j))*(fx(j+1)-fx(j))/dx)*(ch-x(j));
	end
	function [CDFx,CDFy]=CDF_tails(x,fx) %#ok<DEFNU>
		dx=(x(2)-x(1));
		fx=fx/(dx*sum(fx));

		I = find(x<0);
		[m,~]=size(I);
		j=I(m);
		for k=1:j
			CDF(k)=dx*sum(fx(1:k)); %#ok<AGROW>
		end
		[mm,~]=size(x);
		for k=j+1:mm
			CDF(k)=1-dx*sum(fx(1:k));
		end
		CDFx=log(x(j+1:mm));
		CDFy=log(CDF(j+1:mm));
	end
end

