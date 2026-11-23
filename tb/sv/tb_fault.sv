`timescale 1ns/1ps
module tb_fault;
  logic clk=0,rst_n=0; always #5 clk=~clk;
  logic c_awvalid,c_awready; logic [7:0] c_awaddr; logic c_wvalid,c_wready; logic [31:0] c_wdata; logic [3:0] c_wstrb; logic c_bvalid,c_bready; logic c_arvalid,c_arready; logic [7:0] c_araddr; logic c_rvalid,c_rready; logic [31:0] c_rdata; logic [1:0] c_bresp,c_rresp;
  logic e_awvalid,e_awready; logic [7:0] e_awaddr; logic e_wvalid,e_wready; logic [31:0] e_wdata; logic [3:0] e_wstrb; logic e_bvalid,e_bready; logic e_arvalid,e_arready; logic [7:0] e_araddr; logic e_rvalid,e_rready; logic [31:0] e_rdata; logic [1:0] e_bresp,e_rresp;
  dash_dummy #(.ERROR_ON_START(1'b1)) dut(.*);
  task automatic ew(input [7:0] a,input [31:0] d); begin @(negedge clk);e_awaddr=a;e_awvalid=1;@(negedge clk);e_awvalid=0;e_wdata=d;e_wstrb=4'hf;e_wvalid=1;@(negedge clk);e_wvalid=0;wait(e_bvalid);if(e_bresp!==0)$fatal(1);e_bready=1;@(negedge clk);e_bready=0;end endtask
  task automatic cw(input [7:0] a,input [31:0] d); begin @(negedge clk);c_awaddr=a;c_awvalid=1;@(negedge clk);c_awvalid=0;c_wdata=d;c_wstrb=4'hf;c_wvalid=1;@(negedge clk);c_wvalid=0;wait(c_bvalid);if(c_bresp!==0)$fatal(1);c_bready=1;@(negedge clk);c_bready=0;end endtask
  initial begin
    c_awvalid=0;c_wvalid=0;c_bready=0;c_arvalid=0;c_rready=0;e_awvalid=0;e_wvalid=0;e_bready=0;e_arvalid=0;e_rready=0;c_wstrb=0;e_wstrb=0;
    repeat(3)@(negedge clk);rst_n=1; ew(8'h1c,1);ew(8'h18,16);ew(8'h04,1);wait(dut.core.state==1);cw(8'h14,1);repeat(4)@(negedge clk);
    if(dut.core.state!==6 || dut.core.c_access!==0)$fatal(1,"fault not fail-closed state=%0d access=%0d",dut.core.state,dut.core.c_access);
    $display("SV FAULT PASS fault_closed=1");$finish(0);
  end
endmodule
