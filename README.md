# ASIC Design of 64×64 Systolic Array for Matrix Multiplication

## Abstract

This project implements a **64×64 systolic array accelerator** for
high-performance matrix multiplication using a fully parallel processing
architecture optimized for throughput and scalability. The complete ASIC
design flow is covered, including **RTL design, functional verification,
synthesis using the Cadence 45 nm library, logic equivalence checking
(LEC), physical implementation (PnR), power analysis, and gate-level
simulation**. The final deliverables include **timing, power, area
reports and GDSII layout** generated using industry-standard EDA tools.

------------------------------------------------------------------------

## Table of Contents

1.  Introduction\
2.  Repository Structure\
3.  Systolic Array RTL to GDS Flow\
4.  Prerequisite Tools\
5.  Getting Started\
6.  Verification & Simulation\
7.  Synthesis\
8.  Logic Equivalence Checking\
9.  Physical Design (PnR)\
10. Power Analysis\
11. Full Report\
12. Contributors

------------------------------------------------------------------------

## 1. Introduction

The systolic array architecture is a highly scalable and efficient
structure for accelerating matrix operations such as **matrix
multiplication**, a fundamental computation used in **machine learning,
signal processing, and HPC workloads**.

This project implements a **64×64 systolic array composed of 4096
Processing Elements (PEs)** arranged in a regular 2D mesh. Each PE
performs **multiply-accumulate (MAC)** operations and passes partial
sums to its neighboring PEs in a rhythmic pipelined fashion.

A centralized **controller module** manages: - Input data flow\
- Weight loading\
- Computation sequencing\
- Output collection

This project covers the **complete RTL-to-GDS ASIC flow**, enabling a
real silicon-ready implementation.

------------------------------------------------------------------------

## 2. Repository Structure

    ├── src/                # RTL design files
    │   ├── modules/        # Controller, PE, FP32 MAC, Systolic Array
    │   ├── include/        # SystemVerilog package files
    │   └── testbench/      # Testbenches & bind files

    ├── synthesis/          # Cadence Genus synthesis flow
    │   ├── constraints.sdc
    │   ├── genus.cmd
    │   ├── synthesis_flow.tcl
    │   ├── reports/
    │   └── outputs/

    ├── lec/               # Cadence Conformal LEC flow
    │   ├── top_lec.tcl
    │   ├── fv/
    │   └── rtl_fv_map_db/

    ├── layout/            # Cadence Innovus PnR flow
    │   ├── layout_flow.tcl
    │   ├── outputs/       # GDSII and final layout
    │   ├── reports/       # Post-route timing, power, area
    │   └── savedDesign/

    ├── power_analysis/    # Voltus power analysis scripts
    ├── xcelium_run/       # Cadence Xcelium wave/dump scripts
    ├── waveforms/         # Simulation waveform setup
    ├── mat_test.py        # Python verification for matrix ops
    ├── Makefile
    ├── global_variables.tcl
    └── README.md

------------------------------------------------------------------------

## 3. Systolic Array RTL to GDS Flow

### 1. RTL Design

**Location:** `src/modules/`

Key files: - `controller.sv` - `fp32_add.sv` - `fp32_mul.sv` -
`fp32_mac.sv` - `processing_element.sv` - `systolic_array.sv` -
`systolic_array_top.sv` - `top.sv`

------------------------------------------------------------------------

### 2. Pre-Synthesis Simulation

**Location:** `src/testbench/`\
**Tool:** Cadence Xcelium\
Used for **functional verification of RTL before synthesis**.

------------------------------------------------------------------------

### 3. Synthesis

**Location:** `synthesis/`\
**Tool:** Cadence Genus (45 nm Nangate Library)

Run:

``` bash
cd synthesis
genus -f synthesis_flow.tcl
```

Outputs: - `top_netlist.sv` - `top.sdf` - Area, Power, Timing & QoR
reports in:

    synthesis/reports/
    synthesis/outputs/

------------------------------------------------------------------------

### 4. Logic Equivalence Checking (LEC)

**Location:** `lec/`\
**Tool:** Cadence Conformal

Run:

``` bash
cd lec
lec -XL -nogui -color -64 -dofile top_lec.tcl
```

Ensures **RTL and synthesized netlist are functionally identical**.

------------------------------------------------------------------------

### 5. Physical Design (PnR)

**Location:** `layout/`\
**Tool:** Cadence Innovus

Includes: - Floorplanning\
- Power Planning\
- Placement\
- Clock Tree Synthesis (CTS)\
- Routing\
- DRC\
- GDSII Generation

Run:

``` bash
cd layout
innovus -stylus
source layout_flow.tcl
```

Final output:

    layout/outputs/top.gds

------------------------------------------------------------------------

### 6. Power Analysis

**Location:** `power_analysis/`\
**Tool:** Cadence Voltus

Used for **post-layout switching-activity-based power estimation**.

------------------------------------------------------------------------

## 4. Prerequisite Tools

### Cadence EDA Tools

-   **Xcelium 23.x** -- RTL Simulation\
-   **Genus 21.x** -- Logic Synthesis\
-   **Innovus 21.x** -- Physical Design & Routing\
-   **Conformal 24.x** -- Logic Equivalence Checking\
-   **Voltus** -- Power Analysis

### Technology

-   **Nangate 45 nm Standard Cell Library**

------------------------------------------------------------------------

## 5. Getting Started

### Clone the Repository

``` bash
git clone https://github.com/vishalkevat007/systolic_array_I2I.git
cd systolic_array_I2I
```

------------------------------------------------------------------------

## 6. Verification & Simulation

### Using Cadence Xcelium

``` bash
cd xcelium_run
make
```

Or manually:

``` bash
xrun -f filelist.txt -access +rwc -gui
```

Waveform configuration: - `waveforms/wave.do` - `xcelium_run/shm.tcl` -
`xcelium_run/vcd.tcl`

------------------------------------------------------------------------

## 7. Synthesis

``` bash
cd synthesis
genus -f synthesis_flow.tcl
```

Reports generated in:

    synthesis/reports/

------------------------------------------------------------------------

## 8. Logic Equivalence Checking

``` bash
cd lec
lec -XL -nogui -color -64 -dofile top_lec.tcl
```

------------------------------------------------------------------------

## 9. Physical Design (PnR)

``` bash
cd layout
innovus -stylus
source layout_flow.tcl
```

Final layout:

    layout/outputs/top.gds

------------------------------------------------------------------------

## 10. Power Analysis

``` bash
cd power_analysis
./run_power
```

------------------------------------------------------------------------

## 11. Full Report

For complete benchmarking methodology, timing closure, area utilization,
power breakdown, and architectural discussion, refer to the **project
report PDF**.

------------------------------------------------------------------------

## 12. Contributors

-   **Vishal Kevat**\
-   **Jagdish Kurdiya**\
-   **Niharika Tulugu**
