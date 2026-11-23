package DashVerilogTop;
import DashBsv::*;
(* synthesize *)
module mkDashTop(DashAxi);
  DashAdapter a <- mkDashDummy;
  DashAxi d <- mkDashBsv(a);
  return d;
endmodule
endpackage
