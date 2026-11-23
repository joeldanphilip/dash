package TbDashComplete;
import DashBsv::*;
module mkTbDashComplete(Empty);
 DashAdapter a<-mkDashDummy; DashAxi d<-mkDashBsv(a); Reg#(UInt#(8)) p<-mkReg(0); Reg#(UInt#(16)) cycles<-mkReg(0); Reg#(UInt#(8)) waitR<-mkReg(0); Reg#(UInt#(8)) checks<-mkReg(0);
 rule timeout; cycles<=cycles+1; if(cycles>500)begin $display("BSV FAIL timeout phase=%0d state=%0d",p,pack(d.state));$finish(1);end endrule
 rule policyAw(p==0&&d.eAwReady); d.eAw(8'd28); p<=1; endrule
 rule policyW(p==1&&d.eWReady); d.eW(32'h1,4'hf); p<=2; endrule
 rule policyResp(p==2&&d.eBValid); if(d.eBResp!=0)begin $display("BSV FAIL policy response");$finish(1);end d.eBReady;checks<=checks+1;p<=3;endrule
 rule length(p==3&&d.eAwReady&&d.eWReady); d.eAw(8'd24);d.eW(32'd16,4'hf);p<=4;endrule
 rule lengthResp(p==4&&d.eBValid); if(d.eBResp!=0)begin $display("BSV FAIL length response");$finish(1);end d.eBReady;checks<=checks+1;p<=5;endrule
 rule grantC(p==5&&d.eAwReady&&d.eWReady);d.eAw(8'd4);d.eW(32'd1,4'hf);p<=6;endrule
 rule grantResp(p==6&&d.eBValid);if(d.eBResp!=0)begin $display("BSV FAIL grant response");$finish(1);end d.eBReady;checks<=checks+1;p<=7;endrule
 rule waitC(p==7&&d.state==CActive);p<=8;endrule
 rule cStart(p==8&&d.cAwReady&&d.cWReady);d.cAw(8'd20);d.cW(32'd1,4'hf);p<=9;endrule
 rule cStartResp(p==9&&d.cBValid);if(d.cBResp!=0)begin $display("BSV FAIL C start response");$finish(1);end d.cBReady;checks<=checks+1;p<=10;endrule
 rule cInput(p==10&&d.cAwReady&&d.cWReady);d.cAw(8'd12);d.cW(32'h80000005,4'hf);p<=11;endrule
 rule cInputResp(p==11&&d.cBValid);if(d.cBResp!=0)begin $display("BSV FAIL C input response");$finish(1);end d.cBReady;checks<=checks+1;p<=12;endrule
 rule revoke(p==12&&d.eAwReady&&d.eWReady);d.eAw(8'd20);d.eW(32'd4,4'hf);p<=13;endrule
 rule revokeResp(p==13&&d.eBValid);if(d.eBResp!=0)begin $display("BSV FAIL revoke response");$finish(1);end d.eBReady;checks<=checks+1;p<=14;endrule
 rule waitIdle(p==14&&d.state==Idle);p<=15;endrule
 rule grantE(p==15&&d.eAwReady&&d.eWReady);d.eAw(8'd4);d.eW(32'd2,4'hf);p<=16;endrule
 rule grantEResp(p==16&&d.eBValid);if(d.eBResp!=0)begin $display("BSV FAIL E grant response");$finish(1);end d.eBReady;checks<=checks+1;p<=17;endrule
 rule waitE(p==17&&d.state==EActive);p<=18;endrule
 rule unauthorized(p==18&&d.cAwReady&&d.cWReady);d.cAw(8'd28);d.cW(32'd1,4'hf);p<=19;endrule
 rule unauthorizedResp(p==19&&d.cBValid);if(d.cBResp!=2)begin $display("BSV FAIL unauthorized response=%0d",d.cBResp);$finish(1);end d.cBReady;checks<=checks+1;p<=20;endrule
 rule eStart(p==20&&d.eAwReady&&d.eWReady);d.eAw(8'd20);d.eW(32'd1,4'hf);p<=21;endrule
 rule eStartResp(p==21&&d.eBValid);if(d.eBResp!=0)begin $display("BSV FAIL E start response");$finish(1);end d.eBReady;checks<=checks+1;p<=22;endrule
 rule eInput(p==22&&d.eAwReady&&d.eWReady);d.eAw(8'd12);d.eW(32'h80000003,4'hf);p<=23;endrule
 rule eInputResp(p==23&&d.eBValid);if(d.eBResp!=0)begin $display("BSV FAIL E input response");$finish(1);end d.eBReady;checks<=checks+1;p<=24;endrule
 rule resultWait(p==24&&waitR<8); waitR<=waitR+1; endrule
 rule resultRead(p==24&&waitR==8&&d.eArReady);d.eAr(8'd16);p<=25;endrule
 rule resultCheck(p==25&&d.eRValid);if(d.eRResp!=0||d.eRData!=32'h80000003)begin $display("BSV FAIL result data=%h resp=%0d",d.eRData,d.eRResp);$finish(1);end d.eRReady;$display("TRACE scenario=revocation ownership=C_to_E c_unauthorized=SLVERR e_result=80000003 checks=%0d",checks);$display("DASH BSV transaction regression PASS checks=%0d",checks);$finish(0);endrule
endmodule
endpackage
