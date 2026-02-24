# XR Series Simulation Makefile

# 工具選擇
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# 設計源文件路徑
RTL_DIR = ..
VERILOG_SOURCES += $(RTL_DIR)/xsm/xsm_capture.sv
VERILOG_SOURCES += $(RTL_DIR)/xsm/xsm_fifo.sv
VERILOG_SOURCES += $(RTL_DIR)/xsm/xsm_trigger.sv

# 頂層模塊
TOPLEVEL = xsm_capture_simple

# Python 模塊路徑
MODULE = tests.test_$(TEST)
COCOTB_TEST_MODULES = tests.test_$(TEST)

# 模擬參數
COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps
WAVES ?= 0
COVERAGE ?= 0
PYTHONPATH := $(PWD):$(PYTHONPATH)

# 包含 cocotb 規則
include $(shell cocotb-config --makefiles)/Makefile.sim

# 自定義目標
clean::
	rm -rf sim_build/
	rm -f results.xml
	rm -f *.vcd *.fst *.log

waves::
	@echo "Opening waveform viewer..."
	@gtkwave dump.vcd &

help::
	@echo "Available commands:"
	@echo "  make TEST=test_name  - Run simulation"
	@echo "  make waves           - View waveforms"
	@echo "  make clean           - Clean build files"

.PHONY: clean waves help
