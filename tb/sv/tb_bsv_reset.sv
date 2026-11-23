`timescale 1ns/1ps
module tb_bsv_reset;
  logic clk=0,rst_n=0; always #5 clk=~clk;
  logic [7:0] cAw_a,eAw_a,cAr_a,eAr_a; logic [31:0] cW_d,eW_d; logic [3:0] cW_s,eW_s;
  logic EN_cAw=0,EN_cW=0,EN_cBReady=0,EN_cAr=0,EN_cRReady=0,EN_eAw=0,EN_eW=0,EN_eBReady=0,EN_eAr=0,EN_eRReady=0;
  wire RDY_cAw,RDY_cW,RDY_cBReady,RDY_cAr,RDY_cRReady,RDY_eAw,RDY_eW,RDY_eBReady,RDY_eAr,RDY_eRReady;
  wire cBValid,eBValid,cRValid,eRValid; wire [1:0] cBResp,eBResp,cRResp,eRResp; wire [31:0] cRData,eRData;
  wire cAwReady,cWReady,cArReady,eAwReady,eWReady,eArReady,cMayAccess,fault; wire [2:0] state;
  mkDashTop dut(.CLK(clk),.RST_N(rst_n),.cAw_a,.EN_cAw,.RDY_cAw,.cW_d,.cW_s,.EN_cW,.RDY_cW,.cBValid,.cBResp,.EN_cBReady,.RDY_cBReady,.cAr_a,.EN_cAr,.EN_cRReady,.eAw_a,.EN_eAw,.RDY_eAw,.eW_d,.eW_s,.EN_eW,.RDY_eW,.eBValid,.eBResp,.EN_eBReady,.RDY_eBReady,.eAr_a,.EN_eAr,.EN_eRReady,.cAwReady,.eAwReady,.state,.cMayAccess,.fault);
  task automatic ewrite(input [7:0] a,input [31:0] d); begin
    @(negedge clk); eAw_a=a; EN_eAw=1; while(!RDY_eAw) @(posedge clk); @(negedge clk); EN_eAw=0;
    eW_d=d;eW_s=4'hf;EN_eW=1;while(!RDY_eW)@(posedge clk);@(negedge clk);EN_eW=0;
    while(!eBValid)@(posedge clk);EN_eBReady=1;@(posedge clk);@(negedge clk);EN_eBReady=0;if(eBResp!==0)$fatal(1,"E write response");
  end endtask
  task automatic cwrite(input [7:0] a,input [31:0] d); begin
    @(negedge clk); cAw_a=a;EN_cAw=1;while(!RDY_cAw)@(posedge clk);@(negedge clk);EN_cAw=0;
    cW_d=d;cW_s=4'hf;EN_cW=1;while(!RDY_cW)@(posedge clk);@(negedge clk);EN_cW=0;
    while(!cBValid)@(posedge clk);EN_cBReady=1;@(posedge clk);@(negedge clk);EN_cBReady=0;if(cBResp!==0)$fatal(1,"C write response addr=%h resp=%0d",a,cBResp);
  end endtask
  initial begin
    cAw_a=0;cW_d=0;cW_s=0;eAw_a=0;eW_d=0;eW_s=0;cAr_a=0;eAr_a=0;
    repeat(3)@(negedge clk);rst_n=1;
    ewrite(8'h1c,1);ewrite(8'h18,16);ewrite(8'h04,1);while(state!==3'b001)@(posedge clk);
    cwrite(8'h14,1);cwrite(8'h0c,32'h80000009);
    @(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;repeat(2)@(negedge clk);
    if(state!==3'b000||fault)$fatal(1,"BSV reset failed state=%0d fault=%0d",state,fault);
    $display("BSV RESET PASS state=IDLE fault=0");$finish(0);
  end
endmodule
