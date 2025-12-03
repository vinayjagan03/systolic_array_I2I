###############################################################
# XCELIUM MAKEFILE
###############################################################

# Default design
DESIGN ?= top
TOP     = tb_$(DESIGN)

# Paths
RTL     = ../src/modules/*.sv
TB      = ../src/testbench/$(TOP).sv
INCDIR  = -incdir ../src/include

# Outputs
VCD_OUT = ../src/$(DESIGN).vcd
SHM_OUT = ../src/shm_out

###############################################################
# Default Target
###############################################################
all: clean build run

###############################################################
# Generic launcher: make top.sim
###############################################################
%.sim:
	@echo "======================================="
	@echo " DESIGN = $*"
	@echo " TOP    = tb_$*"
	@echo "======================================="
	$(MAKE) DESIGN=$* all

###############################################################
# BUILD (Compile + Elaborate)
###############################################################
build:
	@echo "======================================="
	@echo " Compiling DUT   = $(DESIGN)"
	@echo " Testbench TOP  = $(TOP)"
	@echo " RTL (ALL)      = $(RTL)"
	@echo " TB             = $(TB)"
	@echo " INCLUDE DIR    = ../src/include"
	@echo "======================================="
	xrun -clean -64 -sv \
	     -vtimescale 1ns/1ps \
	     -top $(TOP) \
	     $(INCDIR) \
	     $(RTL) $(TB) \
	     -access +r \
	     +define+NUM_TRANSACTIONS=1

###############################################################
# RUN (Reuse Snapshot)
###############################################################
run:
	@echo "======================================="
	@echo " Running Simulation: $(TOP)"
	@echo "======================================="
	xrun -R

###############################################################
# VCD DUMP
###############################################################
vcd:
	@echo "======================================="
	@echo " Generating VCD for: $(DESIGN)"
	@echo " Output: $(VCD_OUT)"
	@echo "======================================="
	DESIGN=$(DESIGN) xrun -R -input vcd.tcl

###############################################################
# SHM DUMP
###############################################################
shm:
	@echo "======================================="
	@echo " Generating SHM for: $(DESIGN)"
	@echo " Output: $(SHM_OUT)"
	@echo "======================================="
	DESIGN=$(DESIGN) xrun -R -input shm.tcl

###############################################################
# CLEAN
###############################################################
clean:
	@echo "======================================="
	@echo " Cleaning Simulation Outputs"
	@echo "======================================="
	rm -rf xrun.* xcelium.d
	rm -rf $(SHM_OUT)
	rm -rf $(VCD_OUT)

.PHONY: all build run clean vcd shm %.sim

