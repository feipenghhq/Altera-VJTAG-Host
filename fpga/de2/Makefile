
GIT_ROOT 	= $(shell git rev-parse --show-toplevel)
SCRIPT_DIR 	= $(GIT_ROOT)/scripts/quartus

# device part
PART = EP2C35F672C7
# device family
FAMILY = Cyclone II
# project name
PROJECT ?= vjtag_host
# top level name
TOP ?= top
# verilog source files
VERILOG += $(GIT_ROOT)/rtl/vjtag/vjtag_ctrl.sv
VERILOG += $(GIT_ROOT)/rtl/vjtag/vjtag_ip.v
VERILOG += $(GIT_ROOT)/rtl/vjtag/vjtag2wb.sv
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/fpga_vjtag2gpio.sv
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/wbgpio.sv
VERILOG += $(GIT_ROOT)/fpga/de2/top.sv
# verilog include directory
SEARCH ?=
# verilog define
DEFINE ?=
# sdc files
SDC	?= $(PWD)/timing.sdc
# pin assignment files
PIN ?= $(PWD)/pin.tcl
# project output directory
OUT_DIR ?= outputs

include $(GIT_ROOT)/scripts/quartus/makefile.mk