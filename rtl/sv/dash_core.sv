`default_nettype none

module dash_core #(
  parameter int DATA_W = 32,
  parameter int ADDR_W = 8,
  parameter int LEN_W  = 16,
  parameter int TIME_W = 16
) (
  input  logic                   clk,
  input  logic                   rst_n,

  input  logic                   c_awvalid,
  output logic                   c_awready,
  input  logic [ADDR_W-1:0]      c_awaddr,
  input  logic                   c_wvalid,
  output logic                   c_wready,
  input  logic [DATA_W-1:0]      c_wdata,
  input  logic [DATA_W/8-1:0]    c_wstrb,
  output logic                   c_bvalid,
  input  logic                   c_bready,
  input  logic                   c_arvalid,
  output logic                   c_arready,
  input  logic [ADDR_W-1:0]      c_araddr,
  output logic                   c_rvalid,
  input  logic                   c_rready,
  output logic [DATA_W-1:0]      c_rdata,
  output logic [1:0]             c_bresp,
  output logic [1:0]             c_rresp,

  input  logic                   e_awvalid,
  output logic                   e_awready,
  input  logic [ADDR_W-1:0]      e_awaddr,
  input  logic                   e_wvalid,
  output logic                   e_wready,
  input  logic [DATA_W-1:0]      e_wdata,
  input  logic [DATA_W/8-1:0]    e_wstrb,
  output logic                   e_bvalid,
  input  logic                   e_bready,
  input  logic                   e_arvalid,
  output logic                   e_arready,
  input  logic [ADDR_W-1:0]      e_araddr,
  output logic                   e_rvalid,
  input  logic                   e_rready,
  output logic [DATA_W-1:0]      e_rdata,
  output logic [1:0]             e_bresp,
  output logic [1:0]             e_rresp,

  output logic                   acc_start,
  output logic                   acc_abort,
  output logic                   acc_clear,
  output logic [DATA_W-1:0]      acc_config,
  output logic                   acc_config_valid,
  input  logic                   acc_config_ready,
  input  logic                   acc_busy,
  input  logic                   acc_done,
  input  logic                   acc_clear_done,
  input  logic                   acc_error,
  output logic [DATA_W-1:0]      acc_data_in,
  output logic                   acc_data_valid,
  output logic [DATA_W/8-1:0]    acc_data_strb,
  output logic                   acc_data_last,
  input  logic                   acc_data_ready,
  input  logic [DATA_W-1:0]      acc_data_out,
  input  logic                   acc_out_valid,
  output logic                   acc_out_ready,
  input  logic                   acc_out_last
);

  localparam logic [1:0] OKAY   = 2'b00;
  localparam logic [1:0] SLVERR = 2'b10;

  localparam logic [2:0] IDLE     = 3'd0;
  localparam logic [2:0] C_ACTIVE = 3'd1;
  localparam logic [2:0] E_ACTIVE = 3'd2;
  localparam logic [2:0] E_C_FEED = 3'd3;
  localparam logic [2:0] QUIESCE  = 3'd4;
  localparam logic [2:0] CLEAR    = 3'd5;
  localparam logic [2:0] FAULT    = 3'd6;

  localparam logic [1:0] M_TRUSTED   = 2'd0;
  localparam logic [1:0] M_UNTRUSTED = 2'd1;
  localparam logic [1:0] M_FEED      = 2'd2;

  localparam logic [7:0] A_STATUS  = 8'h00;
  localparam logic [7:0] A_REQUEST = 8'h04;
  localparam logic [7:0] A_CONFIG  = 8'h08;
  localparam logic [7:0] A_INPUT   = 8'h0c;
  localparam logic [7:0] A_RESULT  = 8'h10;
  localparam logic [7:0] A_CONTROL = 8'h14;
  localparam logic [7:0] A_LENGTH  = 8'h18;
  localparam logic [7:0] A_POLICY  = 8'h1c;
  localparam logic [7:0] A_TIMEOUT = 8'h20;
  localparam logic [7:0] A_ERROR   = 8'h24;
  localparam logic [7:0] A_RECOVER = 8'h28;

  logic [2:0] state;
  logic [2:0] next_grant;
  logic [1:0] mode;

  logic                 c_access;
  logic                 c_result_ok;
  logic                 graceful;
  logic [DATA_W-1:0]    cfg;
  logic [DATA_W-1:0]    result_reg;
  logic [LEN_W-1:0]     input_limit;
  logic [LEN_W-1:0]     input_count;
  logic [TIME_W-1:0]    timeout_cfg;
  logic [TIME_W-1:0]    timer;

  logic busy;
  logic done;
  logic result_valid;
  logic op_active;
  logic input_error;
  logic fault;

  logic              input_pending;
  logic              input_pending_last;
  logic [DATA_W-1:0] input_pending_data;
  logic [DATA_W/8-1:0] input_pending_strb;

  logic              c_aw_hold;
  logic              e_aw_hold;
  logic              c_w_hold;
  logic              e_w_hold;
  logic [ADDR_W-1:0] c_aw_q;
  logic [ADDR_W-1:0] e_aw_q;
  logic [DATA_W-1:0] c_w_q;
  logic [DATA_W-1:0] e_w_q;
  logic [DATA_W/8-1:0] c_ws_q;
  logic [DATA_W/8-1:0] e_ws_q;

  assign c_awready = !c_aw_hold && !c_bvalid && rst_n;
  assign c_wready  = !c_w_hold  && !c_bvalid && rst_n;
  assign e_awready = !e_aw_hold && !e_bvalid && rst_n;
  assign e_wready  = !e_w_hold  && !e_bvalid && rst_n;
  assign c_arready = !c_rvalid && rst_n;
  assign e_arready = !e_rvalid && rst_n;

  assign acc_out_ready = (state != FAULT) && (c_access || state == E_ACTIVE);
  assign acc_clear = (state == CLEAR);
  assign acc_config = cfg;
  assign acc_data_valid = input_pending && op_active &&
                          (state == C_ACTIVE || state == E_C_FEED ||
                           state == E_ACTIVE);
  assign acc_data_in = input_pending_data;
  assign acc_data_strb = input_pending_strb;
  assign acc_data_last = input_pending_last;

  function automatic logic full_word(input logic [DATA_W/8-1:0] s);
    full_word = &s;
  endfunction

  function automatic logic addr_valid(input logic [7:0] a);
    addr_valid = (a <= A_RECOVER) && (a[1:0] == 2'b00);
  endfunction

  task automatic rd_response(input logic is_c, input logic [7:0] a);
    logic [DATA_W-1:0] d;
    logic              ok;

    begin
      d = '0;
      ok = 1'b1;

      case (a)
        A_STATUS: begin
          d = {{(DATA_W-10){1'b0}}, mode, state[2:0], fault,
               input_error, c_access, done, (busy || acc_busy)};
        end
        A_CONFIG: begin
          d = cfg;
        end
        A_RESULT: begin
          if (!is_c || c_result_ok)
            d = result_valid ? result_reg : '0;
          else
            ok = 1'b0;
        end
        A_LENGTH: begin
          d = {{(DATA_W-LEN_W){1'b0}}, input_limit};
        end
        A_POLICY: begin
          d = {28'b0, graceful, c_result_ok, mode};
        end
        A_TIMEOUT: begin
          d = {{(DATA_W-TIME_W){1'b0}}, timeout_cfg};
        end
        A_ERROR: begin
          d = {30'b0, fault, input_error};
        end
        default: begin
          ok = 1'b0;
        end
      endcase

      if (is_c) begin
        c_rdata <= d;
        c_rresp <= ok ? OKAY : SLVERR;
        c_rvalid <= 1'b1;
      end
      else begin
        e_rdata <= d;
        e_rresp <= ok ? OKAY : SLVERR;
        e_rvalid <= 1'b1;
      end
    end
  endtask

  task automatic do_write(
    input logic                is_c,
    input logic [7:0]          a,
    input logic [DATA_W-1:0]   d,
    input logic [DATA_W/8-1:0] s
  );
    logic ok;

    begin
      ok = 1'b1;

      if (!addr_valid(a)) begin
        ok = 1'b0;
      end
      else begin
        case (a)
          A_REQUEST: begin
            if (is_c) begin
              if (!full_word(s) || d[31:1] != 0)
                ok = 1'b0;
              else if (d[0] && state == IDLE && mode == M_UNTRUSTED && c_access)
                next_grant <= C_ACTIVE;
              else if (!d[0] && state == C_ACTIVE) begin
                state <= QUIESCE;
                next_grant <= IDLE;
              end
            end
            else if (!full_word(s)) begin
              ok = 1'b0;
            end
            else if (d[0] && state == IDLE) begin
              next_grant <= C_ACTIVE;
              state <= CLEAR;
            end
            else if (d[1] && state == IDLE) begin
              next_grant <= (mode == M_FEED) ? E_C_FEED : E_ACTIVE;
              state <= CLEAR;
            end
          end

          A_CONFIG: begin
            if (is_c ? (state != C_ACTIVE || mode != M_UNTRUSTED ||
                        !full_word(s)) :
                     (!full_word(s) ||
                      (state != E_ACTIVE && state != E_C_FEED)) ||
                     !acc_config_ready)
              ok = 1'b0;
            else begin
              cfg <= d;
              acc_config_valid <= 1'b1;
            end
          end

          A_INPUT: begin
            if (is_c ? !(state == C_ACTIVE || state == E_C_FEED) :
                     !(state == E_ACTIVE) || !op_active || input_pending ||
                     input_count >= input_limit)
              ok = 1'b0;
            else if (input_count + LEN_W'(DATA_W/8) > input_limit) begin
              input_error <= 1'b1;
              ok = 1'b0;
            end
            else begin
              input_pending <= 1'b1;
              input_pending_data <= d;
              input_pending_strb <= s;
              input_pending_last <= d[31];
            end
          end

          A_CONTROL: begin
            if (is_c) begin
              if (state != C_ACTIVE || d[2] ||
                  (mode != M_UNTRUSTED && d[0]))
                ok = 1'b0;
              else if (d[0] && !op_active) begin
                op_active <= 1'b1;
                busy <= 1'b1;
                acc_start <= 1'b1;
              end
              else if (d[1] && op_active) begin
                op_active <= 1'b0;
              end
            end
            else begin
              if (d[2]) begin
                state <= QUIESCE;
                next_grant <= IDLE;
              end
              if (d[0] && (state == E_ACTIVE || state == E_C_FEED) &&
                  !op_active) begin
                op_active <= 1'b1;
                busy <= 1'b1;
                acc_start <= 1'b1;
              end
            end
          end

          A_LENGTH: begin
            if (is_c || !full_word(s))
              ok = 1'b0;
            else
              input_limit <= d[LEN_W-1:0];
          end

          A_POLICY: begin
            if (is_c || !full_word(s) || state != IDLE)
              ok = 1'b0;
            else begin
              mode <= d[1:0];
              c_result_ok <= d[2];
              graceful <= d[3];
              c_access <= d[1:0] != M_TRUSTED;
            end
          end

          A_TIMEOUT: begin
            if (is_c || !full_word(s))
              ok = 1'b0;
            else
              timeout_cfg <= d[TIME_W-1:0];
          end

          A_ERROR: begin
            if (is_c || !full_word(s))
              ok = 1'b0;
            else if (d[0]) begin
              fault <= 1'b0;
              input_error <= 1'b0;
            end
          end

          A_RECOVER: begin
            if (is_c || !full_word(s) || !d[0] || state != FAULT)
              ok = 1'b0;
            else
              state <= CLEAR;
          end

          default: begin
            ok = 1'b0;
          end
        endcase
      end

      if (is_c) begin
        c_bresp <= ok ? OKAY : SLVERR;
        c_bvalid <= 1'b1;
      end
      else begin
        e_bresp <= ok ? OKAY : SLVERR;
        e_bvalid <= 1'b1;
      end
    end
  endtask

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      next_grant <= IDLE;
      mode <= M_TRUSTED;
      c_access <= 1'b0;
      c_result_ok <= 1'b0;
      graceful <= 1'b1;
      cfg <= '0;
      result_reg <= '0;
      input_limit <= '0;
      input_count <= '0;
      timeout_cfg <= 100;
      timer <= '0;
      busy <= 1'b0;
      done <= 1'b0;
      result_valid <= 1'b0;
      op_active <= 1'b0;
      input_error <= 1'b0;
      fault <= 1'b0;
      input_pending <= 1'b0;
      input_pending_data <= '0;
      input_pending_strb <= '0;
      input_pending_last <= 1'b0;
      acc_start <= 1'b0;
      acc_abort <= 1'b0;
      acc_config_valid <= 1'b0;
      c_aw_hold <= 1'b0;
      e_aw_hold <= 1'b0;
      c_w_hold <= 1'b0;
      e_w_hold <= 1'b0;
      c_bvalid <= 1'b0;
      e_bvalid <= 1'b0;
      c_rvalid <= 1'b0;
      e_rvalid <= 1'b0;
    end
    else begin
      acc_start <= 1'b0;
      acc_abort <= 1'b0;
      acc_config_valid <= 1'b0;

      if (c_bvalid && c_bready)
        c_bvalid <= 1'b0;
      if (e_bvalid && e_bready)
        e_bvalid <= 1'b0;
      if (c_rvalid && c_rready)
        c_rvalid <= 1'b0;
      if (e_rvalid && e_rready)
        e_rvalid <= 1'b0;

      if (c_awvalid && c_awready) begin
        c_aw_hold <= 1'b1;
        c_aw_q <= c_awaddr;
      end
      if (c_wvalid && c_wready) begin
        c_w_hold <= 1'b1;
        c_w_q <= c_wdata;
        c_ws_q <= c_wstrb;
      end
      if (e_awvalid && e_awready) begin
        e_aw_hold <= 1'b1;
        e_aw_q <= e_awaddr;
      end
      if (e_wvalid && e_wready) begin
        e_w_hold <= 1'b1;
        e_w_q <= e_wdata;
        e_ws_q <= e_wstrb;
      end

      if (c_aw_hold && c_w_hold && !c_bvalid) begin
        c_aw_hold <= 1'b0;
        c_w_hold <= 1'b0;
        do_write(1'b1, c_aw_q[7:0], c_w_q, c_ws_q);
      end
      if (e_aw_hold && e_w_hold && !e_bvalid) begin
        e_aw_hold <= 1'b0;
        e_w_hold <= 1'b0;
        do_write(1'b0, e_aw_q[7:0], e_w_q, e_ws_q);
      end

      if (c_arvalid && c_arready)
        rd_response(1'b1, c_araddr[7:0]);
      if (e_arvalid && e_arready)
        rd_response(1'b0, e_araddr[7:0]);

      if (acc_error) begin
        fault <= 1'b1;
        state <= FAULT;
        c_access <= 1'b0;
        op_active <= 1'b0;
        busy <= 1'b0;
      end

      if (input_pending && acc_data_ready && acc_data_valid) begin
        input_pending <= 1'b0;
        input_count <= input_count + LEN_W'(DATA_W/8);
      end

      if (acc_done) begin
        done <= 1'b1;
        busy <= 1'b0;
        op_active <= 1'b0;
      end

      if (acc_out_valid && acc_out_ready && acc_out_last) begin
        result_reg <= acc_data_out;
        result_valid <= 1'b1;
      end

      if (state == CLEAR) begin
        timer <= timer + 1;
        input_pending <= 1'b0;
        if (acc_clear_done) begin
          state <= next_grant;
          timer <= '0;
          input_count <= '0;
          op_active <= 1'b0;
          busy <= 1'b0;
          done <= 1'b0;
          result_valid <= 1'b0;
        end
        else if (timer >= timeout_cfg) begin
          state <= FAULT;
          fault <= 1'b1;
          c_access <= 1'b0;
          timer <= '0;
        end
      end

      if (state == QUIESCE) begin
        c_access <= 1'b0;
        if (op_active) begin
          acc_abort <= 1'b1;
          op_active <= 1'b0;
          busy <= 1'b0;
        end
        state <= CLEAR;
        result_valid <= 1'b0;
      end

      if (state == C_ACTIVE && next_grant == C_ACTIVE)
        c_access <= 1'b1;
    end
  end

`ifdef FORMAL
  // Yosys-compatible safety checks.
  always @(posedge clk) begin
    if (rst_n) begin
      assert (!(state == C_ACTIVE && state == E_ACTIVE));
      assert (state != FAULT || !c_access);
      assert (!acc_data_valid || input_pending);
      assert (!(c_bvalid && e_bvalid && c_rvalid && e_rvalid));

      if (c_bvalid && !c_bready)
        assert (c_bvalid);
      if (e_bvalid && !e_bready)
        assert (e_bvalid);
    end
  end

  // Reachability covers keep the safety checks from passing only through reset.
  always @(posedge clk) begin
    if (rst_n) begin
      cover (state == C_ACTIVE);
      cover (state == E_C_FEED);
      cover (state == FAULT);
    end
  end
`endif

endmodule

`default_nettype wire
