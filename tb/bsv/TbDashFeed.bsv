package TbDashFeed;
import DashBsv::*;
module mkTbDashFeed(Empty);
 DashAdapter a<-mkDashDummy; DashAxi d<-mkDashBsv(a); Reg#(UInt#(8)) p<-mkReg(0); Reg#(UInt#(8)) t<-mkReg(0); Reg#(UInt#(8)) checks<-mkReg(0);
 rule timeout; t<=t+1;if(t>200)begin $display("BSV FEED FAIL timeout phase=%0d",p);$finish(1);end endrule
 rule pol(p==0&&d.eAwReady);d.eAw(28);p<=1;endrule rule polW(p==1&&d.eWReady);d.eW(32'd2,4'hf);p<=2;endrule
 rule polR(p==2&&d.eBValid);if(d.eBResp!=0)$finish(1);d.eBReady;checks<=checks+1;p<=3;endrule
 rule len(p==3&&d.eAwReady&&d.eWReady);d.eAw(24);d.eW(16,4'hf);p<=4;endrule rule lenR(p==4&&d.eBValid);if(d.eBResp!=0)$finish(1);d.eBReady;checks<=checks+1;p<=5;endrule
 rule grant(p==5&&d.eAwReady&&d.eWReady);d.eAw(4);d.eW(2,4'hf);p<=6;endrule rule grantR(p==6&&d.eBValid);if(d.eBResp!=0)$finish(1);d.eBReady;checks<=checks+1;p<=7;endrule
 rule waitFeed(p==7&&d.state==ECFeed);p<=8;endrule
 rule start(p==8&&d.eAwReady&&d.eWReady);d.eAw(20);d.eW(1,4'hf);p<=9;endrule rule startR(p==9&&d.eBValid);if(d.eBResp!=0)$finish(1);d.eBReady;checks<=checks+1;p<=10;endrule
 rule feed(p==10&&d.cAwReady&&d.cWReady);d.cAw(12);d.cW(32'h80000007,4'hf);p<=11;endrule rule feedR(p==11&&d.cBValid);if(d.cBResp!=0)$finish(1);d.cBReady;checks<=checks+1;p<=12;endrule
 rule badStart(p==12&&d.cAwReady&&d.cWReady);d.cAw(20);d.cW(1,4'hf);p<=13;endrule rule badStartR(p==13&&d.cBValid);if(d.cBResp!=2)$finish(1);d.cBReady;checks<=checks+1;p<=14;endrule
 rule badPolicy(p==14&&d.cAwReady&&d.cWReady);d.cAw(28);d.cW(1,4'hf);p<=15;endrule rule badPolicyR(p==15&&d.cBValid);if(d.cBResp!=2)$finish(1);d.cBReady;checks<=checks+1;p<=16;endrule
 rule waitOut(p==16&&d.eArReady);d.eAr(16);p<=17;endrule
 rule result(p==17&&d.eRValid);if(d.eRResp!=0||d.eRData!=32'h80000007)begin $display("BSV FEED FAIL result=%h",d.eRData);$finish(1);end d.eRReady;$display("TRACE scenario=controlled_feed mode=E_C_FEED c_input=accepted c_start=SLVERR c_policy=SLVERR e_result=80000007 checks=%0d",checks);$finish(0);endrule
endmodule
endpackage
