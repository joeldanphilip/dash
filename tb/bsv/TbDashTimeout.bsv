package TbDashTimeout;
import DashBsv::*;
module mkNoClearAdapter(DashAdapter);
 Reg#(Bool) cd<-mkReg(False); Reg#(Bool) err<-mkReg(False); Reg#(Bool) busyR<-mkReg(False); Reg#(Bool) doneR<-mkReg(False); Reg#(Bool) inR<-mkReg(False); Reg#(Bool) outR<-mkReg(False);
 method Bool configReady=True; method Action configure(Bit#(32)x); noAction; endmethod
 method Action start; noAction; endmethod method Action abort; noAction; endmethod method Action clear; noAction; endmethod
 method Bool busy=busyR; method Bool done=doneR; method Bool clearDone=cd; method Bool error=err; method Action injectError; err<=True; endmethod method Action injectClearHang; noAction; endmethod method Bool inReady=inR;
 method Bool clearPending=False; method Action acceptInput(Bit#(32)x,Bit#(4)s,Bool last); noAction; endmethod
 method Bool outValid=outR; method Bit#(32) outputData=0; method Action outputTaken; noAction; endmethod
endmodule
module mkTbDashTimeout(Empty);
 DashAdapter a<-mkNoClearAdapter; DashAxi d<-mkDashBsv(a); Reg#(UInt#(8)) p<-mkReg(0); Reg#(UInt#(12)) t<-mkReg(0);
 rule timeout; t<=t+1;if(t>200)begin $display("BSV TIMEOUT FAIL timeout phase=%0d state=%0d",p,pack(d.state));$finish(1);end endrule
 rule aw(p==0&&d.eAwReady);d.eAw(32);p<=1;endrule
 rule w(p==1&&d.eWReady);d.eW(3,4'hf);p<=2;endrule
 rule br(p==2&&d.eBValid);if(d.eBResp!=0)$finish(1);d.eBReady;p<=3;endrule
 rule reqAw(p==3&&d.eAwReady);d.eAw(4);p<=4;endrule
 rule reqW(p==4&&d.eWReady);d.eW(1,4'hf);p<=5;endrule
 rule reqR(p==5&&d.eBValid);if(d.eBResp!=0)$finish(1);d.eBReady;p<=6;endrule
 rule seeClear(p==6&&d.state==Clear);p<=7;endrule
 rule fault(p==7&&d.fault);if(d.cMayAccess)$finish(1);$display("BSV TIMEOUT PASS clear_to_fault=1 c_access=0");$finish(0);endrule
endmodule
endpackage
