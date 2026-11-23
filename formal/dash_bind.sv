`default_nettype none
// Formal binding for the native core. The core's top-level inputs are left
// unconstrained by the proof harness; adapter contract assumptions belong in
// the integration-specific harness.
bind dash_core dash_sva dash_sva_i (
  .clk(clk), .rst_n(rst_n), .state(state), .op_active(op_active),
  .c_access(c_access), .fault(fault), .c_bvalid(c_bvalid), .e_bvalid(e_bvalid),
  .c_rvalid(c_rvalid), .e_rvalid(e_rvalid), .c_bready(c_bready),
  .e_bready(e_bready), .acc_data_valid(acc_data_valid),
  .acc_data_ready(acc_data_ready), .input_pending(input_pending)
);
`default_nettype wire
