function [po,sdage,skewage,kurtage,p90_10,p90_50,p50_10,kellysage,...
	hinkleyage,moorsage,crowsage] = read_cross_moments(direc,k,arc,dib)

	if k~=1 && k~=5
		disp('Wrong value of k')
		stop
	end
	if arc~=0 && arc~=1
		disp('Wrong value of arc')
		stop
	end
	if dib~=0 && dib~=1
		disp('Wrong value of dib')
		stop
	end
	if dib==1
		disp('Reading in data for total income (including DI)')
	else
		disp('Reading in data for labor income (excluding DI)')
	end
	cd(direc);
	if k==1
		K=importdata('L1.txt'); data=K.data; %#ok<*SAGROW>
	else
		K=importdata('L5.txt'); data=K.data;
	end

	% Store percentiles
	ind=2+arc*2*15+dib*15+1;
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
	ind=62+arc*2*7+dib*7+3;
	sd=data(:,ind);   ind=ind+1;
	skew=data(:,ind); ind=ind+1;
	kurt=data(:,ind); ind=ind+1;
	for age=1:7
		p1age(age,:)=mean(p1((age-1)*100+1:age*100,:),2)'; %#ok<*AGROW>
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

	sdy=mean(sdage(1:2,:),1); sdo=mean(sdage(3:6,:),1); %#ok<*NASGU>

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
end