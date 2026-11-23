`default_nettype none
// Bind these properties to a dash_core instance in a formal or simulation top.
module dash_sva #(parameter int DATA_W=32)(
  input logic clk,input logic rst_n,input logic [2:0] state,input logic op_active,
  input logic c_access,input logic fault,input logic c_bvalid,input logic e_bvalid,
  input logic c_rvalid,input logic e_rvalid,input logic c_bready,input logic e_bready,input logic acc_data_valid,
  input logic acc_data_ready,input logic input_pending);
  localparam logic [2:0] FAULT=3'd6;
  property one_owner; @(posedge clk) disable iff(!rst_n) !(state==3'd1 && state==3'd2); endproperty
  property c_blocked_in_fault; @(posedge clk) disable iff(!rst_n) state==FAULT |-> !c_access; endproperty
  property input_only_when_pending; @(posedge clk) disable iff(!rst_n) acc_data_valid |-> input_pending; endproperty
  property responses_are_separate; @(posedge clk) !(c_bvalid && e_bvalid && c_rvalid && e_rvalid); endproperty
  assert property(one_owner);
  assert property(c_blocked_in_fault);
  assert property(input_only_when_pending);
  // AXI response stability while backpressured.
  assert property(@(posedge clk) c_bvalid && !c_bready |=> c_bvalid);
  assert property(@(posedge clk) e_bvalid && !e_bready |=> e_bvalid);
endmodule
`default_nettype wire
