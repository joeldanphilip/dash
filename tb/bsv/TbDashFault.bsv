package TbDashFault;
import DashBsv::*;
module mkTbDashFault(Empty);
  DashAdapter a<-mkDashDummy; DashAxi d<-mkDashBsv(a); Reg#(UInt#(8)) p<-mkReg(0); Reg#(UInt#(12)) t<-mkReg(0);
  rule timeout; t<=t+1;if(t>100)begin $display("BSV FAULT FAIL timeout");$finish(1);end endrule
  rule inject(p==0); a.injectError;p<=1;endrule
  rule check(p==1&&d.fault); if(d.cMayAccess)begin $display("BSV FAULT FAIL C access");$finish(1);end $display("BSV FAULT PASS fault_closed=1");$finish(0);endrule
endmodule
endpackage
