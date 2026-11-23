`timescale 1ns/1ps
module tb_feed;
  logic clk=0,rst_n=0; always #5 clk=~clk;
  logic c_awvalid,c_awready; logic [7:0] c_awaddr; logic c_wvalid,c_wready; logic [31:0] c_wdata; logic [3:0] c_wstrb; logic c_bvalid,c_bready; logic c_arvalid,c_arready; logic [7:0] c_araddr; logic c_rvalid,c_rready; logic [31:0] c_rdata; logic [1:0] c_bresp,c_rresp;
  logic e_awvalid,e_awready; logic [7:0] e_awaddr; logic e_wvalid,e_wready; logic [31:0] e_wdata; logic [3:0] e_wstrb; logic e_bvalid,e_bready; logic e_arvalid,e_arready; logic [7:0] e_araddr; logic e_rvalid,e_rready; logic [31:0] e_rdata; logic [1:0] e_bresp,e_rresp;
  dash_dummy dut(.*); integer checks=0;
  task automatic ew(input [7:0] a,input [31:0] d,input [1:0] r); begin @(negedge clk);e_awaddr=a;e_awvalid=1;@(negedge clk);e_awvalid=0;e_wdata=d;e_wstrb=4'hf;e_wvalid=1;@(negedge clk);e_wvalid=0;wait(e_bvalid);checks=checks+1;if(e_bresp!==r)$finish(1);@(negedge clk);e_bready=1;@(negedge clk);e_bready=0;end endtask
  task automatic cw(input [7:0] a,input [31:0] d,input [1:0] r); begin @(negedge clk);c_awaddr=a;c_awvalid=1;@(negedge clk);c_awvalid=0;c_wdata=d;c_wstrb=4'hf;c_wvalid=1;@(negedge clk);c_wvalid=0;wait(c_bvalid);checks=checks+1;if(c_bresp!==r)$finish(1);@(negedge clk);c_bready=1;@(negedge clk);c_bready=0;end endtask
  task automatic er(input [7:0] a,input [31:0] d); begin @(negedge clk);e_araddr=a;e_arvalid=1;@(negedge clk);e_arvalid=0;wait(e_rvalid);checks=checks+1;if(e_rresp!==0||e_rdata!==d)$finish(1);@(negedge clk);e_rready=1;@(negedge clk);e_rready=0;end endtask
  initial begin c_awvalid=0;c_wvalid=0;c_bready=0;c_arvalid=0;c_rready=0;e_awvalid=0;e_wvalid=0;e_bready=0;e_arvalid=0;e_rready=0;c_wstrb=0;e_wstrb=0;repeat(3)@(negedge clk);rst_n=1;
    ew(8'h1c,32'h2,0);ew(8'h18,16,0);ew(8'h04,2,0);repeat(4)@(negedge clk);if(dut.core.state!==3) $finish(1);
    ew(8'h14,1,0);cw(8'h0c,32'h80000007,0);cw(8'h14,1,2);cw(8'h1c,1,2);repeat(10)@(negedge clk);er(8'h10,32'h80000007);
    $display("TRACE scenario=controlled_feed mode=E_C_FEED c_input=accepted c_start=SLVERR c_policy=SLVERR e_result=80000007 checks=%0d",checks);$finish;
  end
endmodule
