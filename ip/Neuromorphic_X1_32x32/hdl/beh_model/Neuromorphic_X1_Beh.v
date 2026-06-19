
`timescale 1ns / 1ps

`ifdef USE_POWER_PINS
    `define USE_PG_PIN
`endif

module Neuromorphic_X1_wb (

`ifdef USE_PG_PIN
   inout         VDDC1,            // 0 V analog ground
   inout         VDDC2,            // 0 V analog ground
   inout         VDDA1,           // 1.8 V analog supply (mapped to vdda1)
   inout         VDDA2,           // 1.8 V analog supply (mapped to vdda1)
   inout         VSS,           // 1.8 V analog core digital supply (mapped to vccd1)
`endif
  input         user_clk,     // user clock
  input         user_rst,     // user reset
  input         wb_clk_i,     // Wishbone clock
  input         wb_rst_i,     // Wishbone reset (Active High)
  input         wbs_stb_i,    // Wishbone strobe
  input         wbs_cyc_i,    // Wishbone cycle indicator
  input         wbs_we_i,     // Wishbone write enable: 1=write, 0=read
  input  [3:0]  wbs_sel_i,    // Wishbone byte select (must be 4'hF for 32-bit op)
  input  [31:0] wbs_dat_i,    // Wishbone write data (becomes DI to core)
  input  [31:0] wbs_adr_i,    // Wishbone address
  output [31:0] wbs_dat_o,    // Wishbone read data output (driven by DO from core)
  output        wbs_ack_o,     // Wishbone acknowledge output (ack_out from core)
  
  // Scan/Test Pins
  input         ScanInCC,        // Scan enable
  input         ScanInDL,        // Data scan chain input (user_clk domain)
  input         ScanInDR,        // Data scan chain input (wb_clk domain)
  input         TM,              // Test mode
  output        ScanOutCC,       // Data scan chain output

  // Analog Pins
  input         Iref,            // 100 µA current reference
  input         Vcc_read,        // 0.3 V read rail
  input         Vcomp,           // 0.6 V comparator bias
  input         Bias_comp2,      // 0.6 V comparator bias
  input         Vcc_wl_read,     // 0.7 V wordline read rail
  input         Vcc_wl_set,      // 1.8 V wordline set rail
  input         Vbias,           // 1.8 V analog bias
  input         Vcc_wl_reset,    // 2.6 V wordline reset rail
  input         Vcc_set,         // 3.3 V array set rail
  input         dc_bias
);

	parameter [31:0] ADDR_MATCH = 32'h3000_0004;
	
	// --------------------------------------------------------------------------
  // Internal wires connecting the shim to the behavioral core
  // --------------------------------------------------------------------------
	wire        CLKin;
  wire        RSTin;
  wire        EN;
  wire [31:0] DI;
  wire        W_RB;
  wire [31:0] DO;
  wire        ack_out;
	
	// Map WB to core
	assign EN = (wbs_stb_i && wbs_cyc_i && (wbs_adr_i == ADDR_MATCH) && (wbs_sel_i == 4'hF));
	assign CLKin      = wb_clk_i;
  assign RSTin      = wb_rst_i;
	assign DI         = wbs_dat_i;
	assign W_RB       = wbs_we_i;
	assign wbs_dat_o  = DO;
	assign wbs_ack_o  = ack_out;
	
	// Instantiate the behavioral core
	Neuromorphic_X1_beh core_inst (
	`ifdef USE_PG_PIN
      .VDDC1(VDDC1),
      .VDDC2(VDDC2),
      .VDDA1(VDDA1),
      .VDDA2(VDDA2),
      .VSS(VSS),
`endif
    .CLKin      (CLKin),
    .RSTin      (RSTin),
    .EN         (EN),
    .DI         (DI),
    .W_RB       (W_RB),
    .DO         (DO),
    .ack_out   (ack_out),
    
    // Scan/Test Pins
    .ScanInCC(ScanInCC),
    .ScanInDL(ScanInDL),
    .ScanInDR(ScanInDR),
    .TM(TM),
    .ScanOutCC(ScanOutCC),

    // Analog Pins
    .Iref(Iref),
    .Vcc_read(Vcc_read),
    .Vcomp(Vcomp),
    .Bias_comp2(Bias_comp2),
    .Vcc_wl_read(Vcc_wl_read),
    .Vcc_wl_set(Vcc_wl_set),
    .Vbias(Vbias),
    .Vcc_wl_reset(Vcc_wl_reset),
    .Vcc_set(Vcc_set),
    .dc_bias(dc_bias)
  );
	
endmodule


// -----------------------------------------------------------------------------
// Behavioral core (sim only)
//  - 32x32 bit array
//  - input FIFO (commands), output FIFO (read results)
//  - PROGRAM (MODE=11): after WR_Dly cycles, write bit
//  - READ    (MODE=01): after RD_Dly cycles, push {31'b0, bit} into output FIFO
//  - WB READ a result: ACK=1 only when a word is popped
//  - If empty: DO=DEAD_C0DE for visibility, but ACK=0 (so the master waits)
// -----------------------------------------------------------------------------


module Neuromorphic_X1_beh (

`ifdef USE_PG_PIN
   inout         VDDC1,            // 0 V analog ground
   inout         VDDC2,            // 0 V analog ground
   inout         VDDA1,           // 1.8 V analog supply (mapped to vdda1)
   inout         VDDA2,           // 1.8 V analog supply (mapped to vdda1)
   inout         VSS,           // 1.8 V analog core digital supply (mapped to vccd1)
`endif

  input         CLKin,
	input         RSTin,
	input         EN,
	input  [31:0] DI,
	input         W_RB,
	output reg [31:0] DO,
	output reg    ack_out,
	
	// Scan/Test Pins
  input         ScanInCC,        // Scan enable
  input         ScanInDL,        // Scan data in (user_clk domain)
  input         ScanInDR,        // Scan data in (wb_clk domain)
  input         TM,              // Test mode
  output        ScanOutCC,       // Scan data out

  // Analog Pins
  input         Iref,            // 100 µA current reference
  input         Vcc_read,        // 0.3 V read rail
  input         Vcomp,           // 0.6 V comparator bias
  input         Bias_comp2,      // 0.6 V comparator bias
  input         Vcc_wl_read,     // 0.7 V wordline read rail
  input         Vcc_wl_set,      // 1.8 V wordline set rail
  input         Vbias,           // 1.8 V analog bias
  input         Vcc_wl_reset,    // 2.6 V wordline reset rail
  input         Vcc_set,         // 3.3 V set rail
  input         dc_bias
);
  
  assign ScanOutCC = 1'b0;

  // ---------------------------------------------------------------------------
  // Parameters (simulation delays / constants)
  // ---------------------------------------------------------------------------
  parameter integer RD_Dly      = 44;          // cycles before read data is available
  parameter integer WR_Dly      = 200;         // cycles to simulate write latency
  parameter [31:0] EMPTY_TOKEN  = 32'hDEAD_C0DE;

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------
  integer r, c, k, m;                          // loop indices for init and delays

  // 32x32 8-bit memory array (row = [29:25], col = [24:20])
  reg array_mem [0:31][0:31];  // 32x32 memory array (1-bit values)

  // Two 32-deep FIFOs (behavioral)
  reg [31:0] ip_fifo [0:31];                   // WB -> Engine commands
  reg [31:0] op_fifo [0:31];                   // Engine -> WB results

  // --- 5-bit pointers + separate wrap flags (preserves original semantics) ---
  // Input FIFO (WB producer / Engine consumer)
  reg  [4:0] ip_wptr_idx;   // producer index (WB)
  reg        ip_wptr_wrap;  // producer wrap bit
  reg  [4:0] ip_rptr_idx;   // consumer index (Engine)
  reg        ip_rptr_wrap;  // consumer wrap bit

  // Output FIFO (Engine producer / WB consumer)
  reg  [4:0] op_wptr_idx;   // producer index (Engine)
  reg        op_wptr_wrap;  // producer wrap bit
  reg  [4:0] op_rptr_idx;   // consumer index (WB)
  reg        op_rptr_wrap;  // consumer wrap bit

  // FIFO status using index + wrap flags
  wire ip_empty = (ip_wptr_idx == ip_rptr_idx) && (ip_wptr_wrap == ip_rptr_wrap);
  wire ip_full  = (ip_wptr_idx == ip_rptr_idx) && (ip_wptr_wrap != ip_rptr_wrap);

  wire op_empty = (op_wptr_idx == op_rptr_idx) && (op_wptr_wrap == op_rptr_wrap);
  wire op_full  = (op_wptr_idx == op_rptr_idx) && (op_wptr_wrap != op_rptr_wrap);
	
	// Next index helpers
  wire [4:0] ip_wptr_idx_next = (ip_wptr_idx == 5'd31) ? 5'd0 : (ip_wptr_idx + 5'd1);
  wire       ip_wptr_wrap_next = (ip_wptr_idx == 5'd31) ? ~ip_wptr_wrap : ip_wptr_wrap;

  wire [4:0] ip_rptr_idx_next = (ip_rptr_idx == 5'd31) ? 5'd0 : (ip_rptr_idx + 5'd1);
  wire       ip_rptr_wrap_next = (ip_rptr_idx == 5'd31) ? ~ip_rptr_wrap : ip_rptr_wrap;

  wire [4:0] op_wptr_idx_next = (op_wptr_idx == 5'd31) ? 5'd0 : (op_wptr_idx + 5'd1);
  wire       op_wptr_wrap_next = (op_wptr_idx == 5'd31) ? ~op_wptr_wrap : op_wptr_wrap;

  wire [4:0] op_rptr_idx_next = (op_rptr_idx == 5'd31) ? 5'd0 : (op_rptr_idx + 5'd1);
  wire       op_rptr_wrap_next = (op_rptr_idx == 5'd31) ? ~op_rptr_wrap : op_rptr_wrap;

  // Engine state
  reg        in_process;                        // engine busy flag
  reg [31:0] DI_local;                          // latched command
  reg [31:0] DO_local;                          // latched read data

  // ---------------------------------------------------------------------------
  // Wishbone side (behavioral, decoupled from engine)
  // ---------------------------------------------------------------------------
  always @(posedge CLKin or posedge RSTin) begin
    if (RSTin) begin
      DO          <= 32'd0;
      ack_out     <= 1'b0;
      ip_wptr_idx <= 5'd0;
      ip_wptr_wrap<= 1'b0;
      op_rptr_idx <= 5'd0;
      op_rptr_wrap<= 1'b0;
    end else begin
      ack_out <= 1'b0;
      // WRITE request -> push to ip_fifo if not full
      if (EN && W_RB && !ack_out) begin
        if (!ip_full) begin
          ack_out <= 1'b1;
          ip_fifo[ip_wptr_idx] <= DI;
          ip_wptr_idx  <= ip_wptr_idx_next;
          ip_wptr_wrap <= ip_wptr_wrap_next;
        end
      end
      // READ request -> pop from op_fifo or return token if empty
      else if (EN && !W_RB && !ack_out) begin
        if (!op_empty) begin
          ack_out <= 1'b1;
          DO      <= op_fifo[op_rptr_idx];
          op_rptr_idx  <= op_rptr_idx_next;
          op_rptr_wrap <= op_rptr_wrap_next;
        end else begin
          ack_out <= 1'b1;
          DO      <= EMPTY_TOKEN;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Engine side (simulation-only)
  // ---------------------------------------------------------------------------
  always @(posedge CLKin or posedge RSTin) begin
    if (RSTin) begin
      in_process   <= 1'b0;
      ip_rptr_idx  <= 5'd0;
      ip_rptr_wrap <= 1'b0;
      op_wptr_idx  <= 5'd0;
      op_wptr_wrap <= 1'b0;
			
    end else begin
      if (!in_process) begin
        if (!ip_empty) begin
          in_process <= 1'b1;
          DI_local   = ip_fifo[ip_rptr_idx]; // latch command

          // ---------------- WRITE OP (MODE=2'b11) ----------------
          if (DI_local[31:30] == 2'b11) begin
					  for (k = 0; k < WR_Dly; k = k + 1) @(posedge CLKin);
            array_mem[DI_local[29:25]][DI_local[24:20]] = (DI_local[7:0] > 8'h7F);

            ip_rptr_idx  <= ip_rptr_idx_next;
            ip_rptr_wrap <= ip_rptr_wrap_next;
            in_process   <= 1'b0;
          end

          // ---------------- READ OP (MODE=2'b01) -----------------
          else if (DI_local[31:30] == 2'b01) begin
            if (op_full) begin
              in_process <= 1'b0;
            end else begin
              for (m = 0; m < RD_Dly; m = m + 1) @(posedge CLKin);
              DO_local = {31'b0, array_mem[DI_local[29:25]][DI_local[24:20]]};
              op_fifo[op_wptr_idx] <= DO_local;
              op_wptr_idx  <= op_wptr_idx_next;
              op_wptr_wrap <= op_wptr_wrap_next;
              ip_rptr_idx  <= ip_rptr_idx_next;
              ip_rptr_wrap <= ip_rptr_wrap_next;
              in_process   <= 1'b0;
            end
          end

          // --------------- UNKNOWN OPCODE: drop it ----------------
          else begin
            ip_rptr_idx  <= ip_rptr_idx_next;
            ip_rptr_wrap <= ip_rptr_wrap_next;
            in_process   <= 1'b0;
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Init memory to 0 (sim-only convenience)
  // ---------------------------------------------------------------------------
  initial begin
    for (r = 0; r < 32; r = r + 1) begin
      for (c = 0; c < 32; c = c + 1) begin
        array_mem[r][c] = 1'b0;
      end
    end		
  end

endmodule