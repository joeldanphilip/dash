`timescale 1ns/1ps
module tb_axi_random;
  logic clk=0, rst_n=0; always #5 clk=~clk;
  logic c_awvalid,c_awready; logic [7:0] c_awaddr; logic c_wvalid,c_wready; logic [31:0] c_wdata; logic [3:0] c_wstrb; logic c_bvalid,c_bready;
  logic c_arvalid,c_arready; logic [7:0] c_araddr; logic c_rvalid,c_rready; logic [31:0] c_rdata; logic [1:0] c_bresp,c_rresp;
  logic e_awvalid,e_awready; logic [7:0] e_awaddr; logic e_wvalid,e_wready; logic [31:0] e_wdata; logic [3:0] e_wstrb; logic e_bvalid,e_bready;
  logic e_arvalid,e_arready; logic [7:0] e_araddr; logic e_rvalid,e_rready; logic [31:0] e_rdata; logic [1:0] e_bresp,e_rresp;
  dash_dummy dut(.*);
  integer seed=32'h5eed1234, count=0, i, timeout;
  task automatic wr(input bit trusted, input [7:0] addr, input [31:0] data, input [1:0] expected);
    bit aw_first; bit aw_done,w_done; bit finished; begin
      aw_first=$urandom(seed)&1; aw_done=0; w_done=0;
      if(trusted) begin e_awaddr=addr;e_wdata=data;e_wstrb=4'hf;e_awvalid=0;e_wvalid=0;e_bready=0; end
      else begin c_awaddr=addr;c_wdata=data;c_wstrb=4'hf;c_awvalid=0;c_wvalid=0;c_bready=0; end
      @(negedge clk);
      if(aw_first) begin
        if(trusted)e_awvalid=1;else c_awvalid=1; @(negedge clk); if(trusted)e_awvalid=0;else c_awvalid=0;
        if(trusted)e_wvalid=1;else c_wvalid=1; @(negedge clk); if(trusted)e_wvalid=0;else c_wvalid=0;
      end else begin
        if(trusted)e_wvalid=1;else c_wvalid=1; @(negedge clk); if(trusted)e_wvalid=0;else c_wvalid=0;
        if(trusted)e_awvalid=1;else c_awvalid=1; @(negedge clk); if(trusted)e_awvalid=0;else c_awvalid=0;
      end
      timeout=0;
      finished=0;
      while((trusted&&!e_bvalid)||(!trusted&&!c_bvalid)) begin
        @(negedge clk); timeout=timeout+1; if(timeout>100)$fatal(1,"write response timeout");
      end
      if(trusted)e_bready=1;else c_bready=1;
      @(posedge clk);
      if(trusted) begin if(e_bresp!==expected)$fatal(1,"E response %0d expected %0d",e_bresp,expected); e_bready=0; end
      else begin if(c_bresp!==expected)$fatal(1,"C response %0d expected %0d",c_bresp,expected); c_bready=0; end
      finished=1;
    end
  endtask
  initial begin
    c_awvalid=0;c_wvalid=0;c_bready=0;c_arvalid=0;c_rready=0;c_wstrb=0;e_awvalid=0;e_wvalid=0;e_bready=0;e_arvalid=0;e_rready=0;e_wstrb=0;
    if($value$plusargs("SEED=%d",seed)) $display("AXI RANDOM seed=%0d",seed);
    repeat(4) @(negedge clk); rst_n=1;
    for(i=0;i<10000;i=i+1) begin
      wr(i[0], (i%3==0)?8'hfc:8'h80, $urandom(seed), 2'b10); count=count+1;
    end
    $display("AXI RANDOM PASS seed=%0d transactions=%0d",seed,count); $finish(0);
  end
endmodule
