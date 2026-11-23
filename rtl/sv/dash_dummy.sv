`default_nettype none

module dash_dummy #(
  parameter int  DATA_W        = 32,
  parameter int  LATENCY       = 3,
  parameter int  CLEAR_DELAY   = 1,
  parameter bit  ERROR_ON_START = 1'b0
) (
  input  logic                   clk,
  input  logic                   rst_n,

  input  logic                   c_awvalid,
  output logic                   c_awready,
  input  logic [7:0]             c_awaddr,
  input  logic                   c_wvalid,
  output logic                   c_wready,
  input  logic [DATA_W-1:0]      c_wdata,
  input  logic [DATA_W/8-1:0]    c_wstrb,
  output logic                   c_bvalid,
  input  logic                   c_bready,
  input  logic                   c_arvalid,
  output logic                   c_arready,
  input  logic [7:0]             c_araddr,
  output logic                   c_rvalid,
  input  logic                   c_rready,
  output logic [DATA_W-1:0]      c_rdata,
  output logic [1:0]             c_bresp,
  output logic [1:0]             c_rresp,

  input  logic                   e_awvalid,
  output logic                   e_awready,
  input  logic [7:0]             e_awaddr,
  input  logic                   e_wvalid,
  output logic                   e_wready,
  input  logic [DATA_W-1:0]      e_wdata,
  input  logic [DATA_W/8-1:0]    e_wstrb,
  output logic                   e_bvalid,
  input  logic                   e_bready,
  input  logic                   e_arvalid,
  output logic                   e_arready,
  input  logic [7:0]             e_araddr,
  output logic                   e_rvalid,
  input  logic                   e_rready,
  output logic [DATA_W-1:0]      e_rdata,
  output logic [1:0]             e_bresp,
  output logic [1:0]             e_rresp
);

  logic                   start;
  logic                   abort;
  logic                   clear;
  logic                   cfg_valid;
  logic                   cfg_ready;
  logic                   busy;
  logic                   done;
  logic                   clear_done;
  logic                   error;
  logic                   input_valid;
  logic                   input_ready;
  logic                   input_last;
  logic                   output_valid;
  logic                   output_ready;
  logic                   output_last;

  logic [DATA_W-1:0]      cfg;
  logic [DATA_W-1:0]      input_data;
  logic [DATA_W-1:0]      output_data;
  logic [DATA_W/8-1:0]    input_strb;

  dash_core core (
    .clk               (clk),
    .rst_n              (rst_n),
    .c_awvalid          (c_awvalid),
    .c_awready          (c_awready),
    .c_awaddr           (c_awaddr),
    .c_wvalid           (c_wvalid),
    .c_wready           (c_wready),
    .c_wdata            (c_wdata),
    .c_wstrb            (c_wstrb),
    .c_bvalid           (c_bvalid),
    .c_bready           (c_bready),
    .c_arvalid          (c_arvalid),
    .c_arready          (c_arready),
    .c_araddr           (c_araddr),
    .c_rvalid           (c_rvalid),
    .c_rready           (c_rready),
    .c_rdata            (c_rdata),
    .c_bresp            (c_bresp),
    .c_rresp            (c_rresp),
    .e_awvalid          (e_awvalid),
    .e_awready          (e_awready),
    .e_awaddr           (e_awaddr),
    .e_wvalid           (e_wvalid),
    .e_wready           (e_wready),
    .e_wdata            (e_wdata),
    .e_wstrb            (e_wstrb),
    .e_bvalid           (e_bvalid),
    .e_bready           (e_bready),
    .e_arvalid          (e_arvalid),
    .e_arready          (e_arready),
    .e_araddr           (e_araddr),
    .e_rvalid           (e_rvalid),
    .e_rready           (e_rready),
    .e_rdata            (e_rdata),
    .e_bresp            (e_bresp),
    .e_rresp            (e_rresp),
    .acc_start          (start),
    .acc_abort          (abort),
    .acc_clear          (clear),
    .acc_config         (cfg),
    .acc_config_valid   (cfg_valid),
    .acc_config_ready   (cfg_ready),
    .acc_busy           (busy),
    .acc_done           (done),
    .acc_clear_done     (clear_done),
    .acc_error          (error),
    .acc_data_in        (input_data),
    .acc_data_valid     (input_valid),
    .acc_data_strb      (input_strb),
    .acc_data_last      (input_last),
    .acc_data_ready     (input_ready),
    .acc_data_out       (output_data),
    .acc_out_valid      (output_valid),
    .acc_out_ready      (output_ready),
    .acc_out_last       (output_last)
  );

  dash_dummy_accel #(
    .DATA_W         (DATA_W),
    .LATENCY        (LATENCY),
    .CLEAR_DELAY    (CLEAR_DELAY),
    .ERROR_ON_START (ERROR_ON_START)
  ) dummy (
    .clk          (clk),
    .rst_n        (rst_n),
    .start        (start),
    .abort        (abort),
    .clear        (clear),
    .config_data  (cfg),
    .config_valid (cfg_valid),
    .config_ready (cfg_ready),
    .data_in      (input_data),
    .data_valid   (input_valid),
    .data_ready   (input_ready),
    .data_strb    (input_strb),
    .data_last    (input_last),
    .busy         (busy),
    .done         (done),
    .clear_done   (clear_done),
    .error        (error),
    .data_out     (output_data),
    .out_valid    (output_valid),
    .out_ready    (output_ready),
    .out_last     (output_last)
  );

endmodule

`default_nettype wire
