`timescale 1ns/1ps
module tb_dash;
  logic clk=0,rst_n=0; always #5 clk=~clk;
  logic c_awvalid,c_awready; logic [7:0] c_awaddr; logic c_wvalid,c_wready; logic [31:0] c_wdata; logic [3:0] c_wstrb; logic c_bvalid,c_bready; logic c_arvalid,c_arready; logic [7:0] c_araddr; logic c_rvalid,c_rready; logic [31:0] c_rdata; logic [1:0] c_bresp,c_rresp;
  logic e_awvalid,e_awready; logic [7:0] e_awaddr; logic e_wvalid,e_wready; logic [31:0] e_wdata; logic [3:0] e_wstrb; logic e_bvalid,e_bready; logic e_arvalid,e_arready; logic [7:0] e_araddr; logic e_rvalid,e_rready; logic [31:0] e_rdata; logic [1:0] e_bresp,e_rresp;
  integer checks=0; dash_dummy dut(.*);
  task automatic ewrite(input [7:0] a,input [31:0] d,input [1:0] expected); begin
    @(negedge clk); e_awaddr=a; e_awvalid=1; e_wvalid=0;
    @(negedge clk); e_awvalid=0; e_wdata=d; e_wstrb=4'hf; e_wvalid=1;
    @(negedge clk); e_wvalid=0; wait(e_bvalid); checks=checks+1;
    if(e_bresp!==expected) begin $display("FAIL E write addr=%h resp=%b expected=%b",a,e_bresp,expected); $finish(1); end
    @(negedge clk); e_bready=1; @(negedge clk); e_bready=0;
  end endtask
  task automatic cwrite(input [7:0] a,input [31:0] d,input [1:0] expected); begin
    @(negedge clk); c_wdata=d; c_wstrb=4'hf; c_wvalid=1; c_awvalid=0;
    @(negedge clk); c_wvalid=0; c_awaddr=a; c_awvalid=1;
    @(negedge clk); c_awvalid=0; wait(c_bvalid); checks=checks+1;
    if(c_bresp!==expected) begin $display("FAIL C write addr=%h resp=%b expected=%b",a,c_bresp,expected); $finish(1); end
    @(negedge clk); c_bready=1; @(negedge clk); c_bready=0;
  end endtask
  task automatic eread(input [7:0] a,input [31:0] expected,input [1:0] expected_resp); begin
    @(negedge clk); e_araddr=a; e_arvalid=1; @(negedge clk); e_arvalid=0; wait(e_rvalid); checks=checks+1;
    if(e_rresp!==expected_resp || (expected_resp==0 && e_rdata!==expected)) begin $display("FAIL E read addr=%h data=%h resp=%b state=%b op=%b cnt=%0d rv=%b dummy_out=%h dummy_v=%b run=%b inpend=%b indata=%h",a,e_rdata,e_rresp,dut.core.state,dut.core.op_active,dut.core.input_count,dut.core.result_valid,dut.dummy.data_out,dut.dummy.out_valid,dut.dummy.running,dut.core.input_pending,dut.core.input_pending_data); $finish(1); end
    @(negedge clk); e_rready=1; @(negedge clk); e_rready=0;
  end endtask
  task automatic cread(input [7:0] a,input [1:0] expected_resp); begin
    @(negedge clk); c_araddr=a; c_arvalid=1; @(negedge clk); c_arvalid=0; wait(c_rvalid); checks=checks+1;
    if(c_rresp!==expected_resp) begin $display("FAIL C read addr=%h resp=%b expected=%b",a,c_rresp,expected_resp); $finish(1); end
    @(negedge clk); c_rready=1; @(negedge clk); c_rready=0;
  end endtask
  initial begin
    c_awvalid=0;c_wvalid=0;c_bready=0;c_arvalid=0;c_rready=0;
    e_awvalid=0;e_wvalid=0;e_bready=0;e_arvalid=0;e_rready=0;c_wstrb=0;e_wstrb=0;
    repeat(3) @(negedge clk); rst_n=1;
    ewrite(8'h1c,32'h1,2'b00); ewrite(8'h18,32'd16,2'b00); ewrite(8'h04,32'h1,2'b00);
    repeat(4) @(negedge clk); if(dut.core.state!==3'd1) begin $display("FAIL C was not granted");$finish(1);end
    cwrite(8'h14,32'h1,2'b00); cwrite(8'h0c,32'h00000005,2'b00);
    ewrite(8'h14,32'h4,2'b00); repeat(2) @(negedge clk);
    if(dut.core.state!==3'd5 && dut.core.state!==3'd0) begin $display("FAIL revoke did not quiesce/clear");$finish(1);end
    cwrite(8'h0c,32'h00000006,2'b10);
    repeat(5) @(negedge clk); ewrite(8'h04,32'h2,2'b00); repeat(4) @(negedge clk);
    if(dut.core.state!==3'd2) begin $display("FAIL E was not granted after clear");$finish(1);end
    cwrite(8'h1c,32'h1,2'b10); cread(8'h10,2'b10);
    ewrite(8'h14,32'h1,2'b00); ewrite(8'h0c,32'h80000003,2'b00);
    repeat(10) @(negedge clk); eread(8'h10,32'h80000003,2'b00);
    $display("TRACE scenario=revocation ownership=C_to_E c_unauthorized=SLVERR e_result=80000003 checks=%0d",checks);
    $display("DASH SV Stage-1 revocation/security test PASS checks=%0d",checks); $finish;
  end
endmodule
