# Makefile to build mpi class examples
# -1-- macros
#FC = $(F90)
FC = ifort

#--
# increasing the stacksize tio see if problem could be fixed
#--
MYFLAGS = -heap-arrays

#--
#trying to isolate the fault with a stack traceback
#---
#OPT = -O3 -g -traceback -check all -fp-stack-check
#OPT = -O3 -g -traceback -fp-stack-check
#OPT = -O3 -fp-stack-check
OPT = -O3 -ipo -check bounds
#OPT = -O3 -ipo

#----
F90CFLAGS = $(MYFLAGS) $(OPT)
#F90CFLAGS = $(OPT)
F90LFLAGS = $(OPT)

EXE_SH = estimate.exe_sh

#----------
# -2- objects
#     List files from least USE to most USE
objects = utilities.o OBJECTIVE.o DFNLS.o ESTIMATE.o

#--------------------------------------------
# -3- Define how to create the exe file
#--------------------------------------------
all: $(EXE_SH)

$(EXE_SH) : $(objects)
	@echo ""
	@echo "   LINKING to Create $@  ..."
	$(FC) $(F90LFLAGS) -o $@ $(objects)
	@echo ""
	@echo " -- Executable $@ created --"
	@echo ""

#--------------------------------------------
# -4- Define how create the .o files required
#     by the .exe file
#
#--------------------------------------------
utilities.o: utilities.F90
	$(FC) -c $(F90CFLAGS) $<

OBJECTIVE.o: OBJECTIVE.f90
	$(FC) -c $(F90CFLAGS) $<

DFNLS.o: DFNLS.f90
	$(FC) -c $(F90CFLAGS) $<

ESTIMATE.o:  ESTIMATE.f90
	$(FC) -c $(F90CFLAGS) $<

#---------------------------------------------
# -5- Define how to clean up the .o and .exe files
#     if you wish to build .exe from scratch
#---------------------------------------------
clean:
	 @echo "        Cleaning UP executable and object files ..."
	 \rm -f *.o *.mod $(objects) $(EXE_SH)
