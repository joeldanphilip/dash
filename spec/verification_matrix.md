# DASH Stage 1 verification matrix

| Area | SV | BSV | Status |
|---|---|---|---|
| Independent AW/W capture | Executed in Stage-1 test | Native C/E FIFOs implemented; not scenario-tested | Partial |
| B/R backpressure | Basic response holding tested | Response holding implemented; not scenario-tested | Partial |
| Trusted policy/register protection | Executed | Implemented in `mkDashBsv`; not scenario-tested | Partial |
| Untrusted-owned mode | Executed | Implemented; smoke only | Partial |
| Trusted-owned mode | Executed after revocation | Implemented; smoke only | Partial |
| Controlled-feed mode | `make sv-feed`: PASS, 8 checks | `make bsv-feed`: PASS, 7 checks | PASS for covered directed path |
| Immediate revocation | 13-check regression PASS | 10-check transaction regression PASS | PASS for covered path |
| Adapter abort/clear | Dummy exercised in SV | Dummy exercised through revoke/clear regression | PASS for covered path |
| Input-length boundary | Not yet exhaustive | Counter/limit implemented | Not complete |
| Stalled/missing clear | Formal core checks only | `make bsv-timeout`: PASS, non-acknowledging adapter reaches `FAULT` and C access remains closed | PASS for BSV missing-clear path |
| Reset during transactions | `make sv-reset`: PASS, 6 checks; reset during active C operation clears state/result | `make bsv-reset`: PASS through generated BSV Verilog, mid-operation RST_N returns IDLE with fault=0 | PASS |
| Adapter fault fail-closed | `make sv-fault`: PASS, injected adapter error closes C access | `make bsv-fault`: PASS, injected adapter error closes C access; fresh top 0 warnings | PASS for injected-fault path |
| Stale result/completion | Basic result invalidation path | Result invalidation path implemented | Not complete |
| Formal safety | Z3 BMC depth 20: 5 assertions PASS; temporal induction PASS at step 20 | Generated BSV RTL: 4 assertions, Z3 BMC depth 20 and induction PASS; ownership/fault/reset assertions | PASS for checked properties |
| Formal reachability | 3 cover targets (C_ACTIVE, E_C_FEED, FAULT), cover run depth 40 PASS | Generated BSV RTL: C_ACTIVE, E_C_FEED, FAULT covers PASS at depth 40 | PASS for checked covers |
| BSV/SV equivalence | Common runner compares 2 normalized traces | Common runner compares 2 normalized traces | PASS for 2 directed traces |

| Verilator lint | `make sv-lint`: exit 0, no `%Warning`/`%Error` in latest log | N/A | PASS |
| BSV scheduling | Main fresh elaboration: 0 G0010/G0117 warnings; feed fresh elaboration: 0 warnings | Guarded arbitration and explicit input-feed urgency; no suppression | PASS |
| Randomized AXI stress | Seeds 1592594996, 17, and 83: 10,000 transactions PASS each | Seed 1592594996: 10,000 transactions PASS | PASS for malformed-write stress |
| Common trace scoreboard | 2 directed traces plus 10,000-count stress comparison | 2 directed traces plus 10,000-count stress comparison | PASS for covered scenarios |

Stage 1 evidence is complete for the defined gates in this matrix. Fresh BSV
elaboration is warning-free; both implementations pass directed, controlled-
feed, reset/fault, randomized AXI, stress, and formal gates. The common runner
compares normalized directed traces and the randomized transaction count rather
than cycle-by-cycle payload traces. The remaining limitations are scope notes:
the stress generator targets malformed writes, and exhaustive application-level
input-length permutations are outside this regression set.
