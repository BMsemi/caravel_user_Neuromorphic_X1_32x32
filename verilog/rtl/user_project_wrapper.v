`default_nettype none
module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1, inout vdda2,
    inout vssa1, inout vssa2,
    inout vccd1, inout vccd2,
    inout vssd1, inout vssd2,
`endif

    // Wishbone
    input         wb_clk_i,
    input         wb_rst_i,
    input         wbs_stb_i,
    input         wbs_cyc_i,
    input         wbs_we_i,
    input  [3:0]  wbs_sel_i,
    input  [31:0] wbs_dat_i,
    input  [31:0] wbs_adr_i,
    output        wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // Digital IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog IOs (analog_io[k] <-> GPIO pad k+7)
    inout  [`MPRJ_IO_PADS-10:0] analog_io,

    // Extra user clock
    input   user_clock2,

    // IRQs
    output [2:0] user_irq
);

    wire scanout_cc;

    assign la_data_out = 128'b0;
    assign user_irq     = 3'b000;

    // Drive all GPIO outputs low except GPIO23 = ScanOutCC
    // MPRJ_IO_PADS = 38, so this is bits [37:24], [23], [22:0]
    assign io_out = {14'b0, scanout_cc, 23'b0};

    // Disable all GPIO output drivers except GPIO23
    // io_oeb = 1 means output disabled, 0 means output enabled
    assign io_oeb = {14'h3fff, 1'b0, 23'h7fffff};


    // -----------------------------
    // Instantiate your hard macro
    // -----------------------------
   Neuromorphic_X1_wb neuro_inst (
`ifdef USE_POWER_PINS
  .VDDC1 (vccd1),
  .VDDC2 (vccd2),
  .VDDA1 (vdda1),
  .VDDA2 (vdda2),
  .VSS  (vssd1),
`endif

  // Clocks / resets
  .user_clk (wb_clk_i),
  .user_rst (wb_rst_i),
  .wb_clk_i (wb_clk_i),
  .wb_rst_i (wb_rst_i),

  // Wishbone
  .wbs_stb_i (wbs_stb_i),
  .wbs_cyc_i (wbs_cyc_i),
  .wbs_we_i  (wbs_we_i),
  .wbs_sel_i (wbs_sel_i),
  .wbs_dat_i (wbs_dat_i),
  .wbs_adr_i (wbs_adr_i),
  .wbs_dat_o (wbs_dat_o),
  .wbs_ack_o (wbs_ack_o),

  // Scan/Test
  .ScanInCC  (io_in[35]),
  .ScanInDL  (io_in[22]),
  .ScanInDR  (io_in[21]),
  .TM        (io_in[36]),
  .ScanOutCC (scanout_cc),

  // Analog / bias pins (drive from analog_io[] wires you already built)
  .Iref          (analog_io[27]),
  .Vcc_read      (analog_io[26]),
  .Vcomp         (analog_io[25]),
  .Bias_comp2    (analog_io[24]),
  .Vcc_wl_read   (analog_io[19]),
  .Vcc_wl_set    (analog_io[23]),
  .Vbias         (analog_io[22]),
  .Vcc_wl_reset  (analog_io[21]),
  .Vcc_set       (analog_io[20]),
  .dc_bias       (analog_io[18])
);


endmodule
`default_nettype wire
