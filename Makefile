BUILD=build
SV=iverilog -g2012 -Wall -Wno-timescale
SV_SRCS=rtl/sv/dash_core.sv rtl/sv/dash_dummy_accel.sv rtl/sv/dash_dummy.sv

.PHONY: sv-test sv-feed sv-axi-random sv-reset sv-fault bsv-reset bsv-formal bsv-feed bsv-axi-random bsv-fault bsv-timeout sv-lint bsv-test common-test formal repo-boundary clean
sv-test: $(BUILD)/sv.out
	 vvp $(BUILD)/sv.out | tee $(BUILD)/sv-test.log

sv-feed:
	mkdir -p $(BUILD)
	$(SV) -s tb_feed -o $(BUILD)/sv-feed.out $(SV_SRCS) tb/sv/tb_feed.sv
	vvp $(BUILD)/sv-feed.out | tee $(BUILD)/sv-feed.log

sv-axi-random:
	mkdir -p $(BUILD)
	$(SV) -s tb_axi_random -o $(BUILD)/sv-axi-random.out $(SV_SRCS) tb/sv/tb_axi_random.sv
	vvp $(BUILD)/sv-axi-random.out +SEED=1592594996 | tee $(BUILD)/sv-axi-random.log

sv-reset:
	mkdir -p $(BUILD)
	$(SV) -s tb_reset -o $(BUILD)/sv-reset.out $(SV_SRCS) tb/sv/tb_reset.sv
	vvp $(BUILD)/sv-reset.out | tee $(BUILD)/sv-reset.log

sv-fault:
	mkdir -p $(BUILD)
	$(SV) -s tb_fault -o $(BUILD)/sv-fault.out $(SV_SRCS) tb/sv/tb_fault.sv
	vvp $(BUILD)/sv-fault.out | tee $(BUILD)/sv-fault.log


$(BUILD)/sv.out: $(SV_SRCS) tb/sv/tb_dash.sv
	mkdir -p $(BUILD)
	$(SV) -s tb_dash -o $@ $(SV_SRCS) tb/sv/tb_dash.sv

sv-lint:
	mkdir -p $(BUILD)
	verilator --lint-only --timing -Wall --Wno-fatal --top-module dash_dummy $(SV_SRCS) 2>&1 | tee $(BUILD)/verilator-lint.log

bsv-test:
	mkdir -p $(BUILD)
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -sim -g mkTbDashComplete -show-schedule -p +:rtl/bsv:tb/bsv tb/bsv/TbDashComplete.bsv 2>&1 | tee $(BUILD)/bsv-compile.log
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -sim -e mkTbDashComplete -o $(BUILD)/tb_bsv -p +:rtl/bsv:tb/bsv 2>&1 | tee -a $(BUILD)/bsv-compile.log
	set -o pipefail; $(BUILD)/tb_bsv | tee $(BUILD)/bsv-test.log; ! rg -q 'BSV FAIL' $(BUILD)/bsv-test.log

bsv-feed:
	mkdir -p $(BUILD)
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -sim -g mkTbDashFeed -p +:rtl/bsv:tb/bsv tb/bsv/TbDashFeed.bsv 2>&1 | tee $(BUILD)/bsv-feed-compile.log
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -sim -e mkTbDashFeed -o $(BUILD)/tb_bsv_feed -p +:rtl/bsv:tb/bsv 2>&1 | tee -a $(BUILD)/bsv-feed-compile.log
	set -o pipefail; $(BUILD)/tb_bsv_feed | tee $(BUILD)/bsv-feed.log; ! rg -q 'BSV FEED FAIL' $(BUILD)/bsv-feed.log

bsv-axi-random:
	mkdir -p $(BUILD)
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -sim -g mkTbDashStress -show-schedule -p +:rtl/bsv:tb/bsv tb/bsv/TbDashStress.bsv 2>&1 | tee $(BUILD)/bsv-stress-compile.log
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -sim -e mkTbDashStress -o $(BUILD)/tb_bsv_stress -p +:rtl/bsv:tb/bsv 2>&1 | tee -a $(BUILD)/bsv-stress-compile.log
	set -o pipefail; $(BUILD)/tb_bsv_stress | tee $(BUILD)/bsv-axi-random.log; ! rg -q 'BSV STRESS FAIL' $(BUILD)/bsv-axi-random.log

bsv-fault:
	mkdir -p $(BUILD)
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -sim -g mkTbDashFault -show-schedule -p +:rtl/bsv:tb/bsv tb/bsv/TbDashFault.bsv 2>&1 | tee $(BUILD)/bsv-fault-compile.log
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -sim -e mkTbDashFault -o $(BUILD)/tb_bsv_fault -p +:rtl/bsv:tb/bsv 2>&1 | tee -a $(BUILD)/bsv-fault-compile.log
	set -o pipefail; $(BUILD)/tb_bsv_fault | tee $(BUILD)/bsv-fault.log; ! rg -q 'BSV FAULT FAIL' $(BUILD)/bsv-fault.log

bsv-timeout:
	mkdir -p $(BUILD)
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -sim -g mkTbDashTimeout -show-schedule -p +:rtl/bsv:tb/bsv tb/bsv/TbDashTimeout.bsv 2>&1 | tee $(BUILD)/bsv-timeout-compile.log
	set -o pipefail; BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -sim -e mkTbDashTimeout -o $(BUILD)/tb_bsv_timeout -p +:rtl/bsv:tb/bsv 2>&1 | tee -a $(BUILD)/bsv-timeout-compile.log
	set -o pipefail; $(BUILD)/tb_bsv_timeout | tee $(BUILD)/bsv-timeout.log; ! rg -q 'BSV TIMEOUT FAIL' $(BUILD)/bsv-timeout.log

bsv-reset:
	mkdir -p $(BUILD)
	BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -verilog -g mkDashTop -p +:rtl/bsv rtl/bsv/DashVerilogTop.bsv
	$(SV) -s tb_bsv_reset -o $(BUILD)/bsv-reset.out rtl/bsv/mkDashTop.v tb/sv/tb_bsv_reset.sv
	vvp $(BUILD)/bsv-reset.out | tee $(BUILD)/bsv-reset.log

bsv-formal:
	mkdir -p $(BUILD)
	BLUESPECDIR=$${BLUESPECDIR:-/home/joel/tools/bsc/lib} bsc -u -verilog -g mkDashTop -p +:rtl/bsv rtl/bsv/DashVerilogTop.bsv
	set -o pipefail; yosys -q -p 'read_verilog -formal rtl/bsv/mkDashTop.v formal/bsv_formal.sv; prep -top bsv_formal; write_smt2 -wires build/bsv_formal.smt2' 2>&1 | tee $(BUILD)/bsv-formal-yosys.log
	set -o pipefail; yosys-smtbmc -s z3 -t 20 build/bsv_formal.smt2 2>&1 | tee $(BUILD)/bsv-formal.log



common-test:
	python3 scripts/common_regression.py | tee $(BUILD)/common-regression.log

formal:
	mkdir -p $(BUILD)
	@if command -v yosys-smtbmc >/dev/null 2>&1 && command -v yosys >/dev/null 2>&1 && command -v z3 >/dev/null 2>&1; then \
		set -o pipefail; yosys -q -s formal/dash.ys 2>&1 | tee $(BUILD)/formal-yosys.log; \
		set -o pipefail; yosys-smtbmc -s z3 -t 20 --presat build/dash.smt2 2>&1 | tee $(BUILD)/formal.log; \
	else \
		echo "FORMAL NOT RUN: requires Yosys, yosys-smtbmc, and an SMT solver" | tee $(BUILD)/formal.log; \
		exit 2; \
	fi

repo-boundary:
	python3 scripts/check_repo_boundary.py

clean:
	rm -rf $(BUILD) *.bo *.ba *.bsv *.v
