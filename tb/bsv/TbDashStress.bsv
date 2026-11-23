package TbDashStress;
import DashBsv::*;
module mkTbDashStress(Empty);
  DashAdapter a<-mkDashDummy; DashAxi d<-mkDashBsv(a);
  Reg#(UInt#(14)) n<-mkReg(0); Reg#(UInt#(20)) ticks<-mkReg(0);
  Reg#(UInt#(3)) phase<-mkReg(0); Reg#(Bool) trusted<-mkReg(False);
  Reg#(Bit#(32)) lfsr<-mkReg(32'h5eed1234);
  function Bit#(32) step(Bit#(32) x); return {x[30:0],x[31]^x[21]^x[1]^x[0]}; endfunction
  rule tick; ticks<=ticks+1; if(ticks>200000)begin $display("BSV STRESS FAIL timeout n=%0d phase=%0d",n,phase);$finish(1);end endrule
  rule choose(phase==0&&n<10000); Bit#(32) x=step(lfsr);lfsr<=x;trusted<=x[0]==1;phase<=(x[1]==1)?1:2;endrule
  rule sendAw(phase==1&&trusted&&d.eAwReady);d.eAw(8'hfc);phase<=4;endrule
  rule sendAwC(phase==1&&!trusted&&d.cAwReady);d.cAw(8'hfc);phase<=4;endrule
  rule sendWFirst(phase==2&&trusted&&d.eWReady);d.eW(lfsr,4'hf);phase<=3;endrule
  rule sendWFirstC(phase==2&&!trusted&&d.cWReady);d.cW(lfsr,4'hf);phase<=3;endrule
  rule sendAwSecond(phase==3&&trusted&&d.eAwReady);d.eAw(8'hfc);phase<=5;endrule
  rule sendAwSecondC(phase==3&&!trusted&&d.cAwReady);d.cAw(8'hfc);phase<=5;endrule
  rule sendWSecond(phase==4&&trusted&&d.eWReady);d.eW(lfsr,4'hf);phase<=5;endrule
  rule sendWSecondC(phase==4&&!trusted&&d.cWReady);d.cW(lfsr,4'hf);phase<=5;endrule
  rule getE(phase==5&&trusted&&d.eBValid);if(d.eBResp!=2)begin $display("BSV STRESS FAIL E resp=%0d n=%0d",d.eBResp,n);$finish(1);end d.eBReady;n<=n+1;phase<=0;endrule
  rule getC(phase==5&&!trusted&&d.cBValid);if(d.cBResp!=2)begin $display("BSV STRESS FAIL C resp=%0d n=%0d",d.cBResp,n);$finish(1);end d.cBReady;n<=n+1;phase<=0;endrule
  rule done(n==10000);$display("BSV AXI RANDOM PASS seed=1592594996 transactions=%0d",n);$finish(0);endrule
endmodule
endpackage
