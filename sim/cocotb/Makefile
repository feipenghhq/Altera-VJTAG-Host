# Makefile

REPO = $(shell git rev-parse --show-toplevel)

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES = 1

# quartus installation path
QUARTUS_PATH = /home/feipenghhq/altera/13.0sp1/quartus

VERILOG_SOURCES += $(shell find $(REPO)/rtl -name "*.sv")
VERILOG_SOURCES += $(shell find $(REPO)/rtl -name "*.v")
VERILOG_SOURCES += $(QUARTUS_PATH)/eda/sim_lib/altera_mf.v

#VERILOG_INCLUDE_DIRS +=

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = vjtag_host

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim