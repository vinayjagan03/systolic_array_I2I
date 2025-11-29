########################################################
# FINAL Xcelium Makefile (Generalized, Default = top)
########################################################

# =========================
# Default Design (can be overridden)
# =========================
DESIGN ?= top
TOP    = tb_$(DESIGN)

# =========================
# Auto-Derived Paths
# =========================
RTL = ../src/modules/$(DESIGN).sv
TB  = ../src/testbench/$(TOP).sv

# =========================
# Include Directory
# =========================
INCDIR = -incdir ../src/include

# =========================
# Output Locations
# =========================
VCD_OUT = ../src/testbench/$(DESIGN).vcd
SHM_OUT = ../src/testbench/shm_out

# =========================
# Default Target
# =========================
all: clean build run

########################################################
# Generalized <design>.sim Target
########################################################
%.sim:
	@echo "======================================="
	@echo " Overriding DESIGN = $*"
	@echo " Using RTL = ../src/modules/$*.sv"
	@echo " Using TB  = ../src/testbench/tb_$*.sv"
	@echo "======================================="
	$(MAKE) DESIGN=$* all

########################################################
# 1. COMPILE ONLY
########################################################
build:
	@echo "======================================="
	@echo " Compiling DUT   = $(DESIGN)"
	@echo " Testbench TOP  = $(TOP)"
	@echo " RTL            = $(RTL)"
	@echo " TB             = $(TB)"
	@echo " INCLUDE DIR    = ../src/include"
	@echo "======================================="
	xrun -clean -64 -sv \
	     -top $(TOP) \
	     $(INCDIR) \
	     $(RTL) $(TB) \
	     -access +r \
	     +define+NUM_TRANSACTIONS=1

########################################################
# 2. NORMAL RUN
########################################################
run:
	@echo "======================================="
	@echo " Running Simulation: $(TOP)"
	@echo "======================================="
	xrun -R

########################################################
# 3. GENERATE VCD
########################################################
vcd:
	@echo "======================================="
	@echo " Generating VCD for: $(DESIGN)"
	@echo " Output: $(VCD_OUT)"
	@echo "======================================="
	xrun -R -input vcd.tcl \
	     -define DESIGN=$(DESIGN)

########################################################
# 4. GENERATE SHM WITH MDA
########################################################
shm:
	@echo "======================================="
	@echo " Generating SHM for: $(DESIGN)"
	@echo " Output: $(SHM_OUT)"
	@echo "======================================="
	xrun -64 -sv -access +rwc \
	     -top $(TOP) \
	     $(INCDIR) \
	     -input shm.tcl \
	     -define DESIGN=$(DESIGN) \
	     $(RTL) $(TB)

########################################################
# CLEAN
########################################################
clean:
	@echo "======================================="
	@echo " Cleaning Simulation Outputs"
	@echo "======================================="
	rm -rf xrun.* xcelium.d
	rm -rf $(SHM_OUT)
	rm -rf $(VCD_OUT)

.PHONY: all build run vcd shm clean %.sim

