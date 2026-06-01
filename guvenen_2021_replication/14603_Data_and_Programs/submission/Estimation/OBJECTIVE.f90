! This module contains all the variables, parameters, functions that define the objective
! which is to be minimized in the estimation.
! The objective function can be a likelihood or sum of least squares.

MODULE OBJECTIVE
  USE UTILITIES, ONLY : DP,lntruncate,truncate
  IMPLICIT NONE

  ! Simulation related
  INTEGER, PARAMETER :: hmax=36							! maximum age
  INTEGER, PARAMETER :: nhip=1							! degree of HIP (1-linear,2-quadratic, etc)
  INTEGER, PARAMETER :: nar=1								! #AR(1) components
  INTEGER, PARAMETER :: nrun=1							! # of runs to average out the moments
  INTEGER, PARAMETER :: nsim=100000						! # people to be simulated in each run
  REAL(DP), DIMENSION(nrun*nsim,nhip+1)   :: rn_hip		! RV for heterogeneous income profiles
  REAL(DP), DIMENSION(nar,nrun*nsim,hmax) :: rn_eta		! RV for innovations to AR(1)
  REAL(DP), DIMENSION(nar,nrun*nsim,hmax) :: rn_p_ar		! RV determines the incidence of AR(1) innovations
  REAL(DP), DIMENSION(nrun*nsim,hmax) :: rn_eps			! Innovations to transitory component
  REAL(DP), DIMENSION(nrun*nsim,hmax) :: rn_p_eps			! Probability to transitory component
  REAL(DP), DIMENSION(nrun*nsim,2) :: rn_z0				! Initial condition random variable

  REAL(DP), DIMENSION(nrun*nsim,hmax) :: rn_unemp			! Innovations to transitory component
  REAL(DP), DIMENSION(nrun*nsim,hmax) :: rn_nu			! Innovations to transitory component

  REAL(DP), DIMENSION(nsim,hmax) :: ysim					! Simulated log income
  !For diagnostic
  REAL(DP), ALLOCATABLE :: ydiag(:,:),rn_impute(:,:),	uniform_imputation(:,:),shock_type(:,:,:)

  REAL(DP), DIMENSION(hmax,nhip+1)    :: agemat	        ! Age Matrix for HIP component

  ! Estimation related
  INTEGER,  PARAMETER  :: nvaseinc=13
  INTEGER,  PARAMETER  :: nvasemnt=3
  INTEGER,  PARAMETER  :: vaseincpct(nvaseinc+1)=(/1,2,11,21,31,41,51,61,71,81,91,96,100,101/)
  INTEGER,  PARAMETER  :: minobs=3		! min. # obs above min. wage to compute avg. past income
  REAL(DP), PARAMETER :: rminwage=1.5_DP	!!!!! DO NOT MAKE RMINWAGE=0 !!!!!!
  REAL(DP), PARAMETER :: lnrminwage=dlog(rminwage)
  INTEGER,  PARAMETER  :: nirinc=8
  INTEGER,  PARAMETER, DIMENSION(nirinc+1) :: iravgincpct=(/1,6,11,31,51,71,91,96,101/)
  INTEGER,  PARAMETER  :: nirchg=10		! For simulation
  INTEGER,  PARAMETER, DIMENSION(nirchg+1) :: irchgpct=(/1,3,6,11,31,51,71,91,96,99,101/) ! For simulation
  INTEGER,  PARAMETER  :: nirchg_data=23	! For data
  INTEGER,  PARAMETER, DIMENSION(4) :: iragebin=(/1,10,11,25/)
  INTEGER,  PARAMETER, DIMENSION(3) :: nagebin=(/2,2,2/)		! # of agebins
  INTEGER,  PARAMETER, DIMENSION(3) :: agebinl=(/1,9,19/)		! Bounds of age groups used for cross sectional moments
  INTEGER,  PARAMETER, DIMENSION(3) :: agebinh=(/8,18,28/)
  INTEGER,  PARAMETER, DIMENSION(2) :: nagebinir=(/8,15/)		! # of agebins
  REAL(DP), DIMENSION(3,nvaseinc,nvasemnt) :: SdSkewKurt_L1,SdSkewKurt_L5,SdSkewKurt_L1_log,SdSkewKurt_L5_log
  REAL(DP), DIMENSION(3,nvaseinc,nvasemnt) :: DSdSkewKurt_L1, DSdSkewKurt_L5
  INTEGER,  PARAMETER :: nlag=5
  REAL(DP), DIMENSION(2,nirinc,nirchg,nlag+1) :: irmoments,irmoments_log
  REAL(DP), DIMENSION(2,nirinc,nirchg_data,nlag+1) :: Dirmoments,Dirmoments_boot
	INTEGER,  PARAMETER, DIMENSION(nirchg_data) ::  & ! For bootstrap simulation
  irchgpct_boot=(/1,3,6,11,16,21,26,31,36,41,46,51,56,61,66,71,76,81,86,91,96,99,101/)
  INTEGER,  PARAMETER :: minemp=15
  INTEGER,  PARAMETER :: LTh=8, nLTincpct=15
  INTEGER,  PARAMETER, DIMENSION(nLTincpct+1) :: LTincpct=(/1,2,6,11,21,31,41,51,61,71,81,91,96,98,100,101/)
  REAL(DP), DIMENSION(nLTincpct,LTh) :: incgrwth, Dincgrwth
  REAL(DP), DIMENSION(hmax) :: var_lny, Dvar_lny				! variance of log (residual) earnings in the data
  REAL(DP), DIMENSION(nvaseinc,hmax)   :: levelmoments		! Moments related to log(income)
  REAL(DP), DIMENSION(nvaseinc,hmax-1) :: changemoments1
  REAL(DP), DIMENSION(nvaseinc,hmax-5) :: changemoments5
  REAL(DP), DIMENSION(3,nvaseinc,13) :: vasemoments1,vasemoments5,vasemoments1_log,vasemoments5_log
  INTEGER,  PARAMETER :: nest=21							! Number of parameters to be estimated
  REAL(DP), DIMENSION(nest)   :: pguess					! Initial guess determined by the user
  REAL(DP), DIMENSION(nest,2) :: param_bound				! Upper and lower bounds of parameters
  REAL(DP), DIMENSION(nest,2) :: param_range				! The region parameters are most like to be within
  INTEGER,  PARAMETER  :: EmpCDF_num=Hmax+1
  REAL(DP), DIMENSION(EmpCDF_num) :: DEmpCDF, EmpCDF
  INTEGER,  PARAMETER  :: nmom1=6*nvaseinc*nvasemnt, 	&
       nmom2=2*nirinc*nirchg*nlag, &
       nmom3=nLTincpct*LTh, &
       nmom4=Hmax, &
       nmom5=EmpCDF_num-1


  INTEGER,  PARAMETER  :: nmoments=nmom1 + nmom2 + nmom3 + nmom4 + nmom5 ! Number of moments to be targeted
  REAL(DP)  :: weights(nmoments)								! cross-weights for different sets of moments
  REAL(DP), PARAMETER :: scale_moments(5)=(/0.05_DP,0.05_DP,0.0403_DP,0.0_DP,0.0_DP/)   ! These are added to the denominator in percentage
  REAL(DP)  :: penalty=1000.0_DP, penalty0=50.0_DP
  INTEGER   :: diagnostic=0, covar_se=0, Bootstrap=0,GenMoms=0
  REAL(DP)  :: penalty_trim			! penalty in case there are too many observations that are too big or too small
  INTEGER   :: penalty_indicator		! indicator for whether the parameter violates some of the conditions (1 means not evaluated)
  INTEGER, ALLOCATABLE :: nu_sim(:,:)
  CHARACTER(len=255) :: main_path
  REAL(DP) :: obj_imp_S=0.0_DP,obj_imp_L=0.0_DP

CONTAINS

  SUBROUTINE OBJ_INIT
    USE UTILITIES, ONLY : write_1
    IMPLICIT NONE
    INTEGER :: l,h,i,j

    WRITE(*,'(A41,I5)') 'Number of parameters to be estimated: ', nest
    WRITE(*,'(A41,I5)') '    Number of moments to be targeted: ', nmoments
    WRITE(*,*) ' '

    !    ===================== set bounds =============================
    param_bound(1,1)= -1.0_DP;		param_bound(1,2)=  5.0_DP		! age profile const.
    param_bound(2,1)= -1.0_DP;		param_bound(2,2)=  2.0_DP		! age profile linear
    param_bound(3,1)= -1.0_DP;		param_bound(3,2)=  0.5_DP		! age profile quadratic
    param_bound(4,1)=  0.0_DP;		param_bound(4,2)=  2.0_DP		! sd(alpha)
    param_bound(5,1)=  0.0_DP;		param_bound(5,2)=  0.5_DP		! sd(beta)
    param_bound(6,1)= -1.0_DP;		param_bound(6,2)=  1.0_DP		! corr(alpha,beta)
    param_bound(7,1)= -1.0_DP;		param_bound(7,2)=  1.0_DP		! mu1
    param_bound(8,1)= -1.0_DP;		param_bound(8,2)=  1.02_DP		! rho1
    param_bound(9,1)= 0.0_DP;		  param_bound(9,2)= 0.49_DP		! const (pr1)
    param_bound(10,1)= 0.0_DP;		param_bound(10,2)= 2.0_DP		! mean of sd eta(AR1_1)
    param_bound(11,1)= 0.0_DP;		param_bound(11,2)= 2.0_DP		! mean of sd eta(AR1_2)
    param_bound(12,1)= 0.0_DP;		param_bound(12,2)= 1.5_DP   	! sd eta(Z1_0)
    param_bound(13,1)= 0.00_DP;		param_bound(13,2)= 4.0_DP		! lambda of exponential
    param_bound(14,1)=-10.0_DP;		param_bound(14,2)= 1.0_DP		! const (nu)
    param_bound(15,1)=-6.0_DP;		param_bound(15,2)= 2.0_DP   	! lin. age (nu)
    param_bound(16,1)=-6.0_DP;		param_bound(16,2)= 2.0_DP		! lin. z (nu)
    param_bound(17,1)=-6.0_DP;		param_bound(17,2)= 2.0_DP		! lin. interaction (nu)
    param_bound(18,1)= 0.02_DP;		param_bound(18,2)= 2.0_DP		! sd(eps1)
    param_bound(19,1)= 0.02_DP;		param_bound(19,2)= 2.0_DP		! sd(eps2)
    param_bound(20,1)= 0.01_DP;		param_bound(20,2)= 0.49_DP		! prob(eps)
    param_bound(21,1)= -2.00_DP;	param_bound(21,2)= 2.00_DP		! mu(eps1)


    !    ===================== set range =============================
    param_range(1,1)=  2.25_DP;		param_range(1,2)=  3.5_DP		! age profile const.
    param_range(2,1)=  0.30_DP;		param_range(2,2)=  1.0_DP		! age profile linear
    param_range(3,1)=-0.30_DP;		param_range(3,2)=  0.0_DP		! age profile quadratic
    param_range(4,1)=  0.2_DP;		param_range(4,2)=  0.6_DP		! sd(alpha)
    param_range(5,1)=  0.0_DP;		param_range(5,2)=  0.35_DP		! sd(beta)
    param_range(6,1)= -0.1_DP;		param_range(6,2)=  0.95_DP		! corr(alpha,beta)
    param_range(7,1)= -0.5_DP;		param_range(7,2)=  0.25_DP		! mu1
    param_range(8,1)=  0.60_DP;		param_range(8,2)=  0.99_DP		! rho1
    param_range(9,1)= 0.10_DP;		param_range(9,2)=  0.35_DP		! constant pr1
    param_range(10,1)= 0.20_DP;		param_range(10,2)= 0.75_DP		! mean of sd eta(AR1_1)
    param_range(11,1)= 0.0_DP;		param_range(11,2)= 0.30_DP		! mean of sd eta(AR1_2)
    param_range(12,1)= 0.20_DP;		param_range(12,2)= 0.8_DP		! sd eta(Z1_0)
    param_range(13,1)= 0.01_DP;		param_range(13,2)= 1.0_DP		! lambda of exponential
    param_range(14,1)=-7.0_DP;		param_range(14,2)=-2.0_DP		! constant nu
    param_range(15,1)=-2.0_DP;		param_range(15,2)= 0.0_DP		! lin. age nu
    param_range(16,1)=-6.0_DP;		param_range(16,2)= 0.0_DP		! linear z nu
    param_range(17,1)=-4.0_DP;		param_range(17,2)= 0.0_DP		! lin. interaction nu
    param_range(18,1)= 0.05_DP;		param_range(18,2)= 0.75_DP		! sd(eps1)
    param_range(19,1)= 0.01_DP;		param_range(19,2)= 0.30_DP		! sd(eps2)
    param_range(20,1)= 0.05_DP;		param_range(20,2)= 0.40_DP		! prob(eps)
    param_range(21,1)= -0.75_DP;	param_range(21,2)= 0.75_DP		! mu(eps1)

    DO h = 1,hmax
       DO j = 1,nhip+1
          agemat(h,j)=DBLE(h)**(j-1)/(10.0_DP**(j-1))
       ENDDO
    ENDDO

    ! Computing weights
    weights=0.0_DP
    weights(1:nmom1) = 2.0_DP/DBLE(7*nmom1)
    l=nmom1
    ! Here, we need to do the interpolation for impulse response moments.
    DO h=1,2
       DO i=1,nirinc
          DO j=1,nirchg
             weights(l+1:l+3)=1.0_DP/DBLE(7*3*nmom2/5)
             weights(l+4:l+5)=1.0_DP/DBLE(7*2*nmom2/5)
             l=l+nlag
          ENDDO
       ENDDO
    ENDDO
    weights(nmom1+nmom2+1:nmom1+nmom2+nmom3) = 1.0_DP/DBLE(7*nmom3)
    weights(nmom1+nmom2+nmom3+1:nmom1+nmom2+nmom3+nmom4) = 1.0_DP/DBLE(7*nmom4)
    weights(1+nmom1+nmom2+nmom3+nmom4:nmoments) =1.0_DP/DBLE(7*nmom5)

    CALL write_1(weights,'weights.out')

    weights=dsqrt(weights)
    IF(diagnostic==1) THEN
       ALLOCATE(ydiag(NSIM,HMAX))
       ALLOCATE(rn_impute(nrun*nsim,hmax))
       ALLOCATE(uniform_imputation(nsim,hmax))
       ALLOCATE(nu_sim(nsim,hmax)); nu_sim=0;
			ALLOCATE(shock_type(nsim,hmax,nar+2)); shock_type=0.0_DP
    ENDIF

  END SUBROUTINE OBJ_INIT

  SUBROUTINE readmoments
    USE UTILITIES, ONLY: myread2,write2
    IMPLICIT NONE
    INTEGER :: i,j,h,numrows,ios
    REAL(DP) :: temp(2*nirinc*nirchg_data,nlag+1),temp1(3*nvaseinc,nvasemnt),temp2(3*nvaseinc,nvasemnt)

    ios=0

    CALL SIM_RN

    CALL myread2(temp1,'SdSkewKurt_L1.dat',numrows)
    CALL myread2(temp2,'SdSkewKurt_L5.dat',numrows)
    DO h=1,3
       DO i=1,nvaseinc
          DSdSkewKurt_L1(h,i,:)=temp1((h-1)*nvaseinc+i,:)
          DSdSkewKurt_L5(h,i,:)=temp2((h-1)*nvaseinc+i,:)
       ENDDO
    ENDDO

    CALL myread2(temp,'ImpulseA_mean.dat',numrows)
    DO h=1,2
       DO i=1,nirinc
          DO j=1,nirchg_data
             Dirmoments(h,i,j,:)=temp((h-1)*nirinc*nirchg_data+(i-1)*nirchg_data+j,:)
          ENDDO
       ENDDO
    ENDDO

    CALL myread2(Dincgrwth,'meanLTinc_level.dat',numrows)

    OPEN(UNIT=44, FILE='var_lny.dat', STATUS='old')
    READ(44,*,IOSTAT=ios) Dvar_lny; CLOSE(44)

    OPEN(UNIT=44, FILE='EmpCDF.dat', STATUS='old')
    READ(44,*,IOSTAT=ios) DEmpCDF; CLOSE(44)
  END SUBROUTINE readmoments

  SUBROUTINE diagnostic_moments(param_input)
    USE UTILITIES, ONLY: write_1, write2, write_3, write4
    IMPLICIT NONE
    REAL(DP), INTENT(IN), DIMENSION(NEST) :: param_input
    REAL(DP) :: obj

    WRITE(*,'(A45)') 'Diagnostic moments are being simulated.'

    obj= OBJ_FUNC(param_input)
    WRITE(*,'(A10,f18.8)') "obj= ", obj

    PRINT*,'Writing moments..'
    CALL write_3(SdSkewKurt_L1,'S_SdSkewKurt_L1.dat')
    CALL write_3(SdSkewKurt_L5,'S_SdSkewKurt_L5.dat')
    CALL write_3(SdSkewKurt_L1_log,'S_SdSkewKurt_L1_log.dat')
    CALL write_3(SdSkewKurt_L5_log,'S_SdSkewKurt_L5_log.dat')
    CALL write4(irmoments,'S_ImpulseA_mean.dat')
    CALL write4(irmoments_log,'S_Impulse_mean_log.dat')
    CALL write2(incgrwth,'S_meanLTinc_level.dat')
    CALL write2(levelmoments,'S_levelmoments.dat')
    CALL write2(changemoments1,'S_changemoments1.dat')
    CALL write2(changemoments5,'S_changemoments5.dat')
    CALL write_3(vasemoments1,'S_vasemoments1.dat')
    CALL write_3(vasemoments5,'S_vasemoments5.dat')
    CALL write_3(vasemoments1_log,'S_vasemoments1_log.dat')
    CALL write_3(vasemoments5_log,'S_vasemoments5_log.dat')
    CALL write_1(var_lny,'S_var_lny.dat')
    CALL write_1(EmpCDF,'S_EmpCDF.dat')

    DEALLOCATE(ydiag,rn_impute,uniform_imputation,nu_sim,shock_type)
  END SUBROUTINE diagnostic_moments

  SUBROUTINE SIM_RN
    USE myrandom, ONLY: ran1, gasdev
    IMPLICIT NONE
    INTEGER :: i,j,h,iar

    ! Now draw all the random numbers we will ever need.
    DO i=1,nrun*nsim
       DO j=1,nhip+1
          CALL gasdev(rn_hip(i,j))
       ENDDO

       DO j=1,nar
          CALL gasdev(rn_z0(i,j))
       ENDDO

       DO h=1,hmax
          DO iar=1,nar
             CALL ran1(rn_p_ar(iar,i,h))
             CALL gasdev(rn_eta(iar,i,h))
          ENDDO
          CALL ran1(rn_unemp(i,h))
          CALL ran1(rn_nu(i,h))
          CALL gasdev(rn_eps(i,h))
       ENDDO
    ENDDO
    IF(diagnostic==1) THEN
       DO i=1,nrun*nsim
          DO h=1,hmax
             CALL ran1(rn_impute(i,h))
          ENDDO
       ENDDO
    ENDIF
    DO h=1,hmax
       CALL ran1(rn_p_eps(:,h))
    ENDDO

  END SUBROUTINE SIM_RN

  SUBROUTINE GenBootMoms(param_input)
    USE UTILITIES, ONLY: write_1, write2, write_3, write4
    IMPLICIT NONE
    REAL(DP), DIMENSION(:), INTENT(IN) :: param_input
    REAL(DP) :: obj

    write(*,'(A45)') 'Bootsrap moments are being simulated.'
    Dirmoments_boot=0.0_DP;
    call readmoments

    CALL chdir(ADJUSTL(TRIM(main_path)))

    if(GenMoms==1) then
      CALL execute_command_line ('rm -r ./Bootstrap1')
      CALL execute_command_line ('mkdir -p ./Bootstrap1')
      CALL chdir('./Bootstrap1')


      call SIMULATE(param_input)
      obj= OBJ_FUNC(param_input)
      write(*,'(A40,f18.8)') "obj using data moments= ", obj

      DSdSkewKurt_L1=SdSkewKurt_L1
      DSdSkewKurt_L5=SdSkewKurt_L5
      Dirmoments=Dirmoments_boot
      Dincgrwth=incgrwth
      Dvar_lny=var_lny
      DEmpCDF=EmpCDF
    else
      CALL execute_command_line ('rm -r ./Bootstrap2')
      CALL execute_command_line ('mkdir -p ./Bootstrap2')
      CALL chdir('./Bootstrap2')
    endif

    call write_3(DSdSkewKurt_L1,'SdSkewKurt_L1.dat')
    call write_3(DSdSkewKurt_L5,'SdSkewKurt_L5.dat')
    call write4(Dirmoments,'ImpulseA_mean.dat')
    call write2(Dincgrwth,'meanLTinc_level.dat')
    call write_1(Dvar_lny,'var_lny.dat')
    call write_1(DEmpCDF,'EmpCDF.dat')

    obj= OBJ_FUNC(param_input)
    write(*,'(A40,f18.8)') "obj using monte carlo moments= ", obj
  END SUBROUTINE GenBootMoms


  SUBROUTINE AUTOCOVAR_MAT(covar_mat_level,corr_mat_level,covar_mat_diff,corr_mat_diff, &
       covar_diff10v1,corr_diff10v1,covar_diff10v2,corr_diff10v2)
    USE UTILITIES, ONLY: WRITEMatrix,dpmissing,covar
    IMPLICIT NONE
    REAL(DP), INTENT(OUT),DIMENSION(Hmax,Hmax) :: covar_mat_level,corr_mat_level
    REAL(DP), INTENT(OUT),DIMENSION(Hmax-1,Hmax-1) :: covar_mat_diff,corr_mat_diff
    REAL(DP), INTENT(OUT),DIMENSION(2,2) :: covar_diff10v1,corr_diff10v1,covar_diff10v2,corr_diff10v2
    REAL(DP) :: agedum(hmax),temp1(nsim), temp2(nsim), temp3(nsim)
    INTEGER, ALLOCATABLE :: emp(:,:),emp_tot(:)
    REAL(DP), ALLOCATABLE :: ycov(:,:)
    REAL(DP), PARAMETER :: prmiss=dpmissing-1.0_DP
    INTEGER :: h,n


    covar_mat_level=0.0_DP; corr_mat_level=0.0_DP
    covar_mat_diff=0.0_DP; corr_mat_diff=0.0_DP
    covar_diff10v1=0.0_DP; corr_diff10v1=0.0_DP
    covar_diff10v2=0.0_DP; corr_diff10v2=0.0_DP
    ! Begin covariance matrix for levels
    ALLOCATE(emp(nsim,hmax),emp_tot(nsim),ycov(nsim,hmax))
    emp=0
    WHERE(ysim>=rminwage)
       emp=1
       ycov=dlog(ysim)
    ELSEWHERE
       ycov=dpmissing
    endwhere
    emp_tot=SUM(emp,dim=2)
    DO h=1,HMAX
       WHERE(emp_tot<15)
          ycov(:,h)=dpmissing
       endwhere
       agedum(h)=SUM(ycov(:,h),mask=(ycov(:,h)<prmiss))/DBLE(COUNT(ycov(:,h)<prmiss))
       WHERE(ycov(:,h)<prmiss)
          ycov(:,h)=ycov(:,h)-agedum(h)
       endwhere
    END DO

    DO h=1,HMAX
       DO n=h,HMAX
          covar_mat_level(h,n)=covar(ycov(:,h),ycov(:,n))
       END DO
    END DO
    CALL WRITEMatrix(covar_mat_level,hmax,hmax,'covar_mat_level.csv')

    DO h=1,HMAX
       DO n=h,HMAX
          corr_mat_level(h,n)=covar_mat_level(h,n)/(dsqrt(covar_mat_level(h,h))*dsqrt(covar_mat_level(n,n)))
       END DO
    END DO
    CALL WRITEMatrix(corr_mat_level,hmax,hmax,'corr_mat_level.csv')
    ! End covariance matrix for levels

    ! Begin covariance matrix for growth between 25-34 and 35-44 and 40-49
    WHERE(ycov(:,10)<prmiss .AND. ycov(:,1)<prmiss)
       temp1=ycov(:,10)-ycov(:,1)
    ELSEWHERE
       temp1=dpmissing
    ENDWHERE
    WHERE(ycov(:,20)<prmiss .AND. ycov(:,11)<prmiss)
       temp2=ycov(:,20)-ycov(:,11)
    ELSEWHERE
       temp2=dpmissing
    ENDWHERE
    WHERE(ycov(:,25)<prmiss .AND. ycov(:,16)<prmiss)
       temp3=ycov(:,25)-ycov(:,16)
    ELSEWHERE
       temp3=dpmissing
    ENDWHERE
    covar_diff10v1(1,1)=covar(temp1,temp1)
    covar_diff10v1(1,2)=covar(temp1,temp2)
    covar_diff10v1(2,2)=covar(temp2,temp2)
    CALL WRITEMatrix(covar_diff10v1,2,2,'covar_diff10v1.csv')

    covar_diff10v2(1,1)=covar(temp1,temp1)
    covar_diff10v2(1,2)=covar(temp1,temp3)
    covar_diff10v2(2,2)=covar(temp3,temp3)
    CALL WRITEMatrix(covar_diff10v2,2,2,'covar_diff10v2.csv')

    DO h=1,2
       DO n=h,2
          corr_diff10v1(h,n)=covar_diff10v1(h,n)/(dsqrt(covar_diff10v1(h,h))*dsqrt(covar_diff10v1(n,n)))
          corr_diff10v2(h,n)=covar_diff10v2(h,n)/(dsqrt(covar_diff10v2(h,h))*dsqrt(covar_diff10v2(n,n)))
       END DO
    END DO
    CALL WRITEMatrix(corr_diff10v1,2,2,'corr_diff10v1.csv')
    CALL WRITEMatrix(corr_diff10v2,2,2,'corr_diff10v2.csv')
    ! End covariance matrix for growths 25-34 and 35-44 and 40-49

    ! Begin covariance matrix for growths
    DO h=1,HMAX-1
       WHERE(ycov(:,h+1)<prmiss .AND. ycov(:,h)<prmiss)
          ycov(:,h)=ycov(:,h+1)-ycov(:,h)
       ELSEWHERE
          ycov(:,h)=dpmissing
       ENDWHERE
    END DO

    DO h=1,HMAX-1
       DO n=h,HMAX-1
          covar_mat_diff(h,n)=covar(ycov(:,h),ycov(:,n))
       END DO
    END DO
    CALL WRITEMatrix(covar_mat_diff,hmax-1,hmax-1,'covar_mat_diff.csv')

    DO h=1,HMAX-1
       DO n=h,HMAX-1
          corr_mat_diff(h,n)=covar_mat_diff(h,n)/(dsqrt(covar_mat_diff(h,h))*dsqrt(covar_mat_diff(n,n)))
       END DO
    END DO
    CALL WRITEMatrix(corr_mat_diff,hmax-1,hmax-1,'corr_mat_diff.csv')
    ! End covariance matrix for growths

    DEALLOCATE(emp,emp_tot,ycov)
  END SUBROUTINE AUTOCOVAR_MAT

  SUBROUTINE SIMULATE(params0)
    USE UTILITIES, ONLY: mypctile,write2,CHOL,summarize,write_1,SdSkewKurt,dpmissing,histogram
    IMPLICIT NONE
    REAL(DP), INTENT(IN) :: params0(nest)
    REAL(DP) :: var_hip(nhip+1,nhip+1),rho_eta(nar),mu_eta(2),sd_z0(nar)
    REAL(DP) :: cholVB(nhip+1,nhip+1)
    INTEGER :: i,j,h,numobs,lbi,ubi,i2,tempint,n,numobs1
    REAL(DP) :: pctiles(1), pct_values(1), pct_trim_val(2)
    REAL(DP), DIMENSION(3,nvaseinc,nvasemnt)  :: SdSkewKurt_L1n,SdSkewKurt_L5n,SdSkewKurt_L1_logn,SdSkewKurt_L5_logn
    REAL(DP), DIMENSION(2,nirinc,nirchg,nlag+1) :: irmomentsn,irmoments_logn
    REAL(DP), DIMENSION(nLTincpct,LTh)   :: incgrwthn
    REAL(DP), DIMENSION(nvaseinc,hmax)   :: levelmomentsn
    REAL(DP), DIMENSION(nvaseinc,hmax-1) :: changemoments1n
    REAL(DP), DIMENSION(nvaseinc,hmax-5) :: changemoments5n
    REAL(DP), DIMENSION(hmax) :: var_lnyn
    REAL(DP), DIMENSION(3,nvaseinc,13) :: vasemoments1n,vasemoments5n,vasemoments1_logn,vasemoments5_logn
    REAL(DP), ALLOCATABLE :: hip(:,:)
    REAL(DP), ALLOCATABLE :: pdf_nu(:),ar_z1(:),nu(:)
    REAL(DP) :: sd_eta(2),pdf_ar,pr_eps,mu_eps(2),sd_eps(2),frac_unemp(HMAX),SSK_Z(Hmax,3)
    REAL(DP) :: a0,a1,a2,earnh,age_s,z2bounds(hmax,2)=0.0_DP,nu_kinv,nu_lambda
    REAL(DP) :: zbounds(hmax,2)=0.0_DP, zpct(hmax,9)=0.0_DP	! Simulated log income less transitory component
    REAL(DP), PARAMETER :: pctiles_trim(2)=(/40.0_DP,90.0_DP/), &
         pctls(9)=(/1.0_DP,5.0_DP,10.0_DP,25.0_DP,50.0_DP,75.0_DP,90.0_DP,95.0_DP,99.0_DP/)
    REAL(DP), DIMENSION(Hmax,Hmax) :: covar_mat_level,corr_mat_level
    REAL(DP), DIMENSION(Hmax-1,Hmax-1) :: covar_mat_diff,corr_mat_diff
    REAL(DP), DIMENSION(2,2) :: covar_diff10v1=0.0_DP,corr_diff10v1=0.0_DP, &
         covar_diff10v2=0.0_DP,corr_diff10v2=0.0_DP
    penalty_trim=0.0_DP

    ! Check if we have reasonable income level relative to rmininc
    a0=params0(1); a1=params0(2); a2=params0(3)
    DO h=1,hmax
       earnh=a0+(a1*DBLE(h))/10.0_DP+(a2*DBLE(h)**2)/100.0_DP
       IF(earnh<lnrminwage) THEN
          penalty_trim=penalty_trim+penalty0+penalty*(lnrminwage-earnh)**2
          RETURN
       ENDIF
    ENDDO

    ! Construct the var-cov matrix of the HIP component
    DO i=1,nhip+1
       var_hip(i,i)=MAX(0.000001_DP,params0(3+i)**2)
    ENDDO
    DO i=1,nhip+1
       DO j=1,nhip+1
          IF(i.NE.j) THEN
             var_hip(i,j)=MIN(0.99999_DP,MAX(-0.99999_DP,params0(i+j+3)))*dsqrt(var_hip(i,i))*dsqrt(var_hip(j,j))
          ENDIF
       ENDDO
    ENDDO
    IF(nhip>=1) THEN
       IF(nhip==1) THEN
          cholVB=CHOL(var_hip)
          cholVB(:,:)=TRANSPOSE(cholVB(:,:))
       ENDIF
    ELSE
       cholVB=dsqrt(var_hip(1,1))
    ENDIF

    mu_eta(1)=params0(7);
    rho_eta(1)=params0(8);
    pdf_ar=params0(9);
    mu_eta(2)=-mu_eta(1)*pdf_ar/(1.0_DP-pdf_ar);
    sd_eta(1)=params0(10);  sd_eta(2)=params0(11);
    sd_z0(1)=params0(12);

    nu_lambda=params0(13);			! Exponential parameters
    sd_eps(1)=params0(18); sd_eps(2)=params0(19);
    pr_eps=params0(20);
    mu_eps(1)=params0(21);
    mu_eps(2)=-mu_eps(1)*pr_eps/(1.0_DP-pr_eps);


    SdSkewKurt_L1=0.0_DP;	SdSkewKurt_L5=0.0_DP;
    irmoments=0.0_DP;
    incgrwth=0.0_DP;		var_lny=0.0_DP;
    levelmoments=0.0_DP;
    changemoments1=0.0_DP;	changemoments5=0.0_DP;
    vasemoments1=0.0_DP;	vasemoments5=0.0_DP;

    DO i=1,nrun
       ALLOCATE(hip(nsim,nhip+1))						! heterogeneous income profiles
       ALLOCATE(ar_z1(nsim))	! AR(1) components
       ALLOCATE(pdf_nu(nsim),nu(nsim))

       lbi= (i-1)*nsim+1; ubi= i*nsim
       hip = MATMUL(rn_hip(lbi:ubi,:),cholVB(:,:))

       ! we make z0 such that it is correlated with individual's own standard deviation
       ar_z1=sd_z0(1)*rn_z0(lbi:ubi,1)


       DO h=1,hmax
          age_s=DBLE(h)/DBLE(10)

          WHERE(rn_p_ar(1,lbi:ubi,h)<=pdf_ar)
             ar_z1 = rho_eta(1)*ar_z1 + mu_eta(1) + sd_eta(1)*rn_eta(1,lbi:ubi,h)
          ELSEWHERE
             ar_z1 = rho_eta(1)*ar_z1 + mu_eta(2) + sd_eta(2)*rn_eta(1,lbi:ubi,h)
          endwhere

          pdf_nu=dexp(params0(14)+params0(15)*age_s+params0(16)*ar_z1+params0(17)*age_s*ar_z1)
          pdf_nu=pdf_nu/(1.0_DP+pdf_nu)

          WHERE(rn_unemp(lbi:ubi,h)<=pdf_nu(:))
             nu = -dlog(rn_nu(lbi:ubi,h))/nu_lambda
          ELSEWHERE
             nu = 0.0_DP
          endwhere
          WHERE(rn_p_eps(lbi:ubi,h)<=pr_eps)
             ysim(:,h)=MAX(0.0_DP,(1.0_DP-nu)*dexp(MATMUL(hip,agemat(h,:)) + ar_z1 + &
                  + a0 + a1*age_s + a2*age_s**2 + mu_eps(1) + sd_eps(1)*rn_eps(lbi:ubi,h)))
          ELSEWHERE
             ysim(:,h)=MAX(0.0_DP,(1.0_DP-nu)*dexp(MATMUL(hip,agemat(h,:)) + ar_z1 + &
                  + a0 + a1*age_s + a2*age_s**2 + mu_eps(2) + sd_eps(2)*rn_eps(lbi:ubi,h)))
          endwhere
          IF (diagnostic==1) THEN
             WHERE(rn_p_ar(1,lbi:ubi,h)<=pdf_ar)
                shock_type(:,h,1)=1.0_DP
             ENDWHERE
             WHERE(rn_unemp(lbi:ubi,h)<=pdf_nu(:))
                 nu_sim(:,h)=1
                 shock_type(:,h,2)=1.0_DP
             ENDWHERE
             WHERE(rn_p_eps(lbi:ubi,h)<=pr_eps)
                shock_type(:,h,3)=1.0_DP
             ENDWHERE
             CALL mypctile(ar_z1,(/5.0_DP,95.0_DP/),zbounds(h,:),numobs)
             CALL mypctile(ar_z1,(/1.0_DP,99.0_DP/),z2bounds(h,:),numobs)
             CALL mypctile(ar_z1,pctls,zpct(h,:),numobs)
             CALL SdSkewKurt(ar_z1,SSK_Z(h,1),SSK_Z(h,2),SSK_Z(h,3))
          ENDIF


          IF(MOD(h,5)==1) THEN
             CALL mypctile(ysim(:,h),pctiles_trim,pct_trim_val,numobs)
             IF (pct_trim_val(1)<=rminwage) THEN
                penalty_trim=penalty_trim+penalty0+penalty*(1.0_DP-pct_trim_val(1)/rminwage)**2
             ENDIF
             IF (pct_trim_val(2)>=truncate) THEN
                penalty_trim=penalty_trim+penalty0+penalty*(pct_trim_val(2)/truncate-1.0_DP)**2
             ENDIF
             IF (penalty_trim>0.0_DP) THEN
                RETURN
             ENDIF
          ENDIF
       ENDDO
       DEALLOCATE(hip,ar_z1,pdf_nu,nu)
       IF(diagnostic==1) THEN
         WHERE(ysim>=rminwage)
            ydiag=dlog(ysim)
         ELSEWHERE
            ydiag=dpmissing
         endwhere
         call Histogram(RESHAPE(ydiag,(/NSIM*Hmax/)),50,'ysim_hist.out',0.001_DP)
       ENDIF
       WHERE(ysim>truncate) ysim=truncate  !Truncation

       IF(covar_se==1) RETURN

       IF(diagnostic==1) THEN

          CALL AUTOCOVAR_MAT(covar_mat_level,corr_mat_level,covar_mat_diff,corr_mat_diff, &
               covar_diff10v1,corr_diff10v1,covar_diff10v2,corr_diff10v2)

          WHERE(ysim>=rminwage)
             ydiag=dlog(ysim)
          ELSEWHERE
             ydiag=dlog(rminwage*0.1_DP)
          endwhere
          uniform_imputation = rn_impute(lbi:ubi,:)

          frac_unemp=DBLE(COUNT(nu_sim==1, DIM=1))/DBLE(NSIM)
          CALL write_1(frac_unemp,'frac_unemp.out')
          CALL write2(SSK_Z,'SSK_Z.out')
       ENDIF

       CALL MOMENTS(SdSkewKurt_L1n,SdSkewKurt_L5n,irmomentsn,incgrwthn,var_lnyn)
       SdSkewKurt_L1 = SdSkewKurt_L1 + SdSkewKurt_L1n/DBLE(nrun)
       SdSkewKurt_L5 = SdSkewKurt_L5 + SdSkewKurt_L5n/DBLE(nrun)
       irmoments = irmoments + irmomentsn/DBLE(nrun)
       incgrwth  = incgrwth  + incgrwthn/DBLE(nrun)
       var_lny	  = var_lny	  + var_lnyn/DBLE(nrun)
       IF(diagnostic==1) THEN
          CALL MOMENTS_DIAG(changemoments1n,changemoments5n,vasemoments1n,vasemoments5n, &
               levelmomentsn,SdSkewKurt_L1_logn,SdSkewKurt_L5_logn,irmoments_logn,vasemoments1_logn, &
               vasemoments5_logn)
          CALL write2(zbounds,'zbounds.dat')
          CALL write2(z2bounds,'z2bounds.dat')
          CALL write2(zpct,'zpctiles.dat')

          SdSkewKurt_L1_log = SdSkewKurt_L1_log + SdSkewKurt_L1_logn/DBLE(nrun)
          SdSkewKurt_L5_log = SdSkewKurt_L5_log + SdSkewKurt_L5_logn/DBLE(nrun)

          irmoments_log  = irmoments_log + irmoments_logn/DBLE(nrun)
          levelmoments   = levelmoments   + levelmomentsn/DBLE(nrun)
          changemoments1 = changemoments1 + changemoments1n/DBLE(nrun)
          changemoments5 = changemoments5 + changemoments5n/DBLE(nrun)
          vasemoments1   = vasemoments1   + vasemoments1n/DBLE(nrun)
          vasemoments5   = vasemoments5   + vasemoments5n/DBLE(nrun)

          vasemoments1_log = vasemoments1_log + vasemoments1_logn/DBLE(nrun)
          vasemoments5_log = vasemoments5_log + vasemoments5_logn/DBLE(nrun)
       ENDIF
    ENDDO
  END SUBROUTINE SIMULATE

  SUBROUTINE MOMENTS(SdSkewKurt_L1n,SdSkewKurt_L5n,irmomentsn,incgrwthn,var_lnyn)
    USE UTILITIES, ONLY: SdSkewKurt, dpmissing, sortrows,mypctile, mean_var,sort_index,write_3
    IMPLICIT NONE
    REAL(DP), INTENT(OUT), DIMENSION(3,nvaseinc,nvasemnt):: SdSkewKurt_L1n,SdSkewKurt_L5n
    REAL(DP), INTENT(OUT), DIMENSION(2,nirinc,nirchg,nlag+1) :: irmomentsn
    REAL(DP), INTENT(OUT), DIMENSION(nLTincpct,LTh) :: incgrwthn
    REAL(DP), INTENT(OUT), DIMENSION(hmax) :: var_lnyn
    REAL(DP), ALLOCATABLE :: longdata(:,:), temp(:,:), temp2(:,:),logincage(:)
    INTEGER,  ALLOCATABLE :: numobs(:),emp(:)
    REAL(DP), ALLOCATABLE :: LTinc(:,:)
    REAL(DP), PARAMETER :: prmiss=dpmissing-1.0_DP
    REAL(DP) :: agedum(hmax), avgagedum(hmax)
    INTEGER  :: i,j,h,k,l,nonmiss,nonmissL,nonmiss2,nh,h1,h2,unemp(28,10,5),unemp_nu(28,10,5)
    INTEGER  :: lb,ub,lba,uba,lb2,ub2,lb3,ub3,lbh,ubh,hb,numobs2,numunemp
    REAL(DP), DIMENSION(nvasemnt) :: SSK_L1,SSK_L5
    INTEGER,  PARAMETER :: df1(8)=(/2,6,1,2,3,4,6,11/)
    INTEGER,  PARAMETER :: df2(8)=(/1,1,0,0,0,0,0,0/)
    INTEGER, ALLOCATABLE :: rank(:)

    IF(diagnostic==1) ALLOCATE(rank(nsim))
    ! Compute age dummies and Variance of log income
    ALLOCATE(logincage(nsim))
    DO h=1,hmax
       WHERE(ysim(:,h)>=rminwage)
          logincage=dlog(ysim(:,h))
       ELSEWHERE
          logincage=dpmissing
       endwhere
       CALL mean_var(logincage,agedum(h),var_lnyn(h))
    ENDDO
    DEALLOCATE(logincage)

    agedum=dexp(agedum)
    avgagedum=0.0_DP
    DO h=1,hmax
       DO j=0,MIN(h,5)-1
          avgagedum(h)=avgagedum(h)+agedum(h-j)
       END DO
       avgagedum(h)=avgagedum(h)/DBLE(MIN(h,5))
    END DO

    ! Shape the data to a long format that will be used for
    ! cross-sectional and impulse response moments.
    ALLOCATE(longdata(nsim*28,9))		! contains data for 28 ages
    longdata(:,1)=0.0_DP				! avgwageres
    ALLOCATE(numobs(nsim))

    DO h=3,30
       lb=(h-3)*nsim+1
       ub=(h-2)*nsim

       ! Construct average past income
       numobs=0
       WHERE (ysim(:,h)<rminwage) numobs(:)=-5
       DO j=0,MIN(h,5)-1
          longdata(lb:ub,1) = longdata(lb:ub,1) + MAX(ysim(:,h-j),rminwage)
          WHERE (ysim(:,h-j)>=rminwage) numobs = numobs + 1
       END DO
       WHERE (numobs>=minobs)
          longdata(lb:ub,1)=longdata(lb:ub,1)/(DBLE(MIN(h,5))*avgagedum(h)) !!! avgagedum is in levels
       ELSEWHERE
          longdata(lb:ub,1)=dpmissing
       endwhere

       IF(diagnostic==1) THEN
          nonmiss=COUNT(longdata(lb:ub,1)<prmiss)
          CALL sort_index(longdata(lb:ub,1),rank,1,nsim)
          lb2=1
          DO j=1,10
             ub2=MIN(FLOOR(DBLE(nonmiss*(j*10)/100)),nonmiss)
             unemp(h-2,j,1)=ub2-lb2+1
             unemp(h-2,j,2)=COUNT(ysim(rank(lb2:ub2),h+1)<rminwage)
             unemp(h-2,j,3)=COUNT(ysim(rank(lb2:ub2),h+1)<rminwage .AND. ysim(rank(lb2:ub2),h+2)<rminwage)
             unemp(h-2,j,4)=COUNT(ysim(rank(lb2:ub2),h+1)<rminwage .AND. ysim(rank(lb2:ub2),h+6)<rminwage)

             unemp_nu(h-2,j,1)=ub2-lb2+1
             unemp_nu(h-2,j,2)=COUNT(nu_sim(rank(lb2:ub2),h+1)==1)
             unemp_nu(h-2,j,3)=COUNT(nu_sim(rank(lb2:ub2),h+1)==1 .AND. nu_sim(rank(lb2:ub2),h+2)==1)
             unemp_nu(h-2,j,4)=COUNT(nu_sim(rank(lb2:ub2),h+1)==1 .AND. nu_sim(rank(lb2:ub2),h+6)==1)


             IF(h+11<=hmax) THEN
                unemp(h-2,j,5)=COUNT(ysim(rank(lb2:ub2),h+1)<rminwage .AND. ysim(rank(lb2:ub2),h+11)<rminwage)
                unemp_nu(h-2,j,5)=COUNT(nu_sim(rank(lb2:ub2),h+1)==1 .AND. nu_sim(rank(lb2:ub2),h+11)==1)
             ELSE
                unemp(h-2,j,5)=0
                unemp_nu(h-2,j,5)=0
             ENDIF
             lb2=ub2+1
          ENDDO
       ENDIF


       ! Construct relevant arc percent changes at various horizons:

       ! y_{t+j}-y_{t} j=0,1,2,3,5,10
       DO j=1,8
          IF(h+df1(j)<=Hmax) THEN
             WHERE(ysim(:,h+df2(j))>=rminwage .OR. ysim(:,h+df1(j))>=rminwage)
                longdata(lb:ub,1+j)=2*(ysim(:,h+df1(j))/agedum(h+df1(j))-ysim(:,h+df2(j))/agedum(h+df2(j)))/ &
                     (ysim(:,h+df1(j))/agedum(h+df1(j))+ysim(:,h+df2(j))/agedum(h+df2(j)))
             ELSEWHERE
                longdata(lb:ub,1+j)=dpmissing
             endwhere
          ELSE
             longdata(lb:ub,1+j)=dpmissing
          ENDIF
       ENDDO

       ! Demean income changes at horizons relevant for impulse response functions
       DO l=1,nlag+1
          IF(h+df1(2+l)<=Hmax) THEN
             WHERE(longdata(lb:ub,3+l)<prmiss)
                longdata(lb:ub,3+l)=longdata(lb:ub,3+l)-SUM(longdata(lb:ub,3+l),&
                     mask=longdata(lb:ub,3+l)<prmiss)/DBLE(COUNT(longdata(lb:ub,3+l)<prmiss))
             endwhere
          ENDIF
       ENDDO
    ENDDO
    DEALLOCATE(numobs)

    IF(diagnostic==1) THEN
       DEALLOCATE(rank)
       CALL write_3(DBLE(unemp), 'unemp_pers.out')
       CALL write_3(DBLE(unemp_nu), 'nu_unemp_pers.out')
       !stop
    ENDIF

    ! Cross-sectional Moments
    SdSkewKurt_L1n=0.0_DP; SdSkewKurt_L5n=0.0_DP
    DO i=1,3 ! Age groups
       DO nh=1,nagebin(i)

          ! Identify the region of the array where the income for that agebin is stored
          IF(i==1) THEN
             IF(nh==1) THEN
                lb=1
                ub=3*nsim
             ELSE
                lb=3*nsim+1
                ub=8*nsim
             ENDIF
          ELSE
             h=agebinl(i)+5*(nh-1)
             lb=(h-1)*nsim+1
             ub=lb+5*nsim-1
          ENDIF

          ! Sort people on average past income (all stored in temp)
          ALLOCATE(temp(ub-lb+1,3))
          temp(:,1:3)=longdata(lb:ub,1:3)
          temp=sortrows(temp,1,nonmiss)
          DO j=1,nvaseinc
             lb=FLOOR(DBLE(nonmiss*(vaseincpct(j)-1)/100))+1
             ub=MIN(FLOOR(DBLE(nonmiss*(vaseincpct(j+1)-1)/100)),nonmiss)
             CALL SdSkewKurt(temp(lb:ub,2),SSK_L1(1),SSK_L1(2),SSK_L1(3))
             CALL SdSkewKurt(temp(lb:ub,3),SSK_L5(1),SSK_L5(2),SSK_L5(3))
             SdSkewKurt_L1n(i,j,:)=SdSkewKurt_L1n(i,j,:)+SSK_L1/DBLE(nagebin(i))
             SdSkewKurt_L5n(i,j,:)=SdSkewKurt_L5n(i,j,:)+SSK_L5/DBLE(nagebin(i))
          ENDDO
          DEALLOCATE(temp)
       ENDDO
    ENDDO

    ! Impulse response moments.
    irmomentsn=0.0_DP;

    DO i=1,2 ! Age groups
       ! Identify the region of the array where the income for that agebin is stored
       IF(i==1) THEN
          lb=1
          ub=8*nsim
       ELSE
          lb=8*nsim+1
          ub=23*nsim
       ENDIF

       ! Sort people on average past income (stored in temp)
       ALLOCATE(temp(ub-lb+1,7))
       temp(:,1)=longdata(lb:ub,1)
       temp(:,2:7)=longdata(lb:ub,4:9)
       temp=sortrows(temp,1,nonmiss)
       DO j=1,nirinc
          lb2=FLOOR(DBLE(nonmiss*(iravgincpct(j)-1)/100))+1
          ub2=MIN(FLOOR(DBLE(nonmiss*(iravgincpct(j+1)-1)/100)),nonmiss)

          ! Within each income group sort people on realized shocks (temp2)
          ALLOCATE(temp2(ub2-lb2+1,6))
          temp2=temp(lb2:ub2,2:7)
          temp2=sortrows(temp2,1,nonmiss2)
          DO k=1,nirchg
             lb3=FLOOR(DBLE(nonmiss2*(irchgpct(k)-1)/100))+1
             ub3=MIN(FLOOR(DBLE(nonmiss2*(irchgpct(k+1)-1)/100)),nonmiss2)
             irmomentsn(i,j,k,1)=SUM(temp2(lb3:ub3,1))/DBLE(ub3-lb3+1)
             DO l=1,nlag
                irmomentsn(i,j,k,l+1)=SUM(temp2(lb3:ub3,1+l))/DBLE(ub3-lb3+1)
             ENDDO
          ENDDO
          if(GenMoms==1) THEN
            numunemp=count(temp2(:,1)<=-1.99_DP)
            k=1; lb3=1; ub3=numunemp
            Dirmoments_boot(i,j,k,1)=SUM(temp2(lb3:ub3,1))/DBLE(ub3-lb3+1)
            DO l=1,nlag
               Dirmoments_boot(i,j,k,l+1)=SUM(temp2(lb3:ub3,1+l))/DBLE(ub3-lb3+1)
            ENDDO
            DO k=1,nirchg_data-1
               lb3=FLOOR(DBLE(numunemp+(nonmiss2-numunemp)*(irchgpct_boot(k)-1)/100))+1
               ub3=MIN(FLOOR(DBLE(numunemp+(nonmiss2-numunemp)*(irchgpct_boot(k+1)-1)/100)),nonmiss2)
               Dirmoments_boot(i,j,k+1,1)=SUM(temp2(lb3:ub3,1))/DBLE(ub3-lb3+1)
               DO l=1,nlag
                  Dirmoments_boot(i,j,k+1,l+1)=SUM(temp2(lb3:ub3,1+l))/DBLE(ub3-lb3+1)
               ENDDO
            ENDDO
          endif
          DEALLOCATE(temp2)
       ENDDO
       DEALLOCATE(temp)
    ENDDO
    DEALLOCATE(longdata)

    ! Income growth rates over the lifecycle w.r.t lifetime income
    ALLOCATE(emp(nsim))
    ALLOCATE(LTinc(nsim,LTh+1))
    emp=0
    LTinc=0.0_DP
    j=1
    DO h=1,hmax
       LTinc(:,1)=LTinc(:,1)+MAX(ysim(:,h),rminwage)
       WHERE(ysim(:,h)>=rminwage) emp=emp+1
       IF(MOD(h,5)==1) THEN
          LTinc(:,1+j)=MAX(ysim(:,h),rminwage)
          j=j+1
       ENDIF
    ENDDO
    LTinc(:,1)=LTinc(:,1)/DBLE(hmax)
    WHERE(emp<minemp) LTinc(:,1)=dpmissing
    DO i=1,EmpCDF_num-1
       EmpCDF(i)=DBLE(100*COUNT(emp<=i-1))/DBLE(Nsim)
    ENDDO
    EmpCDF(EmpCDF_num)=100.0_DP
    incgrwthn=0.0_DP;
    LTinc=sortrows(LTinc,1,nonmiss)
    DO j=1,nLTincpct
       lb=FLOOR(DBLE(nonmiss*(LTincpct(j)-1)/100))+1
       ub=MIN(FLOOR(DBLE(nonmiss*(LTincpct(j+1)-1)/100)),nonmiss)
       DO h=1,LTh
          incgrwthn(j,h) = SUM(LTinc(lb:ub,h+1))/DBLE(ub-lb+1)
       ENDDO
    ENDDO
    DEALLOCATE(LTinc)
    DEALLOCATE(emp)
  END SUBROUTINE MOMENTS

  SUBROUTINE MOMENTS_DIAG(changestats1,changestats5,vasepctL1det,vasepctL5det,levelstats,	&
       SdSkewKurt_L1_logn,SdSkewKurt_L5_logn,irmoments_logn,vasepctL1det_log,	&
       vasepctL5det_log)
    USE UTILITIES, ONLY: SdSkewKurt, dpmissing, sortrows, summarize, &
         mypctile, write_1,write4,summarize2,write_3,histogram,topshare
    IMPLICIT NONE
    REAL(DP), INTENT(OUT), DIMENSION(3,nvaseinc,nvasemnt):: SdSkewKurt_L1_logn,SdSkewKurt_L5_logn
    REAL(DP), INTENT(OUT), DIMENSION(2,nirinc,nirchg,nlag+1) :: irmoments_logn
    REAL(DP), INTENT(OUT), DIMENSION(13,hmax)   :: levelstats
    REAL(DP), INTENT(OUT), DIMENSION(13,hmax-1) :: changestats1
    REAL(DP), INTENT(OUT), DIMENSION(13,hmax-5) :: changestats5
    REAL(DP), INTENT(OUT), DIMENSION(3,nvaseinc,13) :: vasepctL1det,vasepctL5det,vasepctL1det_log,vasepctL5det_log
    REAL(DP), ALLOCATABLE :: longdata(:,:),temp(:,:),temp2(:,:),logincage(:),incchg_forhist(:),incarcchg_forhist(:)
    INTEGER,  ALLOCATABLE :: numobs(:),emp(:)
    REAL(DP), ALLOCATABLE :: LTincp(:)
    INTEGER,  ALLOCATABLE :: irageincb(:,:,:)
    REAL(DP), PARAMETER :: prmiss=dpmissing-1.0_DP
    REAL(DP) :: agedum(hmax), avgagedum(hmax),vase(13)
    INTEGER  :: i,j,h,k,l,nonmiss,nonmissL,nonmiss2,nh,h1,h2,lb1,ub1
    INTEGER  :: lb,ub,lba,uba,lb2,ub2,lb3,ub3,lbh,ubh,hb,numobs2,vsai
    REAL(DP), DIMENSION(nvasemnt) :: SSK_L1,SSK_L5
    INTEGER,  PARAMETER :: df1(8)=(/2,6,1,2,3,4,6,11/)
    INTEGER,  PARAMETER :: df2(8)=(/1,1,0,0,0,0,0,0/)
    REAL(DP), DIMENSION(99) :: LTincallpctv,LTincallpct
    REAL(DP), DIMENSION(nsim,hmax) :: yimp					! Imputed annual log income
    REAL(DP)  :: tempout(4)
		REAL(DP)  :: count_probs(3,nvaseinc),shock_probs(3,nvaseinc,nar+3)
    REAL(DP) :: nonemp_shc2(10),count_probs2(10),TOTAL
    REAL(DP), DIMENSION(6) :: shrpct,TopShr

    levelstats=0.0_DP
    changestats1=0.0_DP; 		changestats5=0.0_DP;
    vasepctL1det=0.0_DP; 		vasepctL1det_log=0.0_DP;
    vasepctL5det=0.0_DP; 		vasepctL5det_log=0.0_DP;
    SdSkewKurt_L1_logn=0.0_DP; 	SdSkewKurt_L5_logn=0.0_DP;
		shock_probs=0.0_DP; 		count_probs=0.0_DP;
    nonemp_shc2=0.0_DP ; count_probs2=0.0_DP

    ! Compute age dummies
    DO h=1,hmax
       agedum(h)=SUM(ydiag(:,h),mask=(ydiag(:,h)>=lnrminwage))/DBLE(COUNT(ydiag(:,h)>=lnrminwage))
    ENDDO
    agedum=dexp(agedum)
    avgagedum=0.0_DP
    DO h=1,hmax
       DO j=0,MIN(h,5)-1
          avgagedum(h)=avgagedum(h)+agedum(h-j)
       END DO
       avgagedum(h)=avgagedum(h)/DBLE(MIN(h,5))
    END DO

    ! Moments about log(income)
    ALLOCATE(logincage(nsim))
    ALLOCATE(incchg_forhist((hmax-1)*nsim),incarcchg_forhist((hmax-1)*nsim))
    DO h=1,hmax
       WHERE(ydiag(:,h)>=lnrminwage)
          logincage=ydiag(:,h)
       ELSEWHERE
          logincage=dpmissing
       endwhere
       CALL summarize(logincage,numobs2,levelstats(1,h),levelstats(2,h), &
            levelstats(3,h),levelstats(4,h),levelstats(5,h),levelstats(6,h), &
            levelstats(7,h),levelstats(8,h),levelstats(9,h),levelstats(10,h), &
            levelstats(11,h),levelstats(12,h),levelstats(13,h))

       ! Moments about log(income) changes
       !! L1
       IF(h<=hmax-1) THEN
          WHERE(ydiag(:,h)>=lnrminwage .AND. ydiag(:,h+1)>=lnrminwage )
             logincage=(ydiag(:,h+1)-dlog(agedum(h+1))) - &
                  (ydiag(:,h)-dlog(agedum(h)))
          ELSEWHERE
             logincage=dpmissing
          endwhere
          incchg_forhist((h-1)*nsim+1:h*nsim)=logincage
          CALL summarize(logincage,numobs2,changestats1(1,h), &
               changestats1(2,h),changestats1(3,h),changestats1(4,h),  &
               changestats1(5,h),changestats1(6,h),changestats1(7,h),  &
               changestats1(8,h),changestats1(9,h),changestats1(10,h), &
               changestats1(11,h),changestats1(12,h),changestats1(13,h))
          incarcchg_forhist((h-1)*nsim+1:h*nsim)= &
               2*( dexp(ydiag(:,h+1))/agedum(h+1) - dexp(ydiag(:,h))/agedum(h) )/ &
               ( dexp(ydiag(:,h+1))/agedum(h+1) + dexp(ydiag(:,h))/agedum(h) )
       ENDIF
       !! L5
       IF(h<=hmax-5) THEN
          WHERE(ydiag(:,h)>=lnrminwage .AND. ydiag(:,h+5)>=lnrminwage)
             logincage=(ydiag(:,h+5)-dlog(agedum(h+5))) - &
                  (ydiag(:,h)-dlog(agedum(h)))
          ELSEWHERE
             logincage=dpmissing
          endwhere
          CALL summarize(logincage,numobs2,changestats5(1,h), &
               changestats5(2,h),changestats5(3,h),changestats5(4,h), &
               changestats5(5,h),changestats5(6,h),changestats5(7,h), &
               changestats5(8,h),changestats5(9,h),changestats5(10,h), &
               changestats5(11,h),changestats5(12,h),changestats5(13,h))
       ENDIF
    ENDDO
    !call histogram so that we don't write huge files on hard drive.
    call Histogram(incchg_forhist,250,'incchg_hist.out')
    call Histogram(incarcchg_forhist,200,'incarcchg_hist200.out',0.1_DP)
    call Histogram(incarcchg_forhist,250,'incarcchg_hist250.out',0.01_DP)
    call Histogram(incarcchg_forhist,400,'incarcchg_hist400.out',0.01_DP)
    call Histogram(incarcchg_forhist,500,'incarcchg_hist500.out',0.01_DP)
!stop
    !call write_1(incchg_forhist,'incchg_forhist.dat')
    !call write_1(incarcchg_forhist,'incarcchg_forhist.dat')
    DEALLOCATE(logincage,incchg_forhist,incarcchg_forhist)

!!! We change log income to level of income and also impute low income levels (for log moments)
    ydiag=dexp(ydiag)
    WHERE(ydiag<rminwage)
       yimp = ydiag + 0.01_DP*uniform_imputation
       yimp = rminwage + 0.1_DP*rminwage*yimp/(rminwage+0.01_DP)
    ELSEWHERE
       yimp = ydiag
    endwhere

    ! Shape the data to a long format that will be used for
    ! cross-sectional and impulse response moments.
    ALLOCATE(longdata(nsim*28,21))		! contains data for 28 ages
    longdata(:,1)=0.0_DP				! avgwageres
    ALLOCATE(numobs(nsim))

    DO h=3,30
       lb=(h-3)*nsim+1
       ub=(h-2)*nsim

       ! Construct average past income
       numobs=0
       WHERE (ydiag(:,h)<rminwage) numobs(:)=-5
       DO j=0,MIN(h,5)-1
          longdata(lb:ub,1) = longdata(lb:ub,1) + MAX(ydiag(:,h-j),rminwage)
          WHERE (ydiag(:,h-j)>=rminwage) numobs = numobs + 1
       END DO
       WHERE (numobs>=minobs)
          longdata(lb:ub,1)=longdata(lb:ub,1)/(DBLE(MIN(h,5))*avgagedum(h)) !!! avgagedum is in levels
       ELSEWHERE
          longdata(lb:ub,1)=dpmissing
       endwhere
       ! Construct relevant arc percent changes at various horizons:
       ! y_{t+j}-y_{t} j=0,1,2,3,5,10
       DO j=1,8
          IF(h+df1(j)<=Hmax) THEN
             WHERE(ydiag(:,h+df2(j))>=rminwage .OR. ydiag(:,h+df1(j))>=rminwage)
                longdata(lb:ub,1+j)=2*(ydiag(:,h+df1(j))/agedum(h+df1(j))-ydiag(:,h+df2(j))/agedum(h+df2(j)))/ &
                     (ydiag(:,h+df1(j))/agedum(h+df1(j))+ydiag(:,h+df2(j))/agedum(h+df2(j)))
             ELSEWHERE
                longdata(lb:ub,1+j)=dpmissing
             endwhere
              WHERE(yimp(:,h+df2(j))<prmiss .AND. yimp(:,h+df1(j))<prmiss)
                 longdata(lb:ub,9+j)=dlog(yimp(:,h+df1(j))/agedum(h+df1(j))) - &
                      dlog(yimp(:,h+df2(j))/agedum(h+df2(j)))
              ELSEWHERE
                 longdata(lb:ub,9+j)=dpmissing
              endwhere
           ENDIF
       ENDDO
       !write(*,'(10I8)') h,count(longdata(lb:ub,:)>dpmissing-1.0_DP,DIM=1)

       ! Demean income changes at horizons relevant for impulse response functions
       DO l=1,nlag+1
          IF(h+df1(2+l)<=Hmax) THEN
             WHERE(longdata(lb:ub,3+l)<prmiss)
                longdata(lb:ub,3+l)=longdata(lb:ub,3+l)-SUM(longdata(lb:ub,3+l),&
                     mask=longdata(lb:ub,3+l)<prmiss)/DBLE(COUNT(longdata(lb:ub,3+l)<prmiss))
             endwhere
             WHERE(longdata(lb:ub,11+l)<prmiss)
                longdata(lb:ub,11+l)=longdata(lb:ub,11+l)-SUM(longdata(lb:ub,11+l),&
                     mask=longdata(lb:ub,11+l)<prmiss)/DBLE(COUNT(longdata(lb:ub,11+l)<prmiss))
             endwhere
          ENDIF
       ENDDO
       where (ydiag(:,h+1)>=rminwage)
        longdata(lb:ub,18) = 0.0_DP
       elsewhere
        longdata(lb:ub,18) = 1.0_DP
       endwhere

        ! Record shock types: 1=AR1, 2=nonemp, 3=eps, 4=any shock
       longdata(lb:ub,19)=shock_type(:,h+1,1)
       longdata(lb:ub,20)=shock_type(:,h+1,2)
       longdata(lb:ub,21)=shock_type(:,h+1,3)

    ENDDO
    DEALLOCATE(numobs)

    ! Cross-sectional Moments
    !vsai=1
    DO i=1,3 ! Age groups
       DO nh=1,nagebin(i)
          ! Identify the region of the array where the income for that agebin is stored
          IF(i==1) THEN
             IF(nh==1) THEN
                lb=1
                ub=3*nsim
             ELSE
                lb=3*nsim+1
                ub=8*nsim
             ENDIF
          ELSE
             h=agebinl(i)+5*(nh-1)
             lb=(h-1)*nsim+1
             ub=lb+5*nsim-1
          ENDIF

          ! Sort people on average past income (all stored in temp)
          ALLOCATE(temp(ub-lb+1,2))
          temp(:,1)=longdata(lb:ub,1)
          temp(:,2)=longdata(lb:ub,18)
          temp=sortrows(temp,1,nonmiss)
          DO j=1,10
             lb1=FLOOR(DBLE(nonmiss*(j-1)/10))+1
             ub1=MIN(FLOOR(DBLE(nonmiss*j/10))+1,nonmiss)
             nonemp_shc2(j)=nonemp_shc2(j)+SUM(temp(lb1:ub1,2))
             count_probs2(j)=count_probs2(j)+DBLE(ub1-lb1+1)
          ENDDO
          DEALLOCATE(temp)

          ! Sort people on average past income (all stored in temp)
          allocate(temp(ub-lb+1,8))
  				temp(:,1:8)=longdata(lb:ub,(/1:3,10,11,19:21/))
          temp=sortrows(temp,1,nonmiss)
          DO j=1,nvaseinc
             lb=FLOOR(DBLE(nonmiss*(vaseincpct(j)-1)/100))+1
             ub=MIN(FLOOR(DBLE(nonmiss*(vaseincpct(j+1)-1)/100)),nonmiss)
!!! Plotting Vase Figure
             CALL summarize2(temp(lb:ub,2),numobs2,tempout(1),tempout(2),tempout(3),tempout(4), &
                  vase(1),vase(2),vase(3),vase(4),vase(5),vase(6),   &
                  vase(7),vase(8),vase(9),vase(10),vase(11),vase(12),&
                  vase(13))
             vasepctL1det(i,j,:)=vasepctL1det(i,j,:)+vase/DBLE(nagebin(i))
             CALL summarize2(temp(lb:ub,3),numobs2,tempout(1),tempout(2),tempout(3),tempout(4), &
                  vase(1),vase(2),vase(3),vase(4),vase(5),vase(6),   &
                  vase(7),vase(8),vase(9),vase(10),vase(11),vase(12),&
                  vase(13))
             vasepctL5det(i,j,:)=vasepctL5det(i,j,:)+vase/DBLE(nagebin(i))
             CALL summarize2(temp(lb:ub,4),numobs2,tempout(1),tempout(2),tempout(3),tempout(4), &
                  vase(1),vase(2),vase(3),vase(4),vase(5),vase(6),   &
                  vase(7),vase(8),vase(9),vase(10),vase(11),vase(12),&
                  vase(13))
             vasepctL1det_log(i,j,:)=vasepctL1det_log(i,j,:)+vase/DBLE(nagebin(i))
             CALL summarize2(temp(lb:ub,5),numobs2,tempout(1),tempout(2),tempout(3),tempout(4), &
                  vase(1),vase(2),vase(3),vase(4),vase(5),vase(6),   &
                  vase(7),vase(8),vase(9),vase(10),vase(11),vase(12),&
                  vase(13))
             vasepctL5det_log(i,j,:)=vasepctL5det_log(i,j,:)+vase/DBLE(nagebin(i))
             CALL SdSkewKurt(temp(lb:ub,4),SSK_L1(1),SSK_L1(2),SSK_L1(3))
             CALL SdSkewKurt(temp(lb:ub,5),SSK_L5(1),SSK_L5(2),SSK_L5(3))
             SdSkewKurt_L1_logn(i,j,:)=SdSkewKurt_L1_logn(i,j,:)+SSK_L1/DBLE(nagebin(i))
             SdSkewKurt_L5_logn(i,j,:)=SdSkewKurt_L5_logn(i,j,:)+SSK_L5/DBLE(nagebin(i))

             ! Shock probabilities
   					shock_probs(i,j,1)=shock_probs(i,j,1)+dble(count(temp(lb:ub,6)==1))
   					shock_probs(i,j,2)=shock_probs(i,j,2)+dble(count(temp(lb:ub,7)==1))
   					shock_probs(i,j,3)=shock_probs(i,j,3)+dble(count(temp(lb:ub,8)==1))
   					shock_probs(i,j,4)=shock_probs(i,j,4)+dble(count(temp(lb:ub,6)==1 .or. temp(lb:ub,7)==1 .or. temp(lb:ub,8)==1))
   					count_probs(i,j)=count_probs(i,j)+dble(ub-lb+1)
          ENDDO
          !vsai=vsai+1
          DEALLOCATE(temp)
       ENDDO
       do j=1,nvaseinc
         shock_probs(i,j,1)=shock_probs(i,j,1)/count_probs(i,j)
         shock_probs(i,j,2)=shock_probs(i,j,2)/count_probs(i,j)
         shock_probs(i,j,3)=shock_probs(i,j,3)/count_probs(i,j)
         shock_probs(i,j,4)=shock_probs(i,j,4)/count_probs(i,j)
       enddo
    ENDDO
    nonemp_shc2=nonemp_shc2/count_probs2
    CALL write_1(nonemp_shc2,'nonemp_shc2.dat')
		call write_3(shock_probs,'shock_prob.dat')

    ! Now, moments related to impulse response. Here's what we do: within each age,
    ! sort wrt avg past income and assign groups. Then within agebins sort the data wrt
    ! these groups. At the same time, compute normalized income change btw. t and t-1,
    ! by taking out the mean change for each age (so they have zero mean).
    ! Within each agebin and avg past income group, sort wrt normalized income change
    ! btw. t and t-1. Assign groups.
    ! Within each (agebin,avg past income group,normalized income change group) compute
    ! average (normalized) F1,F2,F3,F5,F10.

    ! Impulse response moments.
    irmoments_logn=0.0_DP;
    DO i=1,2 ! Age groups

       ! Identify the region of the array where the income for that agebin is stored
       IF(i==1) THEN
          lb=1
          ub=8*nsim
       ELSE
          lb=8*nsim+1
          ub=23*nsim
       ENDIF

       ! Sort people on average past income (stored in temp)

        ALLOCATE(temp(ub-lb+1,13))
        temp(:,1)=longdata(lb:ub,1)
        temp(:,2:7)=longdata(lb:ub,4:9)
        temp(:,8:13)=longdata(lb:ub,12:17)
       temp=sortrows(temp,1,nonmiss)
       DO j=1,nirinc
          lb2=FLOOR(DBLE(nonmiss*(iravgincpct(j)-1)/100))+1
          ub2=MIN(FLOOR(DBLE(nonmiss*(iravgincpct(j+1)-1)/100)),nonmiss)
         ! Within each income group sort people on realized shocks (temp2)
         ALLOCATE(temp2(ub2-lb2+1,6))
         temp2=temp(lb2:ub2,8:13)
         temp2=sortrows(temp2,1,nonmiss2)
         DO k=1,nirchg
            lb3=FLOOR(DBLE(nonmiss2*(irchgpct(k)-1)/100))+1
            ub3=MIN(FLOOR(DBLE(nonmiss2*(irchgpct(k+1)-1)/100)),nonmiss2)
            irmoments_logn(i,j,k,1)=SUM(temp2(lb3:ub3,1))/DBLE(ub3-lb3+1)
            DO l=1,nlag
               irmoments_logn(i,j,k,l+1)=SUM(temp2(lb3:ub3,1+l))/DBLE(ub3-lb3+1)
            ENDDO
         ENDDO
         DEALLOCATE(temp2)
       ENDDO
       DEALLOCATE(temp)
    ENDDO
    DEALLOCATE(longdata)

    ! lifetime income between h1 and h2
    h1=1;    h2=hmax-5;
    ALLOCATE(emp(nsim));   emp=0;
    ALLOCATE(LTincp(nsim))
    DO h=h1,h2
       WHERE(ydiag(:,h)>=rminwage) emp=emp+1
    ENDDO

    LTincp=sum(ydiag(:,h1:h2),DIM=2)
    LTincp=LTincp/DBLE(h2-h1+1)
    LTincallpct=(/(DBLE(i),i=1,99)/)
    shrpct=(/90.0_DP,99.0_DP,99.9_DP,80.0_DP,98.0_DP,99.8_DP/)
    CALL mypctile(LTincp,LTincallpct,LTincallpctv,numobs2)
    CALL write_1(LTincallpctv,'LTincallpctv_zeros.dat')
    call topshare(LTincp,shrpct,TopShr,numobs2)
    call write_1(TopShr,'TopShr_zeros.out')

    WHERE(emp<minemp) LTincp=dpmissing
    CALL mypctile(LTincp,LTincallpct,LTincallpctv,numobs2)
    CALL write_1(LTincallpctv,'LTincallpctv.dat')
    call topshare(LTincp,shrpct,TopShr,numobs2)
    call write_1(TopShr,'TopShr.out')

    DEALLOCATE(LTincp)
    DEALLOCATE(emp)
  END SUBROUTINE MOMENTS_Diag

  SUBROUTINE dfovec(n, mv, x, v_err)
    !     SUBROUTINE dfovec(n, mv, x, v_err) must be provided by the user.
    !     It must provide the values of the vector function v_err(x) : R^n to R^{mv}
    !     at the variables X(1),X(2),...,X(N), which are generated automatically in
    !     a way that satisfies the bounds given in XL and XU.

    !     Min  F(x) := Sum_{i=1}^{mv}  v_err_i(x)^2, s.t. xl <= x <= xu, x \in R^n,
    !     where v_err(x) : R^n \to R^{mv} is a vector function.
    USE UTILITIES, ONLY : write_1
    IMPLICIT NONE
    INTEGER, INTENT(IN) :: n,mv
    REAL(DP), DIMENSION(n), INTENT(IN)   :: x
    REAL(DP), DIMENSION(mv), INTENT(OUT) :: v_err
    INTEGER :: h,i,j,k,l
    REAL(DP) :: temp(nest), targ(nlag)
    REAL(DP) :: tempm(3,nvaseinc,nvasemnt), tempp(nLTincpct,LTh)
    REAL(DP) :: obj(12),weights_d(nmoments+1)

    penalty_indicator=0

    temp=penalty*(MAX(0.0_DP,param_bound(:,1)-x)/MAX(0.10_DP,dabs(param_bound(:,1))))**2 + &
         penalty*(MAX(0.0_DP,x-param_bound(:,2))/MAX(0.10_DP,dabs(param_bound(:,2))))**2

    v_err=0.0_DP
    v_err(nmoments+1) = SUM(temp)
    !v_err(nmoments+1) = v_err(nmoments+1) + penalty*min(0.0_DP,1.03_DP-x(9)-x(10))**2		! rho(2)<0.95

    ! Penalty
    IF(v_err(nmoments+1)>EPSILON(1.0_DP)) THEN
       v_err(1:nmoments+1)=(penalty0+dabs(v_err(nmoments+1)))/dsqrt(DBLE(nmoments+1))
       penalty_indicator=1
    ELSE
       CALL SIMULATE(x)
       IF (penalty_trim>0.0_DP) THEN
          v_err=penalty_trim/dsqrt(DBLE(nmoments+1))
          penalty_indicator=1
       ELSE
          tempm=(DSdSkewKurt_L1-SdSkewKurt_L1)/((dabs(DSdSkewKurt_L1)+dabs(SdSkewKurt_L1))/2.0_DP + &
               scale_moments(1))
          v_err(1:3*nvaseinc)=RESHAPE(tempm(:,:,1),(/3*nvaseinc/))
          v_err(1+3*nvaseinc:3*nvaseinc*2)=RESHAPE(tempm(:,:,2),(/3*nvaseinc/))
          v_err(1+3*nvaseinc*2:3*nvaseinc*3)=RESHAPE(tempm(:,:,3),(/3*nvaseinc/))

          tempm=(DSdSkewKurt_L5-SdSkewKurt_L5)/((dabs(DSdSkewKurt_L5)+dabs(SdSkewKurt_L5))/2.0_DP + &
               scale_moments(2))
          v_err(1+3*nvaseinc*3:3*nvaseinc*4)=RESHAPE(tempm(:,:,1),(/3*nvaseinc/))
          v_err(1+3*nvaseinc*4:3*nvaseinc*5)=RESHAPE(tempm(:,:,2),(/3*nvaseinc/))
          v_err(1+3*nvaseinc*5:nmom1)=RESHAPE(tempm(:,:,3),(/3*nvaseinc/))

          l=nmom1

          ! Here, we need to do the interpolation for impulse response moments.
          DO h=1,2
             DO i=1,nirinc
                DO j=1,nirchg
                   CALL impulse(h,i,irmoments(h,i,j,1),targ)
                   v_err(l+1:l+nlag)=(targ-irmoments(h,i,j,2:nlag+1))/ &
                        ((dabs(targ)+dabs(irmoments(h,i,j,2:nlag+1)))/2.0_DP+scale_moments(3))
                   IF(diagnostic==1) THEN
                     obj_imp_S = obj_imp_S + DOT_PRODUCT(v_err(l+1:l+3),v_err(l+1:l+3))
                     obj_imp_L = obj_imp_L + DOT_PRODUCT(v_err(l+4:l+nlag),v_err(l+4:l+nlag))
                   ENDIF
                   l=l+nlag
                ENDDO
             ENDDO
          ENDDO

          tempp=(Dincgrwth-incgrwth)/((dabs(Dincgrwth)+dabs(incgrwth))/2.0_DP+scale_moments(4))
          v_err(1+nmom1+nmom2:nmom1+nmom2+nmom3)=RESHAPE(tempp,(/nLTincpct*LTh/))

          v_err(1+nmom1+nmom2+nmom3:nmom1+nmom2+nmom3+nmom4)=(Dvar_lny-var_lny)/ &
               ((dabs(Dvar_lny)+dabs(var_lny))/2.0_DP+scale_moments(5))

          v_err(1+nmom1+nmom2+nmom3+nmom4:nmoments)=(DEmpCDF(1:EmpCDF_num-1)-EmpCDF(1:EmpCDF_num-1))/ &
               ((dabs(DEmpCDF(1:EmpCDF_num-1))+dabs(EmpCDF(1:EmpCDF_num-1)))/2.0_DP)
          IF(diagnostic==1) THEN

             ! Computing weights
             weights_d=0.0_DP
             weights_d(1:nmom1) = 1.0_DP/DBLE(nmom1)
             weights_d(nmom1+1:nmom1+nmom2) =1.0_DP/DBLE(nmom2)
             weights_d(nmom1+nmom2+1:nmom1+nmom2+nmom3) = 1.0_DP/DBLE(nmom3)
             weights_d(nmom1+nmom2+nmom3+1:nmom1+nmom2+nmom3+nmom4) = 1.0_DP/DBLE(nmom4)
             weights_d(1+nmom1+nmom2+nmom3+nmom4:nmoments) = 1.0_DP/DBLE(nmom5)
             weights_d=dsqrt(weights_d)

             obj(1)=DOT_PRODUCT(v_err(1:3*nvaseinc),v_err(1:3*nvaseinc))/DBLE(nmom1)
             obj(2)=DOT_PRODUCT(v_err(1+3*nvaseinc:3*nvaseinc*2), &
                  v_err(1+3*nvaseinc:3*nvaseinc*2))/DBLE(nmom1)
             obj(3)=DOT_PRODUCT(v_err(1+3*nvaseinc*2:3*nvaseinc*3), &
                  v_err(1+3*nvaseinc*2:3*nvaseinc*3))/DBLE(nmom1)
             obj(4)=DOT_PRODUCT(v_err(1+3*nvaseinc*3:3*nvaseinc*4), &
                  v_err(1+3*nvaseinc*3:3*nvaseinc*4))/DBLE(nmom1)
             obj(5)=DOT_PRODUCT(v_err(1+3*nvaseinc*4:3*nvaseinc*5), &
                  v_err(1+3*nvaseinc*4:3*nvaseinc*5))/DBLE(nmom1)
             obj(6)=DOT_PRODUCT(v_err(1+3*nvaseinc*5:3*nvaseinc*6), &
                  v_err(1+3*nvaseinc*5:3*nvaseinc*6))/DBLE(nmom1)

             obj(7)=DOT_PRODUCT(v_err(nmom1+1:nmom1+nmom2),v_err(nmom1+1:nmom1+nmom2))/DBLE(nmom2)
             obj(8)=obj_imp_S/DBLE(3*nmom2/5)
             obj(9)=obj_imp_L/DBLE(2*nmom2/5)
             obj(10)=DOT_PRODUCT(v_err(nmom1+nmom2+1:nmom1+nmom2+nmom3), &
                  v_err(nmom1+nmom2+1:nmom1+nmom2+nmom3))/DBLE(nmom3)
             obj(11)=DOT_PRODUCT(v_err(nmom1+nmom2+nmom3+1:nmom1+nmom2+nmom3+nmom4), &
                  v_err(nmom1+nmom2+nmom3+1:nmom1+nmom2+nmom3+nmom4))/DBLE(nmom4)
             obj(12)=DOT_PRODUCT(v_err(nmom1+nmom2+nmom3+nmom4+1:nmoments), &
                  v_err(nmom1+nmom2+nmom3+nmom4+1:nmoments))/DBLE(nmom5)
             OPEN(unit=1102, file='unweighted_obj_values.out', STATUS='replace')
             WRITE(1102,'(f20.10)') obj,v_err(nmoments+1),dsqrt(SUM(obj) + &
                  v_err(nmoments+1)-obj(8)-obj(9));
             CLOSE(1102)
             CALL write_1(weights_d*v_err,'unweighted_verr.out')
          ENDIF
          v_err(1:nmoments)=v_err(1:nmoments)*weights
       ENDIF
    ENDIF
  CONTAINS
    SUBROUTINE impulse(age,inc,chg,itarg)
      USE UTILITIES, ONLY : LOCATE
      IMPLICIT NONE
      INTEGER, INTENT(IN) :: age,inc
      REAL(DP), INTENT(IN) :: chg
      REAL(DP), INTENT(OUT) :: itarg(nlag)
      INTEGER :: lo,hi,lg
      REAL(DP) :: sx


      LO=MAX(MIN(LOCATE(Dirmoments(age,inc,:,1),chg),nirchg_data-1),1)
      HI=LO+1

      sx=(chg-Dirmoments(age,inc,LO,1))/(Dirmoments(age,inc,HI,1)-Dirmoments(age,inc,LO,1))

      DO lg=1,nlag
         itarg(lg)=Dirmoments(age,inc,LO,1+lg)+ &
              (Dirmoments(age,inc,HI,1+lg)-Dirmoments(age,inc,LO,1+lg))*sx
      ENDDO
    END SUBROUTINE impulse
  END SUBROUTINE dfovec

  REAL(DP) FUNCTION OBJ_FUNC(params0)
    USE UTILITIES, ONLY : write_1
    IMPLICIT NONE
    REAL(DP), DIMENSION(:), INTENT(IN)  :: params0
    REAL(DP), DIMENSION(nmoments+1)  :: verr
    REAL(DP) :: obj(12)

    CALL dfovec(nest,nmoments+1,params0,verr)
    IF(diagnostic==1) THEN
       obj(1)=DOT_PRODUCT(verr(1:3*nvaseinc),verr(1:3*nvaseinc))
       obj(2)=DOT_PRODUCT(verr(1+3*nvaseinc:3*nvaseinc*2),verr(1+3*nvaseinc:3*nvaseinc*2))
       obj(3)=DOT_PRODUCT(verr(1+3*nvaseinc*2:3*nvaseinc*3),verr(1+3*nvaseinc*2:3*nvaseinc*3))
       obj(4)=DOT_PRODUCT(verr(1+3*nvaseinc*3:3*nvaseinc*4),verr(1+3*nvaseinc*3:3*nvaseinc*4))
       obj(5)=DOT_PRODUCT(verr(1+3*nvaseinc*4:3*nvaseinc*5),verr(1+3*nvaseinc*4:3*nvaseinc*5))
       obj(6)=DOT_PRODUCT(verr(1+3*nvaseinc*5:3*nvaseinc*6),verr(1+3*nvaseinc*5:3*nvaseinc*6))
       obj(7)=DOT_PRODUCT(verr(nmom1+1:nmom1+nmom2),verr(nmom1+1:nmom1+nmom2))
       obj(8)=obj_imp_S/DBLE(7*3*nmom2/5)
       obj(9)=obj_imp_L/DBLE(7*2*nmom2/5)
       obj(10)=DOT_PRODUCT(verr(nmom1+nmom2+1:nmom1+nmom2+nmom3),verr(nmom1+nmom2+1:nmom1+nmom2+nmom3))
       obj(11)=DOT_PRODUCT(verr(nmom1+nmom2+nmom3+1:nmom1+nmom2+nmom3+nmom4), &
            verr(nmom1+nmom2+nmom3+1:nmom1+nmom2+nmom3+nmom4))
       obj(12)=DOT_PRODUCT(verr(nmom1+nmom2+nmom3+nmom4+1:nmoments), &
            verr(nmom1+nmom2+nmom3+nmom4+1:nmoments))
       OPEN(unit=1102, file='obj_values.out', STATUS='replace')
       WRITE(1102,'(f20.10)') obj,verr(nmoments+1),dsqrt(SUM(obj)+verr(nmoments+1)-obj(8)-obj(9));
       CLOSE(1102)
       CALL write_1(verr,'verr.out')
    ENDIF
    OBJ_FUNC = DOT_PRODUCT(verr,verr)
    OBJ_FUNC = dsqrt(OBJ_FUNC)
    RETURN
  END FUNCTION OBJ_FUNC
END MODULE OBJECTIVE
