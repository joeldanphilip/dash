package DashController;
import FIFO::*;
import FIFOF::*;

typedef enum { DIdle, CActive, EActive, ECFeed, Quiesce, Clear, Fault } DashState deriving (Bits, Eq, FShow);
typedef enum { TrustedMode, UntrustedMode, FeedMode } DashMode deriving (Bits, Eq, FShow);

interface DashAdapter;
  method Action configure(Bit#(32) x);
  method Action start;
  method Action abort;
  method Action clear;
  method Bool busy;
  method Bool done;
  method Bool clearDone;
  method Bool error;
  method Bool inReady;
  method Action acceptInput(Bit#(32) x, Bit#(4) strb, Bool last);
  method Bool outValid;
  method Bit#(32) outputData;
  method Bool outLast;
  method Action outputTaken;
endinterface

interface DashController;
  method Action setPolicy(DashMode m, Bool resultVisible, Bool graceful);
  method Action setLength(Bit#(16) n);
  method Action setTimeout(Bit#(16) n);
  method Action grantC;
  method Action grantE;
  method Action cRequest;
  method Action cRelease;
  method Action start(Bool fromC);
  method Action abort;
  method Action pushInput(Bool fromC, Bit#(32) d, Bit#(4) s, Bool last);
  method Bool cMayAccess;
  method DashState state;
  method Bit#(16) inputCount;
  method Bool done;
  method Bool fault;
endinterface

module mkDashController#(DashAdapter adapter)(DashController);
  Reg#(DashState) st <- mkReg(DIdle);
  Reg#(DashState) grantAfterClear <- mkReg(DIdle);
  Reg#(DashMode) mode <- mkReg(TrustedMode);
  Reg#(Bool) cAccess <- mkReg(False);
  Reg#(Bool) resultVisible <- mkReg(False);
  Reg#(Bool) graceful <- mkReg(True);
  Reg#(Bit#(16)) limit <- mkReg(0);
  Reg#(Bit#(16)) count <- mkReg(0);
  Reg#(Bit#(16)) timeout <- mkReg(100);
  Reg#(Bit#(16)) timer <- mkReg(0);
  Reg#(Bool) opActive <- mkReg(False);
  Reg#(Bool) complete <- mkReg(False);
  Reg#(Bool) err <- mkReg(False);

  // Explicit rule guards make transfer atomic: no request can grant until the
  // adapter has acknowledged clearing. E-side actions are intended to be
  // called by the trusted frontend, whose priority is external to this core.
  rule finishClear (st == Clear && adapter.clearDone);
    st <= grantAfterClear; count <= 0; timer <= 0; opActive <= False; complete <= False;
  endrule
  rule clearTimeout (st == Clear && !adapter.clearDone && timer >= timeout);
    st <= Fault; err <= True; cAccess <= False; timer <= 0;
  endrule
  rule countTimer (st == Clear && !adapter.clearDone && timer < timeout);
    timer <= timer + 1;
  endrule

  method Action setPolicy(DashMode m, Bool rv, Bool g) if (st == DIdle);
    mode <= m; resultVisible <= rv; graceful <= g; cAccess <= (m != TrustedMode);
  endmethod
  method Action setLength(Bit#(16) n) if (st == DIdle);
    limit <= n;
  endmethod
  method Action setTimeout(Bit#(16) n) if (st == DIdle);
    timeout <= n;
  endmethod
  method Action grantC if (st == DIdle && mode != TrustedMode);
    grantAfterClear <= CActive; st <= Clear; adapter.clear;
  endmethod
  method Action grantE if (st == DIdle);
    grantAfterClear <= EActive; st <= Clear; adapter.clear;
  endmethod
  method Action cRequest if (st == DIdle && cAccess && mode == UntrustedMode);
    grantAfterClear <= CActive; st <= Clear; adapter.clear;
  endmethod
  method Action cRelease if (st == CActive);
    cAccess <= False; st <= Quiesce;
  endmethod
  method Action start(Bool fromC);
    if (!opActive && ((fromC && st == CActive && mode == UntrustedMode) || (!fromC && (st == EActive || st == ECFeed)))) begin
      opActive <= True; complete <= False; adapter.start;
    end
  endmethod
  method Action abort if (st == EActive || st == ECFeed || st == CActive);
    adapter.abort; opActive <= False; st <= Clear; grantAfterClear <= DIdle; adapter.clear;
  endmethod
  method Action pushInput(Bool fromC, Bit#(32) d, Bit#(4) s, Bool last);
    if (opActive && adapter.inReady && count < limit && ((fromC && (st == CActive || st == ECFeed)) || (!fromC && st == EActive))) begin
      adapter.acceptInput(d,s,last); count <= count + 4;
    end
  endmethod
  method Bool cMayAccess = cAccess && (st == CActive || st == ECFeed) && st != Fault;
  method DashState state = st;
  method Bit#(16) inputCount = count;
  method Bool done = complete || adapter.done;
  method Bool fault = err || adapter.error;
endmodule
endpackage
