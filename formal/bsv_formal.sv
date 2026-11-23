`default_nettype none
module bsv_formal(input CLK);
  reg RST_N=0; always @(posedge CLK) RST_N<=1;
  (* anyseq *) reg [7:0] cAw_a,cAr_a,eAw_a,eAr_a;
  (* anyseq *) reg [31:0] cW_d,eW_d;
  (* anyseq *) reg [3:0] cW_s,eW_s;
  (* anyseq *) reg EN_cAw,EN_cW,EN_cBReady,EN_cAr,EN_cRReady,EN_eAw,EN_eW,EN_eBReady,EN_eAr,EN_eRReady;
  wire cAwReady,RDY_cAwReady,RDY_cAw,cWReady,RDY_cWReady,RDY_cW,cBValid,RDY_cBValid,RDY_cBResp,RDY_cBReady;
  wire [1:0] cBResp; wire cArReady,RDY_cArReady,RDY_cAr,cRValid,RDY_cRValid,RDY_cRData,RDY_cRResp,RDY_cRReady; wire [31:0] cRData; wire [1:0] cRResp;
  wire eAwReady,RDY_eAwReady,RDY_eAw,eWReady,RDY_eWReady,RDY_eW,eBValid,RDY_eBValid,RDY_eBResp,RDY_eBReady; wire [1:0] eBResp;
  wire eArReady,RDY_eArReady,RDY_eAr,eRValid,RDY_eRValid,RDY_eRData,RDY_eRResp,RDY_eRReady; wire [31:0] eRData; wire [1:0] eRResp;
  wire [2:0] state; wire RDY_state; wire cMayAccess,RDY_cMayAccess,fault,RDY_fault;
  mkDashTop dut(.CLK,.RST_N,.cAwReady,.RDY_cAwReady,.cAw_a,.EN_cAw,.RDY_cAw,.cWReady,.RDY_cWReady,.cW_d,.cW_s,.EN_cW,.RDY_cW,.cBValid,.RDY_cBValid,.cBResp,.RDY_cBResp,.EN_cBReady,.RDY_cBReady,.cArReady,.RDY_cArReady,.cAr_a,.EN_cAr,.RDY_cAr,.cRValid,.RDY_cRValid,.cRData,.RDY_cRData,.cRResp,.RDY_cRResp,.EN_cRReady,.RDY_cRReady,.eAwReady,.RDY_eAwReady,.eAw_a,.EN_eAw,.RDY_eAw,.eWReady,.RDY_eWReady,.eW_d,.eW_s,.EN_eW,.RDY_eW,.eBValid,.RDY_eBValid,.eBResp,.RDY_eBResp,.EN_eBReady,.RDY_eBReady,.eArReady,.RDY_eArReady,.eAr_a,.EN_eAr,.RDY_eAr,.eRValid,.RDY_eRValid,.eRData,.RDY_eRData,.eRResp,.RDY_eRResp,.EN_eRReady,.RDY_eRReady,.state,.RDY_state,.cMayAccess,.RDY_cMayAccess,.fault,.RDY_fault);
  always @(posedge CLK) begin
    assert(state != 3'b111);
    assert(!fault || !cMayAccess);
    assert(state != 3'b110 || !cMayAccess);
    if(!RST_N) assert(state == 3'b000);
    cover(state == 3'b001);
    cover(state == 3'b011);
    cover(state == 3'b110);
  end
endmodule
`default_nettype wire
