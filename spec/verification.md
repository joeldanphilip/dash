# Verification status

Executed with the repository's local tools on the current checkout:

| Check | Command | Result |
|---|---|---|
| SV Stage-1 revocation/security regression | `make sv-test` | PASS: 13 self-checking transactions, including forced revocation and protected-result access |
| SV lint | `make sv-lint` | PASS: Verilator exit 0 with no `%Warning`/`%Error` diagnostics in latest log |
| BSV concrete elaboration smoke | `make bsv-test` | PASS: native BSV AXI/core/dummy top elaborates and runs Bluesim smoke |

The current SV regression covers reset, trusted policy programming, independent
AW/W arrival on both ports, C grant, C start/input, immediate E revocation while
C is active, adapter abort/clear, rejected post-revocation C input, later E grant,
C policy/result attacks, and a successful E operation/result read. It is not a
full conformance regression. The SVA module contains properties for isolation,
fault-closed behavior, input authorization, and response stability; no formal
engine is invoked by the default Makefile, so these are assertions available to
formal/simulation harnesses, not claimed proofs.

BSV status: `rtl/bsv/DashBsv.bsv` now contains a native AXI-facing controller,
independent C/E AW/W and AR/R queues, the common register map, three modes,
ownership/clear/timeout handling, input counting, protected results, and a native
dummy adapter. The concrete BSV top now elaborates and runs. It has a dedicated
transaction regression plus an automated common-trace/stress comparator against SV.

The expanded BSV transaction regression passes 10 checks and is deliberately
wired to make `make bsv-test` fail on `BSV FAIL`; the controlled-feed regression
passes 7 checks and is wired similarly. Fresh full elaboration now completes
with zero G0010/G0117 diagnostics for both
tops. The fix uses mutually exclusive response/state guards, explicit trusted-E
write priority, lifecycle guards around clear/quiesce/start, and an explicit
`feedInput` urgency declaration for the input-buffer handshake. No warning
suppression or `conflict_free` pragma is used. The earlier “warning-free” report
was from an incremental compile/reused schedule path; fresh elaboration now
reproduces the clean result.

Formal status: the direct Yosys SMTBMC flow now runs with Z3 for 20 bounded
cycles, temporal induction succeeds at step 20, and three reachability covers
pass at depth 40. The checked-in proof setup is `formal/dash.ys` plus the
Yosys-compatible assertions in `rtl/sv/dash_core.sv`; `formal/dash.sby` remains
available for environments that install SymbiYosys. The current bounded run
passes all embedded assertions.

Recovery status: `make sv-reset`, `make sv-fault`, `make bsv-reset`,
`make bsv-fault`, and `make bsv-timeout` pass. The BSV timeout top uses a
non-acknowledging adapter and verifies `CLEAR` reaches `FAULT` without reopening
C access. `make bsv-reset` drives the generated BSV Verilog `RST_N` during an
active C session and verifies return to IDLE.

The original package-install attempt was blocked, but the environment now exposes
Yosys, Z3, Boolector, and `yosys-smtbmc`; SymbiYosys itself is still absent.

Known implementation limitations to resolve before production integration:

* The native SV controller exposes one pending input word rather than a deeper
  FIFO; this is bounded buffering and applies backpressure at the AXI register,
  but does not yet provide a configurable FIFO depth.
* The current SV dummy wrapper binds the generic core to the dummy adapter. A
  production integration should instantiate `dash_core` directly with a
  contract-compliant adapter.
* The common runner compares two directed traces and the randomized stress
  transaction count; it does not yet compare every randomized transaction
  payload between implementations.
* The randomized stress generator targets malformed writes; broader
  application-level input-length permutations remain outside this regression.
