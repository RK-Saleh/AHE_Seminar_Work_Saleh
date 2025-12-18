// PROFESSIONAL BENCHMARK: OpenTitan GPIO (Cleaned for Synthesis)
// Source: Derived from lowRISC OpenTitan 'gpio.sv'

// 1. PACKAGE DEFINITION
package gpio_pkg;
  parameter int NumIOs = 32;
endpackage

// 2. MAIN MODULE
module opentitan_gpio 
  import gpio_pkg::*;
(
  input  logic             clk_i,
  input  logic             rst_ni,

  // Register Interface (Simplified for Benchmarking)
  input  logic             reg_we,
  input  logic [31:0]      reg_addr,
  input  logic [31:0]      reg_wdata,
  output logic [31:0]      reg_rdata,

  // GPIO Ports
  input  logic [NumIOs-1:0] cio_gpio_i,
  output logic [NumIOs-1:0] cio_gpio_o,
  output logic [NumIOs-1:0] cio_gpio_en_o,

  // Interrupt Output
  output logic [NumIOs-1:0] intr_gpio_o
);

  // Registers
  logic [31:0] data_in_q;
  logic [31:0] direct_out_q;
  
  // Input Synchronization (Standard Double Flop for Safety)
  logic [31:0] cio_gpio_sync_1;
  logic [31:0] cio_gpio_sync_2;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        cio_gpio_sync_1 <= '0;
        cio_gpio_sync_2 <= '0;
    end else begin
        cio_gpio_sync_1 <= cio_gpio_i;
        cio_gpio_sync_2 <= cio_gpio_sync_1;
    end
  end

  // Edge Detection Logic
  logic [31:0] event_rise;
  logic [31:0] event_fall;
  
  always_ff @(posedge clk_i) begin
    data_in_q <= cio_gpio_sync_2;
  end
  
  assign event_rise = cio_gpio_sync_2 & ~data_in_q;
  assign event_fall = ~cio_gpio_sync_2 & data_in_q;

  // -------------------------------------------------------
  // THE CRITICAL TEST: MASKED WRITES
  // Professional code uses efficient bitwise logic in one cycle.
  // -------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      direct_out_q <= '0;
    end else if (reg_we) begin
      case (reg_addr[7:0])
        8'h00: direct_out_q <= reg_wdata; // Direct Write
        
        // Masked Lower: Update lower 16 bits based on upper 16 mask
        8'h04: direct_out_q[15:0] <= (direct_out_q[15:0] & ~reg_wdata[31:16]) | (reg_wdata[15:0] & reg_wdata[31:16]);
        
        // Masked Upper: Update upper 16 bits based on upper 16 mask
        8'h08: direct_out_q[31:16] <= (direct_out_q[31:16] & ~reg_wdata[31:16]) | (reg_wdata[15:0] & reg_wdata[31:16]);
      endcase
    end
  end

  assign cio_gpio_o = direct_out_q;
  assign cio_gpio_en_o = {32{1'b1}}; // All outputs enabled for this test

  // Interrupt Logic (Simplified for synthesis comparison)
  // Hardcoded enables to force synthesis to keep the logic
  logic [31:0] intr_ctrl_en_rising  = 32'hFFFFFFFF;
  logic [31:0] intr_ctrl_en_falling = 32'hFFFFFFFF;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) 
      intr_gpio_o <= '0;
    else
      intr_gpio_o <= (event_rise & intr_ctrl_en_rising) | 
                     (event_fall & intr_ctrl_en_falling);
  end

endmodule