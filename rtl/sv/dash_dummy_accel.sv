`default_nettype none

module dash_dummy_accel #(
  parameter int DATA_W         = 32,
  parameter int LATENCY        = 3,
  parameter int CLEAR_DELAY    = 1,
  parameter bit ERROR_ON_START = 1'b0
) (
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   start,
  input  logic                   abort,
  input  logic                   clear,

  input  logic [DATA_W-1:0]      config_data,
  input  logic                   config_valid,
  output logic                   config_ready,
  input  logic [DATA_W-1:0]      data_in,
  input  logic                   data_valid,
  output logic                   data_ready,
  input  logic [DATA_W/8-1:0]    data_strb,
  input  logic                   data_last,

  output logic                   busy,
  output logic                   done,
  output logic                   clear_done,
  output logic                   error,
  output logic [DATA_W-1:0]      data_out,
  output logic                   out_valid,
  input  logic                   out_ready,
  output logic                   out_last
);

  logic [DATA_W-1:0] accum;
  logic [DATA_W-1:0] cfg;
  logic [7:0]        delay;
  logic [7:0]        clear_count;
  logic              running;
  logic              clearing;
  logic              received_last;

  assign config_ready = !running && !clearing;
  assign data_ready = running && !out_valid;
  assign out_last = out_valid;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      accum <= '0;
      cfg <= '0;
      delay <= '0;
      clear_count <= '0;
      running <= 1'b0;
      clearing <= 1'b0;
      received_last <= 1'b0;
      busy <= 1'b0;
      done <= 1'b0;
      clear_done <= 1'b0;
      error <= 1'b0;
      data_out <= '0;
      out_valid <= 1'b0;
    end
    else begin
      clear_done <= 1'b0;
      done <= 1'b0;

      if (config_valid && config_ready)
        cfg <= config_data;

      if (start && !running && !clearing) begin
        running <= 1'b1;
        busy <= 1'b1;
        accum <= cfg;
        delay <= '0;
        received_last <= 1'b0;
        out_valid <= 1'b0;
      end

      if (start && ERROR_ON_START)
        error <= 1'b1;

      if (abort) begin
        running <= 1'b0;
        busy <= 1'b0;
        out_valid <= 1'b0;
      end

      if (data_valid && data_ready && data_strb != 0) begin
        accum <= accum + data_in;
        if (data_last) begin
          delay <= LATENCY[7:0];
          received_last <= 1'b1;
        end
      end

      if (running && received_last && delay != 0 && !data_valid)
        delay <= delay - 1;

      if (running && received_last && delay == 0 && !out_valid) begin
        data_out <= accum + cfg;
        out_valid <= 1'b1;
        running <= 1'b0;
        busy <= 1'b0;
        done <= 1'b1;
      end

      if (out_valid && out_ready)
        out_valid <= 1'b0;

      if (clear) begin
        clearing <= 1'b1;
        clear_count <= CLEAR_DELAY[7:0];
        running <= 1'b0;
        busy <= 1'b0;
        out_valid <= 1'b0;
        received_last <= 1'b0;
      end

      if (clearing) begin
        if (clear_count != 0)
          clear_count <= clear_count - 1;
        else begin
          clearing <= 1'b0;
          clear_done <= 1'b1;
          accum <= '0;
          cfg <= '0;
          received_last <= 1'b0;
        end
      end
    end
  end

endmodule

`default_nettype wire
