!===================================================================================
!   This program is a global minimization routine. It takes its objective function
!   from the OBJECTIVE module.
!===================================================================================
PROGRAM MAIN
  USE OBJECTIVE, ONLY : OBJ_INIT, readmoments,SIM_RN, nest, pguess, &
       OBJ_FUNC,diagnostic_moments,diagnostic, param_bound,HMAX, &
       AUTOCOVAR_MAT,COVAR_SE,GenBootMoms,main_path,Bootstrap,dfovec,nmoments,weights,GenMoms
  USE UTILITIES, ONLY : write2, mysleep, DP,write_3,WRITEMatrix,myread1,sort_index,myread2
  USE ran_state, ONLY : ran_seed
  USE myrandom, only: ran1
  IMPLICIT NONE
  INTERFACE
     SUBROUTINE EST_DIV(initterm,call_amoeba,nstart,qr_ndraw,minlegit, &
          pinit,param_init,fval_saved,pest_saved)
       USE OBJECTIVE, ONLY : nest
       USE UTILITIES, ONLY : DP
       IMPLICIT NONE
       INTEGER, INTENT(INOUT) :: initterm,call_amoeba
       INTEGER, INTENT(IN)    :: nstart,qr_ndraw,minlegit
       REAL(DP), INTENT(IN)   :: pinit(nest)
       REAL(DP), INTENT(OUT)  :: param_init(nstart,nest), fval_saved(nstart), pest_saved(nstart,nest)
     END SUBROUTINE EST_DIV
  END INTERFACE
  INTEGER :: moments_ready,initterm,call_amoeba,call_amoeba_in=1, j
  INTEGER, PARAMETER :: runbootstrap=0, NBoot=100	! 1 if run GenBootMoms
  INTEGER, PARAMETER :: rundiagnostic=1		! 1 if you want to run diagnostic check
  INTEGER, PARAMETER :: runcovar=0, num_covar=50		! 1 if you want to run standard errors for covariance
  INTEGER, PARAMETER :: plot_obj=0		    ! 1 if you want to plot objective function
  INTEGER, PARAMETER :: qr_ndraw=900000, minlegit=300000 ! Number of draws from Sobol Sequence
  INTEGER, PARAMETER :: nstart=2000			! Number of initial points to be estimated
  REAL(DP) :: pinit(nest),pstart(nstart,nest),pest(nstart,nest+1), ptemp(nest),fval
  REAL(DP) :: time_before,time_after,lb_xi, ub_xi,temp(2*nstart,nest+3),runi(nest),time_before_boot
  INTEGER  :: i, now(3), nowi,xi,ai,aj
  INTEGER, PARAMETER  :: nxi=100				! number of grid points for the parameter of interest
  REAL(DP), DIMENSION(num_covar,Hmax,Hmax) :: covar_mat_level,corr_mat_level
  REAL(DP), DIMENSION(num_covar,Hmax-1,Hmax-1) :: covar_mat_diff,corr_mat_diff
  REAL(DP), DIMENSION(num_covar,2,2) :: covar_diff10v2,covar_diff10v1
  REAL(DP), DIMENSION(num_covar,2,2) :: corr_diff10v2,corr_diff10v1
  REAL(DP), DIMENSION(Hmax,Hmax) :: avg_covar_mat_level=0.0_DP,avg_corr_mat_level=0.0_DP
  REAL(DP), DIMENSION(Hmax-1,Hmax-1) :: avg_covar_mat_diff=0.0_DP,avg_corr_mat_diff=0.0_DP
  REAL(DP), DIMENSION(Hmax,Hmax) :: se_covar_mat_level=0.0_DP,se_corr_mat_level=0.0_DP
  REAL(DP), DIMENSION(Hmax-1,Hmax-1) :: se_covar_mat_diff=0.0_DP,se_corr_mat_diff=0.0_DP
  REAL(DP), DIMENSION(2,2) :: se_covar_diff10v2,se_corr_diff10v2,se_covar_diff10v1,se_corr_diff10v1
  REAL(DP), DIMENSION(2,2) :: avg_covar_diff10v2,avg_corr_diff10v2,avg_covar_diff10v1,avg_corr_diff10v1
  REAL(DP), PARAMETER :: tolf_amoeba= 1.0d-4		! Amoeba variables
	INTEGER,  PARAMETER :: itmax_amoeba=4000
  INTEGER  :: iter_n,pindy(2*nstart),pinda(nest+1),seqno=0,nsearch
  REAL(DP) :: amoeba_pts(nest+1,nest),amoeba_y(nest+1),rangeN(nest,2),minf,best_param(nest)
  REAL(DP), DIMENSION(nmoments+1) :: verr,unw_verr

  diagnostic=rundiagnostic
  covar_se=runcovar
  CALL ran_seed(SEQUENCE=1976)
  CALL OBJ_INIT
  CALL CPU_TIME(time_before)

  CALL getcwd(main_path)
  main_path=TRIM(main_path)

  IF (rundiagnostic==1) THEN
     CALL readmoments
     OPEN(73,file='param_diagnostic.dat') ; READ(73,*) pinit; CLOSE(73)
     !pinit=pguess
     DO i=1,nest
        WRITE(*,'(f15.5)') pinit(i)
     ENDDO
     CALL diagnostic_moments(pinit)
     CALL CPU_TIME(time_after)
     WRITE(*,'(A 40,f18.5,A12)') 'Time for Diagnostic  ',time_after-time_before,'  seconds.'
     STOP
  ENDIF

  1239  format(i6, 2000f24.12)
  if(runbootstrap>0) then
      open(73,file='param_diagnostic.dat') ; read(73,*) pinit; close(73)
      call myread2(temp,'saved_pest.dat',iter_n)
      call sort_index(dble(temp(1:iter_n,3)),pindy(1:iter_n),1,iter_n)
      do ai=1,nest
        rangeN(ai,1)=minval(temp(pindy(1:iter_n),ai+3))
        rangeN(ai,2)=maxval(temp(pindy(1:iter_n),ai+3))
      enddo
      ! WHERE(rangeN(:,2)<=rangeN(:,1))
      !   rangeN(:,1)=param_bound(:,1)
      !   rangeN(:,2)=param_bound(:,2)
      ! ENDWHERE
      ! WHERE(rangeN(:,1)<param_bound(:,1))
      !   rangeN(:,1)=param_bound(:,1)
      ! ENDWHERE
      ! WHERE(rangeN(:,2)>param_bound(:,2))
      !   rangeN(:,2)=param_bound(:,2)
      ! ENDWHERE
      call myread1(initterm,'initterm.txt')
      if(initterm==1) then
        initterm=0; open(32,file='initterm.txt', STATUS='replace'); write(32,*) initterm; close(32)
        Bootstrap=1; open(35,file='Bootstrap.txt', STATUS='replace'); write(35,*) Bootstrap; close(35)
        if(runbootstrap==1) GenMoms=1
        if(runbootstrap==2) GenMoms=0
        call GenBootMoms(pinit)
        CALL chdir(ADJUSTL(TRIM(main_path)))
        if(runbootstrap==1) CALL chdir('./Bootstrap1')
        if(runbootstrap==2) CALL chdir('./Bootstrap2')
        open(73,file='param_diagnostic.out', STATUS='replace'); write(73,*) pinit; close(73)
        open(unit=647, file='Bootstrap_init.dat', STATUS='replace'); close(647)
        open(unit=547, file='Bootstrap_all_est.dat', STATUS='replace'); close(547)
        open(unit=747, file='Bootstrap.dat', STATUS='replace'); close(747)
        open(unit=847, file='Bootstrap_verr.dat', STATUS='replace'); close(847)
        open(unit=947, file='Bootstrap_verr_unw.dat', STATUS='replace'); close(947)

        seqno=0; open(unit=31, file='seqno.txt', STATUS='replace'); write(31,*) seqno; close(31)
        Bootstrap=2; open(35,file='Bootstrap.txt', STATUS='replace'); write(35,*) Bootstrap; close(35)
      ELSE
        CALL chdir(ADJUSTL(TRIM(main_path)))
        if(runbootstrap==1) CALL chdir('./Bootstrap1')
        if(runbootstrap==2) CALL chdir('./Bootstrap2')
        DO WHILE (Bootstrap<2)
          call myread1(Bootstrap,'Bootstrap.txt')
          call mysleep(30.0_DP,"Waiting for Monte carlo moments to be created.")
        ENDDO
      ENDIF
  ENDIF
  if(bootstrap==2) then
    call readmoments
    do
      call myread1(seqno,'seqno.txt')
      seqno=seqno+1; open(33,file='seqno.txt', STATUS='replace'); write(33,*) seqno; close(33)
      if(seqno>Nboot) exit
      call itime(now)
      nowi=now(3)*60*60+now(2)*60+now(1)
      print*,"seqno=", seqno, "nowi=",nowi
      call ran_seed(sequence=nowi)
      call SIM_RN
      if(runbootstrap==1) nsearch=1
      if(runbootstrap==2) nsearch=5
      minf=10000000000.0_DP
      do xi=1,nsearch
        if(runbootstrap==1) then
          amoeba_pts(1,:)=pinit
        elseif(runbootstrap==2) then
          call ran1(runi)
          amoeba_pts(1,:)=pinit*(0.85_DP+0.30_DP*runi)
          where(amoeba_pts(1,:) < rangeN(:,1)) amoeba_pts(1,:) = rangeN(:,1)
          where(amoeba_pts(1,:) > rangeN(:,2)) amoeba_pts(1,:) = rangeN(:,2)
        endif
        amoeba_y(1)=OBJ_FUNC(amoeba_pts(1,:))
        open(unit=647, file='Bootstrap_init.dat', position='append')
        write(647,1239) seqno,dble(xi),amoeba_y(1), amoeba_pts(1,:); close(647)

        do ai=2,nest+1
          call ran1(runi)
          amoeba_pts(ai,:) = rangeN(:,1)+runi*(rangeN(:,2)- rangeN(:,1))
          amoeba_y(ai)=OBJ_FUNC(amoeba_pts(ai,:))
        end do
        call cpu_time(time_before)
        call EST_amoeba(amoeba_pts,amoeba_y,nest,tolf_amoeba,OBJ_FUNC,itmax_amoeba,iter_n)
        call sort_index(amoeba_y,pinda,1,nest+1)
        if(amoeba_y(pinda(1))<minf) THEN
          minf=amoeba_y(pinda(1))
          best_param=amoeba_pts(pinda(1),:)
        endif
        open(unit=547, file='Bootstrap_all_est.dat', position='append')
        write(547,1239) seqno,dble(xi),amoeba_y(pinda(1)), amoeba_pts(pinda(1),:); close(547)
      enddo
      call cpu_time(time_after)
      write(*,*) 'Amoeba completed in:  ',time_after-time_before,'  seconds.'
      write(*,*) 'Amoeba estimate objective value is ',minf
      write(*,*) 'Amoeba parameter values is ',best_param
      open(unit=747, file='Bootstrap.dat', position='append')
      write(747,1239) seqno, minf, best_param; close(747)
      call dfovec(nest,nmoments+1,best_param,verr)
      unw_verr(1:nmoments)=verr(1:nmoments)/weights; unw_verr(1+nmoments)=0.0_DP
      open(unit=847, file='Bootstrap_verr.dat', position='append')
      write(847,1239) seqno, verr; close(847)
      open(unit=947, file='Bootstrap_verr_unw.dat', position='append')
      write(947,1239) seqno, unw_verr; close(947)
    enddo

    call cpu_time(time_after)
    write(*,'(A 40,f18.5,A12)') 'Time for Boostrap:  ',time_after-time_before_boot,'  seconds.'
    stop
  endif

  IF (runcovar==1) THEN
     OPEN(73,file='param_diagnostic.dat') ; READ(73,*) pinit; CLOSE(73)
     !pinit=pguess
     DO i=1,nest
        WRITE(*,'(f15.5)') pinit(i)
     ENDDO
     CALL readmoments
     DO xi=1,num_covar
        WRITE(*,'(A 40,I5,A12)') 'Bootstrap SE for covariance, # ', xi
        fval=OBJ_FUNC(pinit)
        CALL AUTOCOVAR_MAT(covar_mat_level(xi,:,:),corr_mat_level(xi,:,:), &
             covar_mat_diff(xi,:,:),corr_mat_diff(xi,:,:),covar_diff10v1(xi,:,:), &
             corr_diff10v1(xi,:,:),covar_diff10v2(xi,:,:),corr_diff10v2(xi,:,:))
        CALL ran_seed(SEQUENCE=1776+xi)
        CALL SIM_RN
     ENDDO

     avg_covar_mat_level=SUM(covar_mat_level,dim=1)/DBLE(num_covar)
     avg_corr_mat_level=SUM(corr_mat_level,dim=1)/DBLE(num_covar)
     avg_covar_mat_diff=SUM(covar_mat_diff,dim=1)/DBLE(num_covar)
     avg_corr_mat_diff=SUM(corr_mat_diff,dim=1)/DBLE(num_covar)

     avg_covar_diff10v1=SUM(covar_diff10v1,dim=1)/DBLE(num_covar)
     avg_corr_diff10v1=SUM(corr_diff10v1,dim=1)/DBLE(num_covar)
     avg_covar_diff10v2=SUM(covar_diff10v2,dim=1)/DBLE(num_covar)
     avg_corr_diff10v2=SUM(corr_diff10v2,dim=1)/DBLE(num_covar)

     se_covar_mat_level=dsqrt(SUM(covar_mat_level**2,dim=1)/DBLE(num_covar)- &
                              avg_covar_mat_level**2)/dsqrt(DBLE(num_covar))
     se_corr_mat_level=dsqrt(SUM(corr_mat_level**2,dim=1)/DBLE(num_covar)- &
                              avg_corr_mat_level**2)/dsqrt(DBLE(num_covar))
     se_covar_mat_diff=dsqrt(SUM(covar_mat_diff**2,dim=1)/DBLE(num_covar)- &
                              avg_covar_mat_diff**2)/dsqrt(DBLE(num_covar))
     se_corr_mat_diff=dsqrt(SUM(corr_mat_diff**2,dim=1)/DBLE(num_covar)- &
                              avg_corr_mat_diff**2)/dsqrt(DBLE(num_covar))

      se_covar_diff10v1=dsqrt(SUM(covar_diff10v1**2,dim=1)/DBLE(num_covar)- &
                               avg_covar_diff10v1**2)/dsqrt(DBLE(num_covar))
      se_corr_diff10v1=dsqrt(SUM(corr_diff10v1**2,dim=1)/DBLE(num_covar)- &
                               avg_corr_diff10v1**2)/dsqrt(DBLE(num_covar))
     se_covar_diff10v2=dsqrt(SUM(covar_diff10v2**2,dim=1)/DBLE(num_covar)- &
                              avg_covar_diff10v2**2)/dsqrt(DBLE(num_covar))
     se_corr_diff10v2=dsqrt(SUM(corr_diff10v2**2,dim=1)/DBLE(num_covar)- &
                              avg_corr_diff10v2**2)/dsqrt(DBLE(num_covar))

     CALL WRITEMatrix(avg_covar_mat_level,Hmax,Hmax,'avg_covar_mat_level.csv')
     CALL WRITEMatrix(avg_corr_mat_level,Hmax,Hmax,'avg_corr_mat_level.csv')
     CALL WRITEMatrix(avg_covar_mat_diff,Hmax-1,Hmax-1,'avg_covar_mat_diff.csv')
     CALL WRITEMatrix(avg_corr_mat_diff,Hmax-1,Hmax-1,'avg_corr_mat_diff.csv')

     CALL WRITEMatrix(se_covar_mat_level,Hmax,Hmax,'se_covar_mat_level.csv')
     CALL WRITEMatrix(se_corr_mat_level,Hmax,Hmax,'se_corr_mat_level.csv')
     CALL WRITEMatrix(se_covar_mat_diff,Hmax-1,Hmax-1,'se_covar_mat_diff.csv')
     CALL WRITEMatrix(se_corr_mat_diff,Hmax-1,Hmax-1,'se_corr_mat_diff.csv')

     CALL WRITEMatrix(avg_covar_diff10v1,2,2,'avg_covar_diff10v1.csv')
     CALL WRITEMatrix(se_covar_diff10v1,2,2,'se_covar_diff10v1.csv')
     CALL WRITEMatrix(avg_corr_diff10v1,2,2,'avg_corr_diff10v1.csv')
     CALL WRITEMatrix(se_corr_diff10v1,2,2,'se_corr_diff10v1.csv')

     CALL WRITEMatrix(avg_covar_diff10v2,2,2,'avg_covar_diff10v2.csv')
     CALL WRITEMatrix(se_covar_diff10v2,2,2,'se_covar_diff10v2.csv')
     CALL WRITEMatrix(avg_corr_diff10v2,2,2,'avg_corr_diff10v2.csv')
     CALL WRITEMatrix(se_corr_diff10v2,2,2,'se_corr_diff10v2.csv')

     CALL write_3(covar_mat_level,'ALL_covar_mat_level.out')
     CALL write_3(corr_mat_level,'ALL_corr_mat_level.out')
     CALL write_3(covar_mat_diff,'ALL_covar_mat_diff.out')
     CALL write_3(corr_mat_diff,'ALL_corr_mat_diff.out')

     CALL CPU_TIME(time_after)
     WRITE(*,'(A 40,f18.5,A12)') 'Time for Diagnostic  ',time_after-time_before,'  seconds.'
     STOP
  ENDIF

  IF (plot_obj==1) THEN
263  FORMAT(999f40.20)
     CALL readmoments
     OPEN(unit=27, file='OBJ_plot.txt', STATUS='replace'); CLOSE(27)
     OPEN(73,file='param_diagnostic.dat') ; READ(73,*) pinit; CLOSE(73)
     !pinit=pguess
     DO i=1,nest
        WRITE(*,'(f15.5)') pinit(i)
     ENDDO
     fval=OBJ_FUNC(pinit)
     WRITE(*,'(A10,f18.8)') "obj= ", fval
     WRITE(*,*) " "
     OPEN(unit=27, file='OBJ_plot.txt', position='append')
     xi=1
     DO WHILE(xi<=nest)
        ptemp=pinit
        i=0
        IF(pinit(xi)>0) THEN
           lb_xi=MAX(0.50_DP*pinit(xi),param_bound(xi,1))
           ub_xi=MIN(1.50_DP*pinit(xi),param_bound(xi,2))
        ELSE
           lb_xi=MAX(1.50_DP*pinit(xi),param_bound(xi,1))
           ub_xi=MIN(0.50_DP*pinit(xi),param_bound(xi,2))
        ENDIF
        fval=OBJ_FUNC(ptemp)
        WRITE(*,'(2i5,A10,f18.8)') xi, i, "  obj= ", fval
        WRITE(27,263) DBLE(xi), ptemp(xi), fval
        DO WHILE(i<=nxi+1)
           i=i+1
           ptemp(xi)=lb_xi+DBLE(i-1)*(ub_xi-lb_xi)/DBLE(nxi)
           fval=OBJ_FUNC(ptemp)
           WRITE(*,'(2i5,A10,f18.8)') xi, i, "  obj= ", fval
           WRITE(27,263) DBLE(xi), ptemp(xi), fval
        ENDDO
        xi=xi+1
     ENDDO
     CLOSE(27)
     CALL CPU_TIME(time_after)
     WRITE(*,'(A 40,f18.5,A12)') 'Time for Objective Function Plot  ',time_after-time_before,'  seconds.'
     STOP
  ENDIF

179 FORMAT(2i3, 990f20.10)
219 FORMAT(999f40.20)

  initterm=1
  call_amoeba=1

  CALL readmoments
  OPEN(73,file='param_diagnostic.dat') ; READ(73,*) pinit; CLOSE(73)
  !pinit=pguess
  CALL itime(now)
  nowi=now(1)*60*60+now(2)*60+now(3)
  CALL ran_seed(SEQUENCE=nowi)
  CALL EST_DIV(initterm,call_amoeba,nstart,qr_ndraw,minlegit, &
       pinit,pstart,pest(:,1),pest(:,2:nest+1))
  IF(initterm==1) THEN
     CALL write2(REAL(pstart),'saved_pinit.dat')
     diagnostic=1
     CALL diagnostic_moments(pest(1,2:nest+1))
  ENDIF

  CALL CPU_TIME(time_after)
  WRITE(*,'(A 40,f18.5,A12)') 'Time for Estimation:  ',time_after-time_before,'  seconds.'
  STOP
END PROGRAM main

SUBROUTINE EST_DIV(initterm,call_amoeba,nstart,qr_ndraw,minlegit, &
     pinit,param_init,fval_saved,pest_saved)
  USE OBJECTIVE, ONLY :nest,nmoments,pguess,param_bound,param_range,OBJ_INIT,OBJ_FUNC, penalty0, penalty, penalty_indicator
  USE UTILITIES, ONLY: sort_index, iminloc, write2, myread2, mysleep, DP
  USE SOBOL_SEQUENCE, ONLY: insobl, I4_SOBOL
  USE myrandom, ONLY: ran1
  USE DFNLS, ONLY: BOBYQA_H
  IMPLICIT NONE
  INTERFACE
     SUBROUTINE EST_amoeba(p,y,ndim,ftol,func,ITMAX,iter)
       USE UTILITIES, ONLY : I4B,imaxloc,iminloc,nrerror, DP
       IMPLICIT NONE
       INTERFACE
          FUNCTION func(x)
            USE UTILITIES, ONLY: DP
            IMPLICIT NONE
            REAL(DP), DIMENSION(:), INTENT(IN) :: x
            REAL(DP) :: func
          END FUNCTION func
       END INTERFACE
       INTEGER(I4B), INTENT(OUT) :: iter
       REAL(DP), INTENT(IN) :: ftol
       INTEGER,  INTENT(IN) :: ITMAX
       INTEGER,  INTENT(IN) :: ndim
       REAL(DP), DIMENSION(ndim+1), INTENT(INOUT) :: y
       REAL(DP), DIMENSION(ndim+1,ndim), INTENT(INOUT) :: p
     END SUBROUTINE EST_amoeba
  END INTERFACE
  INTERFACE
     SUBROUTINE EST_dfpmin(p,gtol,iter,fret,func, nwrite,nwait,itmax)
       USE UTILITIES, ONLY : I4B,imaxloc,iminloc,nrerror, DP
       IMPLICIT NONE
       INTERFACE
          FUNCTION func(x)
            USE UTILITIES, ONLY: DP
            IMPLICIT NONE
            REAL(DP), DIMENSION(:), INTENT(IN) :: x
            REAL(DP) :: func
          END FUNCTION func
       END INTERFACE
       INTEGER(i4b), INTENT(OUT) :: iter
       REAL(DP), INTENT(IN) :: gtol
       REAL(DP), INTENT(OUT) :: fret
       REAL(DP), DIMENSION(:), INTENT(inout) :: p
       INTEGER,  INTENT(IN)::nwrite, nwait, itmax
     END SUBROUTINE EST_dfpmin
  END INTERFACE

  INTEGER,  INTENT(IN)  :: nstart,qr_ndraw,minlegit
  INTEGER,  INTENT(INOUT) :: initterm,call_amoeba
  REAL(DP), INTENT(IN)  :: pinit(nest)
  REAL(DP), INTENT(OUT) :: fval_saved(nstart), pest_saved(nstart,nest), param_init(nstart,nest)
  REAL(DP) :: fval_start(nstart) ! These arrays hold the selected initial parameters from Sobol Sequence and their corresponding objective value
  !REAL(DP) :: param_est(nstart,nest), fval_est(nstart) ! These arrays hold the estimated parameters for nstart starting points
  REAL(DP) :: param_start(nstart,nest) ! Selected points from Sobol sequence
  REAL(DP) :: qrdraw(nest),fvalest,parest(nest)
  REAL(DP), PARAMETER :: tolf_amoeba= 1.0d-4		! Amoeba variables
  INTEGER,  PARAMETER :: itmax_amoeba=4000		! Amoeba variables
  REAL(DP), PARAMETER :: share_case2=0.1_DP		! share of Amoeba runs that use case 2 vertices
  REAL(DP), PARAMETER :: dist_vertex=2.5_DP		! defines the size of the perturbation to obtain vertices for case 2
  REAL(DP) :: apts(nest+1,nest),afval(nest+1),runi(NEST),runii
  INTEGER  :: warm_start, seqno, pindx(qr_ndraw),pindy(2*nstart)
  INTEGER  :: d,i,k,j,seqnonew,seqN(nstart), iter_glob,i1,i2,i3,total_sobol_with_penalties
  INTEGER,  PARAMETER :: ninterppt = 2*nest+1
  REAL(DP), DIMENSION((ninterppt+5)*(ninterppt+nest)+3*nest*(nest+5)/2) :: wspace
  REAL(DP) :: w11,itratio, rangeN(nest,2)
  REAL(DP) :: temp_init(2*nstart,1+nest),temp(2*nstart,nest+3)
  INTEGER  :: pinds(5*qr_ndraw),ios, &
       numinit, iter_a, numlocalmin
  REAL(DP), PARAMETER :: gtol = 1.0d-06			! DFPMIN PARAMETER
  INTEGER,  PARAMETER :: itmax_DFPMIN = 100, nwait = 0, nwrite=1 ! DFPMIN PARAMETER
  REAL(DP), ALLOCATABLE :: sobolmat(:,:)
  REAL(DP)  :: switch_amoeba
  REAL(DP), PARAMETER :: prob_switch_amoeba=0.50_DP
  INTEGER  :: legitcoldstart=0

  REAL(DP), ALLOCATABLE :: param_sobol(:,:),fval_sobol(:)  ! These arrays hold all parameters from Sobol Sequence and their corresponding objective value


  !   =========================================================================
  !   ============================= MAIN PROGRAM STARTS =======================
  !   =========================================================================

  ALLOCATE(param_sobol(qr_ndraw,nest),fval_sobol(qr_ndraw))

  legitcoldstart=0

  ios=1
  DO WHILE(ios.NE.0)
     OPEN(32,file='initterm.txt',STATUS='old')
     READ(32,*,IOSTAT=ios) initterm
     IF(ios.NE.0) PRINT*,'read(32,*,IOSTAT=ios)', ios
     CLOSE(32)
  ENDDO

1453 CONTINUE
  IF(initterm==1) THEN
     initterm=0
     OPEN(32,file='initterm.txt', STATUS='replace'); WRITE(32,*) initterm; CLOSE(32)
     warm_start=0
     OPEN(unit=35, file='warm_start.txt', STATUS='replace'); WRITE(35,*) warm_start; CLOSE(35)
     seqno=1
     OPEN(unit=31, file='seqno.txt', STATUS='replace'); WRITE(31,*) seqno; CLOSE(31)
  ELSE
     OPEN(41,file='warm_start.txt') ; READ(41,*) warm_start ; CLOSE(41)
     !write(*,*) 'Warm Start if 1, Cold Start if 0: ', warm_start
     IF(warm_start==1) CALL mysleep(2.0_DP,' ')
     ios=1
     DO WHILE(ios.NE.0)
        OPEN(32,file='seqno.txt',STATUS='old')
        READ(32,*,IOSTAT=ios) seqno
        IF(ios.NE.0) PRINT*,'read(32,*,IOSTAT=ios)', ios
        CLOSE(32)
     ENDDO
     seqno=seqno+1;
     OPEN(33,file='seqno.txt', STATUS='replace'); WRITE(33,*) seqno; CLOSE(33)
  ENDIF

  IF (warm_start == 1) THEN
     IF(seqno==1) THEN
        OPEN(unit=47, file='saved_init.dat', STATUS='replace'); CLOSE(47)
        OPEN(unit=47, file='saved_pest.dat', STATUS='replace'); CLOSE(47)
        OPEN(unit=247, file='DFPMINlast.dat', STATUS='replace'); CLOSE(247)
     ELSEIF(seqno>nstart) THEN
        go to 1776
     ENDIF
     CALL myread2(temp_init,'saved_start.dat',numinit)
     OPEN(11,file='penalty.txt') ; READ(11,*) penalty ; CLOSE(11)
     OPEN(21,file='penalty0.txt') ; READ(21,*) penalty0 ; CLOSE(21)
     IF(numinit.NE.nstart) THEN
        PRINT*,"numinit.NE.nstart",numinit,nstart
        STOP
     ENDIF
     fval_start=temp_init(1:nstart,1)
     param_start=temp_init(1:nstart,2:nest+1)
     iter_glob=0
     WRITE(*,*) 'Starting sequence # is ', seqno, ' out of ', nstart, ' warm start runs'
     CALL myread2(temp,'saved_pest.dat',iter_glob)
     WRITE(*,*) 'THERE ARE ', iter_glob, 'PREVIOUSLY RECORDED ESTIMATED PARAMETER COMBINATIONS'
     IF (DBLE(iter_glob)/DBLE(nstart)>=0.4_DP) THEN
        CALL ran1(switch_amoeba)
        IF (switch_amoeba<=prob_switch_amoeba) THEN
           call_amoeba=0
        ENDIF
     ENDIF
     IF(iter_glob>=1) THEN
        w11=MIN(MAX(0.10_DP, (dsqrt(DBLE(iter_glob+40)/DBLE(nstart)))),0.95_DP)
        CALL sort_index(DBLE(temp(1:iter_glob,3)),pindy(1:iter_glob),1,iter_glob)
277     FORMAT(i3,990f15.8)
278     FORMAT(i5,i4,990f15.8)
        WRITE(*,*) 'Best parameter values so far is:'
        WRITE(*,278) INT(temp(pindy(1),1:2)), temp(pindy(1),3:nest+3)
        param_init(seqno,:)= w11*temp(pindy(1),4:nest+3)+(1.0_DP-w11)*param_start(seqno,:)
     ELSE
        param_init(seqno,:)=param_start(seqno,:)
     ENDIF
239  FORMAT(i6, 990f20.10)
240  FORMAT(2i6, 990f20.10)
     OPEN(unit=17, file='saved_init.dat', position='append'); WRITE(17,239) seqno, param_init(seqno,:); CLOSE(17)

     IF(call_amoeba==1) THEN
        IF(iter_glob>=MAX(FLOOR(REAL(nstart/2)),21)) THEN
           DO i=1,nest
              rangeN(i,1)=MINVAL(temp(pindy(2:21),i+3))
              rangeN(i,2)=MAXVAL(temp(pindy(2:21),i+3))
              IF(rangeN(i,2)<=rangeN(i,1)) THEN
                 rangeN(i,:)=param_bound(i,:)
              ENDIF
           ENDDO
           w11=MIN(0.995_DP,(DBLE(iter_glob+100)/DBLE(MAX(nstart+100,200)))**(1.0_DP/3.0_DP))
           rangeN=w11*rangeN+(1.0_DP-w11)*param_bound
        ELSE
           rangeN=param_bound
        ENDIF
        apts(1,:)=param_init(seqno,:)
        DO i=2,nest+1
          CALL ran1(runi)
          apts(i,:) = rangeN(:,1)+runi*(rangeN(:,2)- rangeN(:,1))
        END DO

        CALL RUN_AMEOBA(apts,tolf_amoeba,itmax_amoeba,afval)
        parest=apts(1,:)
        fvalest=afval(1)
     ELSEIF (call_amoeba ==2) THEN
        parest=param_init(seqno,:)
        CALL EST_dfpmin(parest,gtol,iter_a,fvalest,OBJ_FUNC,nwrite,nwait,itmax_DFPMIN)
     ELSE
        parest=param_init(seqno,:)
        itratio=MIN(1.0_DP,DBLE(iter_glob)/DBLE(nstart))
        CALL RUN_BOBYQA(parest,itratio,fvalest)
     ENDIF

     CALL myread2(temp,'saved_pest.dat',iter_glob)
     IF(iter_glob>=1) THEN
        CALL sort_index(DBLE(temp(1:iter_glob,3)),pindy(1:iter_glob),1,iter_glob)
        IF(fvalest<temp(pindy(1),3)) THEN
           numlocalmin=INT(temp(iter_glob,2))+1
        ELSE
           numlocalmin=INT(temp(iter_glob,2))
        ENDIF
     ELSE
        numlocalmin=1
     ENDIF
     OPEN(unit=19, file='saved_pest.dat', position='append')
     WRITE(19,240) seqno, numlocalmin, fvalest, parest; CLOSE(19)
     ios=1
     DO WHILE(ios.NE.0)
        OPEN(34,file='seqno.txt',STATUS='old')
        READ(34,*,IOSTAT=ios) seqnonew
        IF(ios.NE.0) PRINT*,'read(34,*,IOSTAT=ios)', ios
        CLOSE(34)
     ENDDO
     IF(seqno<=nstart-1) THEN
        go to 1453
     ENDIF
     !! Completing the estimation..
1776 CONTINUE
     CALL myread2(temp,'saved_pest.dat',iter_glob)
     initterm=1
     CALL myread2(temp_init,'saved_init.dat',numinit)
     CALL sort_index(DBLE(temp(1:iter_glob,3)),pindy(1:iter_glob),1,iter_glob)
     seqno=INT(temp(pindy(1),1))
     WRITE(*,*) 'Best estimation so far:'
     WRITE(*,278) seqno,INT(temp(pindy(1),2)), temp(pindy(1),3:3+nest)
     PRINT*, 'Improving the best solution..'
     parest=temp(pindy(1),4:3+nest)
     CALL EST_dfpmin(parest,gtol,iter_a, fvalest,OBJ_FUNC,nwrite,nwait,itmax_DFPMIN)
     temp(pindy(1),3)=fvalest
     temp(pindy(1),4:nest+3)=parest
     WRITE(*,*) 'Estimated parameter values (FINAL):'
     WRITE(*,277) seqno, fvalest, parest
     OPEN(unit=219, file='DFPMINlast.dat', position='append')
     WRITE(219,239) seqno, fvalest, parest; CLOSE(219)
     CALL write2(temp(1:iter_glob,:),'unsorted_final_soln.dat')
     DO j=1,nest+3
        temp(1:iter_glob,j)=temp(pindy(1:iter_glob),j)
     ENDDO
     CALL write2(temp(1:iter_glob,:),'sorted_final_soln.dat')
     CALL write2(param_start,'unsorted_param_start.dat')
     CALL write2(temp_init(1:numinit,:),'unsorted_param_init.dat')
     DO j=1,numinit
        param_init(INT(temp_init(j,1)),1:nest)=temp_init(j,2:nest+1)
     ENDDO
     IF(iter_glob>=nstart) THEN
        seqN(:)=INT(temp(1:nstart,1))
        fval_saved(:)=temp(1:nstart,3)
        DO j=1,nest
           pest_saved(:,j)=temp(1:nstart,3+j)
           param_start(:,j)=param_start(seqN,j)
           param_init(:,j)=param_init(seqN,j)
        ENDDO
     ELSE
        seqN(1:iter_glob)=INT(temp(1:iter_glob,1))
        seqN(1+iter_glob:nstart)=0
        fval_saved(1:iter_glob)=temp(1:iter_glob,3)
        fval_saved(1+iter_glob:nstart)=0.0_DP
        DO j=1,nest
           pest_saved(1:iter_glob,j)=temp(1:iter_glob,3+j)
           pest_saved(1+iter_glob:nstart,j)=0.0_DP
           param_start(1:iter_glob,j)=param_start(seqN(1:iter_glob),j)
           param_start(1+iter_glob:nstart,j)=0.0_DP
           param_init(1:iter_glob,j)=param_init(seqN(1:iter_glob),j)
           param_init(1+iter_glob:nstart,j)=0.0_DP
        ENDDO
     ENDIF
     CALL write2(REAL(param_start),'sorted_param_start.dat')
     CALL write2(REAL(param_init),'sorted_param_init.dat')
     RETURN
  ELSEIF (warm_start .NE. 1) THEN 	! SELECTING DESIRABLE STARTING POINTS.

     IF (seqno==1) THEN 				! Generating the initial points from Sobol Sequence
        ! Replace the existing 'saved_sobol.dat', 'saved_start.dat' and 'penalties_during_sobol.dat'
        OPEN(unit=43,  file='saved_sobol.dat', STATUS='replace'); CLOSE(43)
        OPEN(unit=47,  file='saved_start.dat', STATUS='replace'); CLOSE(47)
        OPEN(unit=131, file='penalties_during_sobol.dat', STATUS='replace')
        WRITE(131,'(I12,I12,I12)') 0, 0, 0
        CLOSE(131)

        CALL insobl(nest,qr_ndraw)
        DO d = 1,qr_ndraw
           CALL I4_SOBOL(nest,qrdraw)
           param_sobol(d,1:nest) = param_range(1:nest,1)+qrdraw(1:nest)*(param_range(1:nest,2)-param_range(1:nest,1))
        ENDDO
        CALL write2(REAL(param_sobol),'param_sobol.dat')
     ELSEIF(seqno>qr_ndraw .OR. legitcoldstart>minlegit) THEN
        CALL mysleep(DBLE(10+MOD(seqno,10)*5),'All cold start runs have been executed by other terminals!')
        initterm=0
        go to 1453
     ELSE
        CALL myread2(param_sobol,'param_sobol.dat',d)
     ENDIF
     DO WHILE (seqno<=qr_ndraw .AND. legitcoldstart<minlegit)
        WRITE(*,'(A15,I7,A9,I7,A17)') 'Sequence # is ', seqno, '  out of ', qr_ndraw, '  cold start runs'
        fval_sobol(seqno)=OBJ_FUNC(param_sobol(seqno,:))
        OPEN(unit=43, file='saved_sobol.dat', position='append')
        WRITE(43,269) fval_sobol(seqno), param_sobol(seqno,:)
269     FORMAT(999f40.20)
        CLOSE(43)

        ios=1
        DO WHILE(ios.NE.0)
           OPEN(unit=131, file='penalties_during_sobol.dat', position='append')
           REWIND(unit=131)
           READ(131,*,IOSTAT=ios) i1,i2,i3
           IF(ios.NE.0) PRINT*,'read(32,*,IOSTAT=ios)', ios
           CLOSE(131)
        ENDDO
        total_sobol_with_penalties = i2+penalty_indicator
        legitcoldstart=i3+(1-penalty_indicator)
        OPEN(unit=131, file='penalties_during_sobol.dat', status='replace')
        WRITE(131,'(3I12)') seqno,total_sobol_with_penalties,legitcoldstart; CLOSE(131)
        WRITE(*,'(A25,4I12)') ' # penalties, legits: ',  &
             seqno,total_sobol_with_penalties,legitcoldstart,penalty_indicator

        IF(legitcoldstart>minlegit) THEN
           CALL mysleep(DBLE(10+MOD(seqno,10)*5),'Please wait! Program will start with warm option.')
           initterm=0
           go to 1453
        ENDIF
        ios=1
        DO WHILE(ios.NE.0)
           OPEN(36,file='seqno.txt',STATUS='old')
           READ(36,*,IOSTAT=ios) seqnonew
           IF(ios.NE.0) PRINT*,'read(36,*,IOSTAT=ios)', ios
           CLOSE(36)
        ENDDO
        seqnonew=seqnonew+1;
        OPEN(35,file='seqno.txt',STATUS='replace'); WRITE(35,*) seqnonew; CLOSE(35)
        IF(seqnonew < seqno) THEN
           initterm=0
           go to 1453
        ELSEIF(seqnonew>qr_ndraw .AND. seqno<qr_ndraw) THEN
           CALL mysleep(DBLE(10+MOD(seqno,10)*5),'Please wait! Program will start with warm option.')
           initterm=0
           go to 1453
        ENDIF
        seqno=seqnonew
     ENDDO
     DEALLOCATE(param_sobol,fval_sobol)
     ALLOCATE(sobolmat(5*qr_ndraw,nest+1))
     CALL myread2(sobolmat,'saved_sobol.dat',k)
     PRINT*,k, ' out of ', qr_ndraw
     CALL sort_index(sobolmat(1:k,1),pinds(1:k),1,k)
     ! The first initial parameter values is the initial guess defined by the user in objective module.
     param_start(1,:) = pinit(:)
     fval_start(1) = OBJ_FUNC(param_start(1,:))
     param_start(2,:) = sobolmat(pinds(1),2:nest+1)
     fval_start(2) = sobolmat(pinds(1),1)
     j=3
     DO i=2,k
        IF(sobolmat(pinds(i),1)>sobolmat(pinds(i-1),1)) THEN
           param_start(j,:)=sobolmat(pinds(i),2:nest+1)
           fval_start(j)=sobolmat(pinds(i),1)
           IF(j==INT(nstart/2)) THEN
              penalty=5*fval_start(j)
              penalty0=5*fval_start(j)
           ENDIF
           j=j+1
        ENDIF
        IF(j>nstart) EXIT
     END DO
     DEALLOCATE(sobolmat)
     OPEN(unit=47, file='saved_start.dat', STATUS='replace'); CLOSE(47)
     OPEN(unit=47, file='saved_start.dat', position='append')
     DO i=1,nstart
        WRITE(47,269) fval_start(i), param_start(i,:)
     ENDDO
     CLOSE(47)
     OPEN(unit=17,file='penalty.txt',STATUS='replace'); WRITE(17,269) penalty; CLOSE(17)
     OPEN(unit=27,file='penalty0.txt',STATUS='replace'); WRITE(27,269) penalty0; CLOSE(27)
     WRITE(*,332)  MINVAL(fval_start), MAXVAL(fval_start)
     WRITE(*,333)  penalty

332  FORMAT('min and max of fval of chosen points: ',11F20.10)
333  FORMAT('Penalty in the objective function: ',11F20.10)
334  FORMAT('Chosen points', 10F12.6)
     !Prepare the program for the Warm Start
     initterm=0
     warm_start=1;
     OPEN(41,file='warm_start.txt',status='replace'); WRITE(41,*) warm_start; CLOSE(41)
     seqno=0; OPEN(37, file='seqno.txt', STATUS='replace'); WRITE(37,*) seqno; CLOSE(37)
     go to 1453
  ENDIF
  STOP
  !=======================================================================

CONTAINS

  SUBROUTINE RUN_AMEOBA(amoeba_pts,tolf,itmax,amoeba_y)
    IMPLICIT NONE
    REAL(DP), INTENT(IN) :: tolf
    INTEGER, INTENT(IN) :: itmax
    REAL(DP), INTENT(inout) :: amoeba_pts(nest+1,nest),amoeba_y(nest+1)
    REAL(DP) :: time_after,time_before
    INTEGER :: iter_a,ia,pinda(nest+1)
    PRINT*,'amoeba is running'

    DO ia=1,nest+1
       amoeba_y(ia)=OBJ_FUNC(amoeba_pts(ia,:))
    END DO
    CALL CPU_TIME(time_before)
    CALL EST_amoeba(amoeba_pts,amoeba_y,nest,tolf,OBJ_FUNC,itmax,iter_a)
    CALL sort_index(amoeba_y,pinda,1,nest+1)
    amoeba_y=amoeba_y(pinda)
    amoeba_pts(:,:)=amoeba_pts(pinda,:)
    CALL CPU_TIME(time_after)
    WRITE(*,*) 'Amoeba completed in:  ',time_after-time_before,'  seconds.'
    WRITE(*,*) 'Amoeba estimate objective value is ',amoeba_y(1)
  END SUBROUTINE RUN_AMEOBA

  !=======================================================================

  SUBROUTINE RUN_BOBYQA(param_bobyqa,itratio,fval_bobyqa)
    IMPLICIT NONE
    REAL(DP), INTENT(inout) :: param_bobyqa(nest)
    REAL(DP), INTENT(IN) :: itratio
    REAL(DP), INTENT(OUT) :: fval_bobyqa
    INTEGER :: iprint=2, maxeval
    REAL(DP) :: rhobeg,rhoend,time_after,time_before

    PRINT*,'BOBYQA is running'
    IF (itratio>0.5) THEN
       rhobeg	= (MINVAL(param_bound(:,2)-param_bound(:,1))/2.50_DP)/(4.0_DP*itratio)
       rhoend  = 1.0D-3/(4.0_DP*itratio)
    ELSE
       rhobeg	= MINVAL(param_bound(:,2)-param_bound(:,1))/2.50_DP
       rhoend  = 1.0D-3
    ENDIF
    WRITE(*,*) 'Rhobeg and Rhoend are', Rhobeg, Rhoend
    maxeval = 40*(nest+1) ! max number of gradient evaluations
    CALL CPU_TIME(time_before)
    !CALLING THE MAIN MINIMIZATION ROUTINE (DERIVATIVE-FREE NON-LINEAR LEAST SQUARES)
    CALL bobyqa_h(nest,ninterppt,param_bobyqa,param_bound(:,1),param_bound(:,2), &
         rhobeg,rhoend,iprint,maxeval,wspace,nmoments+1)
    fval_bobyqa=OBJ_FUNC(param_bobyqa)
    CALL CPU_TIME(time_after)
    WRITE(*,*) 'BOBYQA completed in:  ',time_after-time_before,'  seconds.'
    WRITE(*,*) 'BOBYQA estimate objective value is ',fval_bobyqa
  END SUBROUTINE RUN_BOBYQA
END SUBROUTINE EST_DIV

!================================================================================
!   EST_amoeba ROUTINE
!===================================================================
SUBROUTINE EST_amoeba(p,y,ndim,ftol,func,ITMAX,iter)
  USE UTILITIES, ONLY : I4B,imaxloc,iminloc,nrerror_continue,swap,DP
  IMPLICIT NONE
  INTERFACE
     FUNCTION func(x)
       USE UTILITIES, ONLY: DP
       IMPLICIT NONE
       REAL(DP), DIMENSION(:), INTENT(IN) :: x
       REAL(DP) :: func
     END FUNCTION func
  END INTERFACE
  INTEGER(I4B), INTENT(OUT) :: iter
  REAL(DP), INTENT(IN) :: ftol
  INTEGER, INTENT(IN) :: ITMAX
  INTEGER, INTENT(IN) :: ndim
  REAL(DP), DIMENSION(ndim+1), INTENT(INOUT) :: y
  REAL(DP), DIMENSION(ndim+1,ndim), INTENT(INOUT) :: p

  REAL(DP), PARAMETER :: TINY=1.0e-10
  INTEGER(I4B) :: ihi
  REAL(DP), DIMENSION(SIZE(p,2)) :: psum


  CALL amoeba_private
CONTAINS
  !BL
  SUBROUTINE amoeba_private
    IMPLICIT NONE
    INTEGER(I4B) :: i,ilo,inhi,j
    REAL(DP) :: rtol,ysave,ytry,ytmp
    REAL(DP), DIMENSION(ndim):: pmin, pmax
    REAL(DP), DIMENSION(ndim+1):: temp
    iter=0
    psum(:)=SUM(p(:,:),dim=1)
    DO
       ilo=iminloc(y(:))
       ihi=imaxloc(y(:))
       ytmp=y(ihi)
       y(ihi)=y(ilo)
       inhi=imaxloc(y(:))
       y(ihi)=ytmp
       rtol=2.0_DP*dabs(y(ihi)-y(ilo))/(dabs(y(ihi))+dabs(y(ilo))+TINY)
       IF (rtol < ftol) THEN
          CALL swap(y(1),y(ilo))
          CALL swap(p(1,:),p(ilo,:))
          RETURN
       END IF
       !     157 format('iter, y(ihi), y(ilo) ' i4 , 2F20.12)
       !     if(mod(iter,10)==0) write(*,157) iter, y(ihi), y(ilo)

       IF (MOD(iter,100)==0) THEN
          WRITE (*,*) 'in ameoba,  iteration =', iter
100       FORMAT(i2,2i10,5i12)
          WRITE(*,*)     'ya(ilo)     ya(ihi)      rtol'
          WRITE(6,101) y(ilo),y(ihi),rtol
101       FORMAT(3f10.6)
          DO 50 i = 1,ndim
             DO 51 j = 1,ndim+1
                temp(j) = p(j,i)
51           END DO
             !   temp(4)=100.0_DP*dsqrt(temp(4))
             !   temp(5)=100.0_DP*dsqrt(temp(5))
             pmax(i) = MAXVAL(temp)
             pmin(i) = MINVAL(temp)
50        END DO

          WRITE(6,102) (p(ilo,i),i=1,ndim)
102       FORMAT(13f9.5)
          WRITE(6,102) (pmax(i),i=1,ndim)
          WRITE(6,102) (pmin(i),i=1,ndim)
          WRITE(*,*) "======================================================"
121       FORMAT("======================================================")
       ENDIF
       IF (iter >= ITMAX) THEN
          PRINT*,'ITMAX exceeded in amoeba'
          RETURN
       ENDIF

       ytry=amotry(-1.0_DP)
       iter=iter+1
       IF (ytry <= y(ilo)) THEN
          ytry=amotry(2.0_DP)
          iter=iter+1
       ELSE IF (ytry >= y(inhi)) THEN
          ysave=y(ihi)
          ytry=amotry(0.5_DP)
          iter=iter+1
          IF (ytry >= ysave) THEN
             p(:,:)=0.5_DP*(p(:,:)+SPREAD(p(ilo,:),1,SIZE(p,1)))
             DO i=1,ndim+1
                IF (i /= ilo) y(i)=func(p(i,:))
             END DO
             iter=iter+ndim
             psum(:)=SUM(p(:,:),dim=1)
          END IF
       END IF
    END DO
  END SUBROUTINE amoeba_private
  !BL
  FUNCTION amotry(fac)
    IMPLICIT NONE
    REAL(DP), INTENT(IN) :: fac
    REAL(DP) :: amotry
    REAL(DP) :: fac1,fac2,ytry
    REAL(DP), DIMENSION(SIZE(p,2)) :: ptry
    fac1=(1.0_DP-fac)/ndim
    fac2=fac1-fac
    ptry(:)=psum(:)*fac1-p(ihi,:)*fac2
    ytry=func(ptry)
    IF (ytry < y(ihi)) THEN
       y(ihi)=ytry
       psum(:)=psum(:)-p(ihi,:)+ptry(:)
       p(ihi,:)=ptry(:)
    END IF
    amotry=ytry
  END FUNCTION amotry
END SUBROUTINE EST_amoeba

!=======================================================================


!=======================================================================

SUBROUTINE EST_dfpmin(p, gtol,iter,fret,func, nwrite,nwait,itmax)
  USE UTILITIES, ONLY : I4B,lgt,imaxloc,iminloc,DP, outerprod

  !   use nr, only : lnsrch
  IMPLICIT NONE
  INTEGER(i4b), INTENT(OUT) :: iter
  REAL(dp), INTENT(IN) :: gtol
  REAL(dp), INTENT(OUT) :: fret
  REAL(dp), DIMENSION(:), INTENT(inout) :: p
  INTEGER, INTENT(IN)::nwrite, nwait, itmax
  INTERFACE
     FUNCTION func(x)
       USE UTILITIES, ONLY: DP
       IMPLICIT NONE
       REAL(DP), DIMENSION(:), INTENT(IN) :: x
       REAL(DP) :: func
     END FUNCTION func
  END INTERFACE
  INTERFACE
     SUBROUTINE lnsrch(func,xold,fold,g,p,x,f,stpmax,check,nest)
       USE UTILITIES, ONLY : I4B, DP, LGT, assert_eq

       INTEGER(i4B), INTENT(IN):: nest
       REAL(DP), DIMENSION(:), INTENT(IN) :: xold,g
       REAL(DP), DIMENSION(:), INTENT(INOUT) :: p
       REAL(DP), INTENT(IN) :: fold,stpmax
       REAL(DP), DIMENSION(:), INTENT(OUT) :: x
       REAL(DP), INTENT(OUT) :: f
       LOGICAL(LGT), INTENT(OUT) :: check
       INTERFACE
          FUNCTION func(xx)
            USE UTILITIES, ONLY: DP
            REAL(DP) :: func
            REAL(DP), DIMENSION(:), INTENT(IN) :: xx
          END FUNCTION func
       END INTERFACE
     END SUBROUTINE lnsrch
  END INTERFACE

  REAL(dp), PARAMETER :: stpmx=100.0_dp,eps=EPSILON(p),tolx=4.0_dp*eps, xinc=1.0D-05
  INTEGER(i4b) :: its,i,k,nn
  LOGICAL(lgt) :: check
  REAL(dp) :: den,fac,fad,fae,fp,stpmax,sumdg,sumxi, se1avg, se2avg,coravg,se1obs,se2obs,corobs
  REAL(dp), DIMENSION(SIZE(p)) :: dg,g,hdg,pnew,xi
  REAL(dp), DIMENSION(SIZE(p),SIZE(p)) :: hessin


  !==================================start here ======================
  WRITE(*,*) 'dfpmin is running..'
498 FORMAT(1i6,f20.10)
332 FORMAT(1i6,20f20.10)
  nn=SIZE(p)
  fp=func(p)
  g=dograd(p,xinc,func)
  !  write(*,*) 'after dograd is:',g

  IF (nwrite == 1) THEN
     its = 0
     WRITE(6,498) its,fp
     WRITE(6,332) its,(p(i),i=1,nn)
     WRITE(6,332) its,(g(i),i=1,nn)
     IF (nwait == 1) PAUSE
  ENDIF

  !  pause
  hessin=0.0_DP
  DO i=1,nn
     hessin(i,i)=1.0_dp
  END DO

  xi=-g
  stpmax=stpmx*MAX(dsqrt(DOT_PRODUCT(p,p)),DBLE(SIZE(p)))
  DO its=1,itmax
     iter=its
     ! write (*,*) 'just before lnsrch'
     ! write(*,*) size(p), size(g),nn
     CALL lnsrch(func,p,   fp,  g,xi,pnew,fret,stpmax,check,nn)
     fp=fret
     xi=pnew-p
     p=pnew
     IF (MAXVAL(dabs(xi)/MAX(dabs(p),1.0_dp)) < tolx) RETURN
     dg=g
     g=dograd(p,xinc,func)
     den=MAX(fret,1.0_dp)
     IF (MAXVAL(dabs(g)*MAX(dabs(p),1.0_dp)/den) < gtol) RETURN
     dg=g-dg
     hdg=MATMUL(hessin,dg)
     fac=DOT_PRODUCT(dg,xi)
     fae=DOT_PRODUCT(dg,hdg)
     sumdg=DOT_PRODUCT(dg,dg)
     sumxi=DOT_PRODUCT(xi,xi)
     IF (fac > dsqrt(eps*sumdg*sumxi)) THEN
        fac=1.0_dp/fac
        fad=1.0_dp/fae
        dg=fac*xi-fad*hdg
        hessin=hessin+fac*outerprod(xi,xi)-&
             fad*outerprod(hdg,hdg)+fae*outerprod(dg,dg)
     END IF

     IF (nwrite == 1 .AND. MOD(its,5)==0) THEN
        WRITE(6,498) its,fp
        WRITE(6,332) its,(p(i),i=1,nn)
        WRITE(6,332) its,(g(i),i=1,nn)

        IF (nwait == 1) PAUSE
     ENDIF

     xi=-MATMUL(hessin,g)
  END DO

CONTAINS

  FUNCTION dograd(x,xinc,func)
    REAL(dp), DIMENSION(:), INTENT(IN):: x
    REAL(dp), DIMENSION(SIZE(x)):: dograd
    REAL(dp), INTENT(IN):: xinc
    INTERFACE
       FUNCTION func(x)
         USE UTILITIES, ONLY: DP
         IMPLICIT NONE
         REAL(DP), DIMENSION(:), INTENT(IN) :: x
         REAL(DP) :: func
       END FUNCTION func
    END INTERFACE

    INTEGER, PARAMETER:: nmax=100
    INTEGER:: n,i,j
    REAL(dp), DIMENSION(SIZE(x)):: dh,  yy, grad
    REAL(dp), DIMENSION(SIZE(x),SIZE(x)):: ee
    REAL(dp):: tempf2, tempf1, tolera

    n=SIZE(x)
    !	    write (*,*) 'inside dograd', n,x
    tolera=10.0_dp*xinc

    IF (n .GT. nmax) PAUSE 'nmax exceeded in dograd'
    DO i = 1,n
       IF (dabs(x(i)) >= tolera) THEN
          dh(i) = x(i)*xinc
       ELSE
          dh(i) = xinc
       ENDIF
    END DO

    ee(1:n,1:n)= 0.0_dp
    DO i = 1,n
       ee(i,i) = dh(i)
    END DO


    DO i = 1,n
       DO j = 1,n
          yy(j) = x(j) - ee(i,j)
       END DO
       tempf1 = func(yy)
       !            write (*,*) 'inside dograd, yy1', yy, tempf1
       DO j = 1,n
          yy(j) = x(j) + ee(i,j)
       END DO
       tempf2 = func(yy)
       grad(i) = (tempf2-tempf1)/(2.0d+00*dh(i))
       !   	     write (*,*) 'inside dograd, n, x', n,x, yy
       !		     write (*,*) 'inside dograd, yy2', yy, tempf2
    END DO

    dograd=grad
    RETURN
  END FUNCTION dograd

END SUBROUTINE EST_dfpmin

!========================================================================
SUBROUTINE lnsrch(func,xold,fold,g,pdir,x,f,stpmax,check,nest)
  USE UTILITIES, ONLY : I4B, DP, LGT, assert_eq

  IMPLICIT NONE
  INTERFACE
     FUNCTION func(xx)
       USE UTILITIES, ONLY: DP
       IMPLICIT NONE
       REAL(DP), DIMENSION(:), INTENT(IN) :: xx
       REAL(DP) :: func
     END FUNCTION func
  END INTERFACE
  INTEGER(i4B), INTENT(IN):: nest
  REAL(dp), DIMENSION(:), INTENT(IN) :: xold,g
  REAL(dp), DIMENSION(:), INTENT(inout) :: pdir
  REAL(dp), INTENT(IN) :: fold,stpmax
  REAL(dp), DIMENSION(:), INTENT(OUT) :: x
  REAL(dp), INTENT(OUT) :: f
  LOGICAL(lgt), INTENT(OUT) :: check


  REAL(dp), PARAMETER :: alf=1.0e-4_dp,tolx=EPSILON(x)
  INTEGER(i4b) :: ndum
  REAL(dp) :: a,alam,alam2,alamin,b,disc,f2,pabs,rhs1,rhs2,slope,tmplam
  !    write(*,*)'inside linesearch', nest
  !    write(*,*) size(g), size(pdir),  size(xold)
  !    write(*,*)'poin1'
  !
  !  	write(*,*) xold
  !    write(*,*)'point2'
  !	write(*,*) pdir
  !    write(*,*)'point3'
  !    write(*,*) g
  !  	332 format(8f15.8)

  !   ndum=assert_eq((/size(g),size(pdir),size(x),size(xold)/),'lnsrch')
  ndum=nest
  check=.FALSE.
  pabs=dsqrt(DOT_PRODUCT(pdir(:),pdir(:)))
  IF (pabs > stpmax) pdir(:)=pdir(:)*stpmax/pabs
  slope=DOT_PRODUCT(g,pdir)
  IF (slope >= 0.0) THEN
     WRITE (*,*) 'roundoff problem in lnsrch.. quitting'
     RETURN
  ENDIF

  alamin=tolx/MAXVAL(dabs(pdir(:))/MAX(dabs(xold(:)),1.0_dp))
  alam=1.0_DP
  !    write(*,*) 'alamin is',alamin
  !    write(*,*) 'alam is', alam

  DO
     x(:)=xold(:)+alam*pdir(:)
     !        write(*,*) 'x is'
     !		write(*,332)  x
     !		write(*,*) 'pdir is'
     !		write(*,332)  pdir
     !		write(*,*) 'xold is'
     !		write(*,332)  xold

     f=func(x)
     IF (alam < alamin) THEN
        x(:)=xold(:)
        check=.TRUE.
        RETURN
     ELSE IF (f <= fold+alf*alam*slope) THEN
        RETURN
     ELSE
        IF (alam == 1.0) THEN
           tmplam=-slope/(2.0_dp*(f-fold-slope))
        ELSE
           rhs1=f-fold-alam*slope
           rhs2=f2-fold-alam2*slope
           a=(rhs1/alam**2-rhs2/alam2**2)/(alam-alam2)
           b=(-alam2*rhs1/alam**2+alam*rhs2/alam2**2)/&
                (alam-alam2)
           IF (a == 0.0) THEN
              tmplam=-slope/(2.0_dp*b)
           ELSE
              disc=b*b-3.0_dp*a*slope
              IF (disc < 0.0) THEN
                 tmplam=0.5_dp*alam
              ELSE IF (b <= 0.0) THEN
                 tmplam=(-b+dsqrt(disc))/(3.0_dp*a)
              ELSE
                 tmplam=-slope/(b+dsqrt(disc))
              END IF
           END IF
           IF (tmplam > 0.5_dp*alam) tmplam=0.5_dp*alam
        END IF
     END IF
     alam2=alam
     f2=f
     alam=MAX(tmplam,0.1_dp*alam)
  END DO
END SUBROUTINE lnsrch
