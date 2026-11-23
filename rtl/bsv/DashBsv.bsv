package DashBsv;

import FIFO  :: *;
import FIFOF :: *;

typedef enum {
  Idle,
  CActive,
  EActive,
  ECFeed,
  Quiesce,
  Clear,
  Fault
} DState deriving (Bits, Eq, FShow);

typedef enum {
  Trusted,
  Untrusted,
  ControlledFeed
} DMode deriving (Bits, Eq, FShow);

typedef struct {
  Bit#(8)  addr;
  Bit#(32) data;
  Bit#(4)  strb;
} Wr deriving (Bits, Eq);

typedef struct {
  Bit#(32) data;
  Bool     ok;
} Rd deriving (Bits, Eq);

interface DashAdapter;
  method Bool configReady;
  method Action configure(Bit#(32) x);
  method Action start;
  method Action abort;
  method Action clear;

  method Bool busy;
  method Bool done;
  method Bool clearDone;
  method Bool error;
  method Action injectError;
  method Action injectClearHang;

  method Bool inReady;
  method Bool clearPending;
  method Action acceptInput(Bit#(32) x, Bit#(4) s, Bool last);

  method Bool outValid;
  method Bit#(32) outputData;
  method Action outputTaken;
endinterface

interface DashAxi;
  method Bool cAwReady;
  method Action cAw(Bit#(8) a);
  method Bool cWReady;
  method Action cW(Bit#(32) d, Bit#(4) s);
  method Bool cBValid;
  method Bit#(2) cBResp;
  method Action cBReady;

  method Bool cArReady;
  method Action cAr(Bit#(8) a);
  method Bool cRValid;
  method Bit#(32) cRData;
  method Bit#(2) cRResp;
  method Action cRReady;

  method Bool eAwReady;
  method Action eAw(Bit#(8) a);
  method Bool eWReady;
  method Action eW(Bit#(32) d, Bit#(4) s);
  method Bool eBValid;
  method Bit#(2) eBResp;
  method Action eBReady;

  method Bool eArReady;
  method Action eAr(Bit#(8) a);
  method Bool eRValid;
  method Bit#(32) eRData;
  method Bit#(2) eRResp;
  method Action eRReady;

  method DState state;
  method Bool cMayAccess;
  method Bool fault;
endinterface

module mkDashDummy(DashAdapter);
  Reg#(Bit#(32)) cfg       <- mkReg(0);
  Reg#(Bit#(32)) acc       <- mkReg(0);
  Reg#(Bit#(8))  delay     <- mkReg(0);
  Reg#(Bit#(8))  clearCnt  <- mkReg(0);

  Reg#(Bool) run       <- mkReg(False);
  Reg#(Bool) lastSeen  <- mkReg(False);
  Reg#(Bool) clearing  <- mkReg(False);
  Reg#(Bool) clearReq  <- mkReg(False);
  Reg#(Bool) clearHang <- mkReg(False);
  Reg#(Bool) killReq   <- mkReg(False);
  Reg#(Bool) outValidR <- mkReg(False);
  Reg#(Bool) doneR     <- mkReg(False);
  Reg#(Bool) clearDoneR <- mkReg(False);
  Reg#(Bool) errorR    <- mkReg(False);
  Reg#(Bool) injectReq <- mkReg(False);
  Reg#(Bit#(32)) outDataR <- mkReg(0);

  rule countDelay (run && lastSeen && delay != 0 && !outValidR &&
                   !clearReq && !clearing);
    delay <= delay - 1;
  endrule

  rule finishOperation (run && lastSeen && delay == 0 && !outValidR &&
                        !clearReq && !clearing);
    outDataR <= acc + cfg;
    outValidR <= True;
    doneR <= True;
  endrule

  rule startClear (clearReq && !clearing);
    clearReq <= False;
    clearing <= True;
    clearDoneR <= False;
    clearCnt <= 1;
    run <= False;
    outValidR <= False;
    lastSeen <= False;
  endrule

  rule finishClear (clearing && !clearReq && clearCnt == 0 && !clearHang);
    clearing <= False;
    clearDoneR <= True;
    doneR <= False;
    errorR <= False;
    acc <= 0;
    cfg <= 0;
    lastSeen <= False;
  endrule

  rule countClear (clearing && !clearReq && clearCnt != 0);
    clearCnt <= clearCnt - 1;
  endrule

  method Bool configReady = !run && !clearing;

  method Action configure(Bit#(32) x) if (!run && !clearing);
    cfg <= x;
  endmethod

  method Action start if (!run && !clearing);
    run <= True;
    killReq <= False;
    lastSeen <= False;
    delay <= 0;
    doneR <= False;
  endmethod

  method Action abort;
    killReq <= True;
  endmethod

  method Action clear;
    clearReq <= True;
  endmethod

  method Bool busy = run && !doneR && !killReq;
  method Bool done = doneR;
  method Bool clearDone = clearDoneR;
  method Bool error = errorR || injectReq;

  method Action injectError;
    injectReq <= True;
  endmethod

  method Action injectClearHang;
    clearHang <= True;
  endmethod

  method Bool inReady = run && !doneR && !outValidR && !killReq && !lastSeen;
  method Bool clearPending = clearReq || clearing;

  method Action acceptInput(Bit#(32) x, Bit#(4) s, Bool last)
      if (run && !outValidR);
    acc <= acc + x;
    if (last) begin
      lastSeen <= True;
      delay <= 3;
    end
  endmethod

  method Bool outValid = outValidR && !killReq;
  method Bit#(32) outputData = outDataR;

  method Action outputTaken if (outValidR && !killReq);
    outValidR <= False;
  endmethod
endmodule

(* descending_urgency = "feedInput, cInputWrite, eInputWrite" *)
module mkDashBsv#(DashAdapter a)(DashAxi);
  Bit#(2) okayResp = 0;
  Bit#(2) slvErr   = 2;

  Bit#(8) statusA  = 0;
  Bit#(8) requestA = 4;
  Bit#(8) configA  = 8;
  Bit#(8) inputA   = 12;
  Bit#(8) resultA  = 16;
  Bit#(8) controlA = 20;
  Bit#(8) lengthA  = 24;
  Bit#(8) policyA  = 28;
  Bit#(8) timeoutA = 32;
  Bit#(8) errorA   = 36;
  Bit#(8) recoverA = 40;

  Reg#(DState) st   <- mkReg(Idle);
  Reg#(DState) next <- mkReg(Idle);
  Reg#(DMode)  mode <- mkReg(Trusted);

  Reg#(Bool) cAccess      <- mkReg(False);
  Reg#(Bool) cResultOk    <- mkReg(False);
  Reg#(Bool) graceful     <- mkReg(True);
  Reg#(Bool) active       <- mkReg(False);
  Reg#(Bool) doneR        <- mkReg(False);
  Reg#(Bool) resultValid  <- mkReg(False);
  Reg#(Bool) inputError   <- mkReg(False);
  Reg#(Bool) faultR       <- mkReg(False);

  Reg#(Bit#(32)) cfg    <- mkReg(0);
  Reg#(Bit#(32)) result <- mkReg(0);
  Reg#(Bit#(16)) limit  <- mkReg(0);
  Reg#(Bit#(16)) count  <- mkReg(0);
  Reg#(Bit#(16)) timeout <- mkReg(100);
  Reg#(Bit#(16)) timer   <- mkReg(0);

  Reg#(Bool) inputPending <- mkReg(False);
  Reg#(Bool) inputFromC   <- mkReg(False);
  Reg#(Bit#(32)) inputData <- mkReg(0);
  Reg#(Bit#(4))  inputStrb <- mkReg(0);
  Reg#(Bool) inputLast <- mkReg(False);

  Reg#(Bool) cAwValid <- mkReg(False);
  Reg#(Bit#(8)) cAwData <- mkReg(0);
  Reg#(Bool) cWValid <- mkReg(False);
  Reg#(Bit#(32)) cWData <- mkReg(0);
  Reg#(Bit#(4)) cWStrb <- mkReg(0);

  Reg#(Bool) eAwValid <- mkReg(False);
  Reg#(Bit#(8)) eAwData <- mkReg(0);
  Reg#(Bool) eWValid <- mkReg(False);
  Reg#(Bit#(32)) eWData <- mkReg(0);
  Reg#(Bit#(4)) eWStrb <- mkReg(0);

  Reg#(Bool) cBValidR <- mkReg(False);
  Reg#(Bit#(2)) cBRespR <- mkReg(okayResp);
  Reg#(Bool) eBValidR <- mkReg(False);
  Reg#(Bit#(2)) eBRespR <- mkReg(okayResp);

  Reg#(Bool) cArPending <- mkReg(False);
  Reg#(Bit#(8)) cArData <- mkReg(0);
  Reg#(Bool) eArPending <- mkReg(False);
  Reg#(Bit#(8)) eArData <- mkReg(0);
  Reg#(Bool) cRValidR <- mkReg(False);
  Reg#(Bit#(32)) cRDataR <- mkReg(0);
  Reg#(Bit#(2)) cRRespR <- mkReg(okayResp);
  Reg#(Bool) eRValidR <- mkReg(False);
  Reg#(Bit#(32)) eRDataR <- mkReg(0);
  Reg#(Bit#(2)) eRRespR <- mkReg(okayResp);

  function Bool fullStrobe(Bit#(4) s);
    return s == 4'hf;
  endfunction

  function Bool validAddress(Bit#(8) x);
    return x <= 40 && x[1:0] == 0;
  endfunction

  function Bit#(32) statusValue;
    return {22'b0, pack(mode), pack(st), pack(faultR), pack(inputError),
            pack(cAccess), pack(doneR), pack(active)};
  endfunction

  function Rd readRegister(Bit#(8) x, Bool fromC);
    Bit#(32) data = 0;
    Bool ok = True;

    case (x)
      statusA: data = statusValue;
      configA: data = cfg;
      resultA: begin
        if (!fromC || cResultOk)
          data = resultValid ? result : 0;
        else
          ok = False;
      end
      lengthA: data = zeroExtend(limit);
      policyA: data = {28'b0, pack(graceful), pack(cResultOk), pack(mode)};
      timeoutA: data = zeroExtend(timeout);
      errorA: data = {30'b0, pack(inputError), pack(faultR)};
      default: ok = False;
    endcase

    return Rd { data: data, ok: ok };
  endfunction

  rule clearStart (st == Clear && timer == 0 && !a.clearPending);
    a.clear;
    timer <= 1;
  endrule

  rule clearRule (st == Clear && timer != 0);
    if (a.clearDone) begin
      st <= next;
      timer <= 0;
      count <= 0;
      active <= False;
      doneR <= False;
      resultValid <= False;
    end
    else if (timer >= timeout) begin
      st <= Fault;
      faultR <= True;
      cAccess <= False;
      timer <= 0;
    end
    else begin
      timer <= timer + 1;
    end
  endrule

  rule quiesce (st == Quiesce);
    cAccess <= False;
    active <= False;
    resultValid <= False;
    next <= Idle;
    st <= Clear;
  endrule

  rule collect (a.outValid && st != Fault && st != Clear && st != Quiesce);
    result <= a.outputData;
    resultValid <= True;
    a.outputTaken;
  endrule

  rule observe (a.done && st != Clear && st != Quiesce);
    doneR <= True;
    active <= False;
  endrule

  rule adapterFault (a.error && st != Fault && st != Clear &&
                     st != Quiesce && !a.done && !a.outValid &&
                     !cAwValid && !cWValid && !eAwValid && !eWValid);
    st <= Fault;
    faultR <= True;
    cAccess <= False;
    active <= False;
    doneR <= False;
    resultValid <= False;
    inputPending <= False;
  endrule

  rule cInputWrite (cAwValid && cWValid && !cBValidR &&
                    cAwData == inputA && !(eAwValid && eWValid) &&
                    st != Clear && st != Quiesce);
    Bit#(32) data = cWData;
    Bool ok = (st == CActive || st == ECFeed) && active &&
              count < limit && !inputPending;

    cAwValid <= False;
    cWValid <= False;

    if (ok) begin
      inputPending <= True;
      inputFromC <= True;
      inputData <= data;
      inputStrb <= cWStrb;
      inputLast <= data[31] == 1;
    end

    cBRespR <= ok ? okayResp : slvErr;
    cBValidR <= True;
  endrule

  rule cStartWrite (cAwValid && cWValid && !cBValidR &&
                    cAwData == controlA && cWData[0] == 1 &&
                    cWData[2] == 0 && st == CActive && !active &&
                    !a.done && !a.clearPending &&
                    !(eAwValid && eWValid));
    cAwValid <= False;
    cWValid <= False;
    active <= True;
    a.start;
    cBRespR <= okayResp;
    cBValidR <= True;
  endrule

  rule cRejectControlWrite (cAwValid && cWValid && !cBValidR &&
                            cAwData == controlA &&
                            !(cWData[0] == 1 && cWData[2] == 0 &&
                              st == CActive && !active) &&
                            !(eAwValid && eWValid));
    cAwValid <= False;
    cWValid <= False;
    cBRespR <= slvErr;
    cBValidR <= True;
  endrule

  rule eInputWrite (eAwValid && eWValid && !eBValidR &&
                    eAwData == inputA && st != Clear && st != Quiesce);
    Bit#(32) data = eWData;
    Bool ok = (st == EActive || st == ECFeed) && active &&
              count < limit && !inputPending;

    eAwValid <= False;
    eWValid <= False;

    if (ok) begin
      inputPending <= True;
      inputFromC <= False;
      inputData <= data;
      inputStrb <= eWStrb;
      inputLast <= data[31] == 1;
    end

    eBRespR <= ok ? okayResp : slvErr;
    eBValidR <= True;
  endrule

  rule eAbortWrite (eAwValid && eWValid && !eBValidR &&
                    eAwData == controlA && eWData[2] == 1 &&
                    st != Quiesce && st != Clear);
    eAwValid <= False;
    eWValid <= False;
    st <= Quiesce;
    eBRespR <= okayResp;
    eBValidR <= True;
  endrule

  rule eStartWrite (eAwValid && eWValid && !eBValidR &&
                    eAwData == controlA && eWData[2] == 0 &&
                    st != Clear && st != Quiesce && !a.done &&
                    !a.clearPending);
    Bit#(32) data = eWData;
    Bool ok = (data[0] == 0) ||
              ((st == EActive || st == ECFeed) && !active);

    eAwValid <= False;
    eWValid <= False;

    if (ok && data[0] == 1) begin
      active <= True;
      a.start;
    end

    eBRespR <= ok ? okayResp : slvErr;
    eBValidR <= True;
  endrule

  rule feedInput (inputPending && active && a.inReady &&
                  !a.clearPending &&
                  ((inputFromC && (st == CActive || st == ECFeed)) ||
                   (!inputFromC && (st == EActive || st == ECFeed))));
    a.acceptInput(inputData, inputStrb, inputLast);
    inputPending <= False;
    count <= count + 4;
  endrule

  rule cWrite (cAwValid && cWValid && !cBValidR &&
               cAwData != inputA && cAwData != controlA &&
               st != Clear && st != Quiesce &&
               !(eAwValid && eWValid));
    Bit#(8) addr = cAwData;
    Bit#(32) data = cWData;
    Bool ok = validAddress(addr);

    cAwValid <= False;
    cWValid <= False;

    if (addr == requestA) begin
      if (!fullStrobe(cWStrb) || data[31:1] != 0)
        ok = False;
      else if (data[0] == 1 && st == Idle && mode == Untrusted && cAccess)
        next <= CActive;
      else if (data[0] == 0 && st == CActive)
        st <= Quiesce;
    end
    else if (addr == configA) begin
      if (!(st == CActive && mode == Untrusted && fullStrobe(cWStrb)))
        ok = False;
      else
        cfg <= data;
    end
    else if (addr == inputA || addr == controlA) begin
      ok = False;
    end
    else begin
      ok = False;
    end

    cBRespR <= ok ? okayResp : slvErr;
    cBValidR <= True;
  endrule

  rule eWrite (eAwValid && eWValid && !eBValidR &&
               eAwData != inputA && eAwData != controlA &&
               st != Clear && st != Quiesce);
    Bit#(8) addr = eAwData;
    Bit#(32) data = eWData;
    Bool ok = validAddress(addr);

    eAwValid <= False;
    eWValid <= False;

    if (addr == requestA) begin
      if (!fullStrobe(eWStrb))
        ok = False;
      else if (data[0] == 1 && st == Idle) begin
        next <= CActive;
        st <= Clear;
      end
      else if (data[1] == 1 && st == Idle) begin
        next <= (mode == ControlledFeed) ? ECFeed : EActive;
        st <= Clear;
      end
    end
    else if (addr == configA) begin
      if (!fullStrobe(eWStrb) || (st != EActive && st != ECFeed))
        ok = False;
      else
        cfg <= data;
    end
    else if (addr == inputA || addr == controlA) begin
      ok = False;
    end
    else if (addr == lengthA) begin
      if (!fullStrobe(eWStrb) || st != Idle)
        ok = False;
      else
        limit <= truncate(data);
    end
    else if (addr == policyA) begin
      if (!fullStrobe(eWStrb) || st != Idle)
        ok = False;
      else begin
        mode <= unpack(data[1:0]);
        cResultOk <= data[2] == 1;
        graceful <= data[3] == 1;
        cAccess <= data[1:0] != 0;
      end
    end
    else if (addr == timeoutA) begin
      if (!fullStrobe(eWStrb))
        ok = False;
      else
        timeout <= truncate(data);
    end
    else if (addr == errorA) begin
      if (!fullStrobe(eWStrb))
        ok = False;
      else if (data[0] == 1) begin
        faultR <= False;
        inputError <= False;
      end
    end
    else if (addr == recoverA) begin
      if (!fullStrobe(eWStrb) || data[0] != 1 || st != Fault)
        ok = False;
      else begin
        next <= Idle;
        st <= Clear;
      end
    end
    else begin
      ok = False;
    end

    eBRespR <= ok ? okayResp : slvErr;
    eBValidR <= True;
  endrule

  rule cRead (cArPending && !cRValidR);
    Rd q = readRegister(cArData, True);
    cRDataR <= q.data;
    cRRespR <= q.ok ? okayResp : slvErr;
    cRValidR <= True;
    cArPending <= False;
  endrule

  rule eRead (eArPending && !eRValidR);
    Rd q = readRegister(eArData, False);
    eRDataR <= q.data;
    eRRespR <= q.ok ? okayResp : slvErr;
    eRValidR <= True;
    eArPending <= False;
  endrule

  method Bool cAwReady = !cAwValid;
  method Action cAw(Bit#(8) x) if (!cAwValid);
    cAwData <= x;
    cAwValid <= True;
  endmethod

  method Bool cWReady = !cWValid;
  method Action cW(Bit#(32) d, Bit#(4) s) if (!cWValid);
    cWData <= d;
    cWStrb <= s;
    cWValid <= True;
  endmethod

  method Bool cBValid = cBValidR;
  method Bit#(2) cBResp = cBRespR;
  method Action cBReady if (cBValidR);
    cBValidR <= False;
  endmethod

  method Bool cArReady = !cArPending && !cRValidR;
  method Action cAr(Bit#(8) x) if (!cArPending && !cRValidR);
    cArData <= x;
    cArPending <= True;
  endmethod

  method Bool cRValid = cRValidR;
  method Bit#(32) cRData = cRDataR;
  method Bit#(2) cRResp = cRRespR;
  method Action cRReady if (cRValidR);
    cRValidR <= False;
  endmethod

  method Bool eAwReady = !eAwValid;
  method Action eAw(Bit#(8) x) if (!eAwValid);
    eAwData <= x;
    eAwValid <= True;
  endmethod

  method Bool eWReady = !eWValid;
  method Action eW(Bit#(32) d, Bit#(4) s) if (!eWValid);
    eWData <= d;
    eWStrb <= s;
    eWValid <= True;
  endmethod

  method Bool eBValid = eBValidR;
  method Bit#(2) eBResp = eBRespR;
  method Action eBReady if (eBValidR);
    eBValidR <= False;
  endmethod

  method Bool eArReady = !eArPending && !eRValidR;
  method Action eAr(Bit#(8) x) if (!eArPending && !eRValidR);
    eArData <= x;
    eArPending <= True;
  endmethod

  method Bool eRValid = eRValidR;
  method Bit#(32) eRData = eRDataR;
  method Bit#(2) eRResp = eRRespR;
  method Action eRReady if (eRValidR);
    eRValidR <= False;
  endmethod

  method DState state = st;
  method Bool cMayAccess = cAccess && (st == CActive || st == ECFeed) &&
                           st != Fault;
  method Bool fault = faultR;
endmodule

endpackage
