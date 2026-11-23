package TbDash;
import DashController::*;
module mkTbDash(Empty);
  // Compile-time smoke harness: a real adapter is supplied by integration.
  // The native SV dummy adapter is the executable end-to-end reference.
  Reg#(Bool) finished <- mkReg(False);
  rule stop (finished);
    $display("DASH BSV controller compile smoke complete"); $finish(0);
  endrule
endmodule
endpackage
