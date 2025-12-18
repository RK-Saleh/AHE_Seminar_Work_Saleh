// Professional GPIO Module with Interrupt Support
// Copyright (c) 2024. All rights reserved.
// Designed for 32-bit General Purpose Input/Output control

module gpio #(
  parameter int unsigned GpioWidth = 32
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,

  // Pad interface
  input  logic [GpioWidth-1:0]    cio_gpio_i,
  output logic [GpioWidth-1:0]    cio_gpio_o,
  output logic [GpioWidth-1:0]    cio_gpio_en_o,

  // Register interface - Direct Write
  input  logic                    direct_out_we_i,
  input  logic [GpioWidth-1:0]    direct_out_data_i,
  input  logic                    direct_oe_we_i,
  input  logic [GpioWidth-1:0]    direct_oe_data_i,

  // Register interface - Masked Write Upper [31:16]
  input  logic                    masked_out_upper_we_i,
  input  logic [15:0]             masked_out_upper_data_i,
  input  logic [15:0]             masked_out_upper_mask_i,
  input  logic                    masked_oe_upper_we_i,
  input  logic [15:0]             masked_oe_upper_data_i,
  input  logic [15:0]             masked_oe_upper_mask_i,

  // Register interface - Masked Write Lower [15:0]
  input  logic                    masked_out_lower_we_i,
  input  logic [15:0]             masked_out_lower_data_i,
  input  logic [15:0]             masked_out_lower_mask_i,
  input  logic                    masked_oe_lower_we_i,
  input  logic [15:0]             masked_oe_lower_data_i,
  input  logic [15:0]             masked_oe_lower_mask_i,

  // Interrupt configuration
  input  logic [GpioWidth-1:0]    intr_ctrl_en_rising_i,
  input  logic [GpioWidth-1:0]    intr_ctrl_en_falling_i,
  input  logic [GpioWidth-1:0]    intr_ctrl_en_lvlhigh_i,
  input  logic [GpioWidth-1:0]    intr_ctrl_en_lvllow_i,

  // Interrupt status (write-1-to-clear)
  input  logic                    intr_state_we_i,
  input  logic [GpioWidth-1:0]    intr_state_data_i,
  output logic [GpioWidth-1:0]    intr_state_o,

  // Interrupt output
  output logic [GpioWidth-1:0]    intr_o
);

  // =============================================================================
  // Internal Signals
  // =============================================================================
  logic [GpioWidth-1:0] gpio_out_q, gpio_out_d;
  logic [GpioWidth-1:0] gpio_oe_q, gpio_oe_d;
  logic [GpioWidth-1:0] gpio_in_sync1_q, gpio_in_sync2_q;
  logic [GpioWidth-1:0] gpio_in_prev_q;
  logic [GpioWidth-1:0] intr_state_q, intr_state_d;

  // Edge detection signals
  logic [GpioWidth-1:0] rising_edge, falling_edge;

  // =============================================================================
  // Input Synchronization (Double-Flop for Metastability Protection)
  // =============================================================================
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      gpio_in_sync1_q <= '0;
      gpio_in_sync2_q <= '0;
      gpio_in_prev_q  <= '0;
    end else begin
      gpio_in_sync1_q <= cio_gpio_i;
      gpio_in_sync2_q <= gpio_in_sync1_q;
      gpio_in_prev_q  <= gpio_in_sync2_q;
    end
  end

  // =============================================================================
  // Edge Detection Logic
  // =============================================================================
  assign rising_edge  = gpio_in_sync2_q & ~gpio_in_prev_q;
  assign falling_edge = ~gpio_in_sync2_q & gpio_in_prev_q;

  // =============================================================================
  // GPIO Output Data Register Logic
  // =============================================================================
  always_comb begin
    gpio_out_d = gpio_out_q;

    // Direct write has priority
    if (direct_out_we_i) begin
      gpio_out_d = direct_out_data_i;
    end else begin
      // Masked write upper [31:16]
      if (masked_out_upper_we_i) begin
        for (int i = 0; i < 16; i++) begin
          if (masked_out_upper_mask_i[i]) begin
            gpio_out_d[16+i] = masked_out_upper_data_i[i];
          end
        end
      end

      // Masked write lower [15:0]
      if (masked_out_lower_we_i) begin
        for (int i = 0; i < 16; i++) begin
          if (masked_out_lower_mask_i[i]) begin
            gpio_out_d[i] = masked_out_lower_data_i[i];
          end
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      gpio_out_q <= '0;
    end else begin
      gpio_out_q <= gpio_out_d;
    end
  end

  assign cio_gpio_o = gpio_out_q;

  // =============================================================================
  // GPIO Output Enable Register Logic
  // =============================================================================
  always_comb begin
    gpio_oe_d = gpio_oe_q;

    // Direct write has priority
    if (direct_oe_we_i) begin
      gpio_oe_d = direct_oe_data_i;
    end else begin
      // Masked write upper [31:16]
      if (masked_oe_upper_we_i) begin
        for (int i = 0; i < 16; i++) begin
          if (masked_oe_upper_mask_i[i]) begin
            gpio_oe_d[16+i] = masked_oe_upper_data_i[i];
          end
        end
      end

      // Masked write lower [15:0]
      if (masked_oe_lower_we_i) begin
        for (int i = 0; i < 16; i++) begin
          if (masked_oe_lower_mask_i[i]) begin
            gpio_oe_d[i] = masked_oe_lower_data_i[i];
          end
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      gpio_oe_q <= '0;
    end else begin
      gpio_oe_q <= gpio_oe_d;
    end
  end

  assign cio_gpio_en_o = gpio_oe_q;

  // =============================================================================
  // Interrupt Detection Logic
  // =============================================================================
  logic [GpioWidth-1:0] intr_detect;

  always_comb begin
    for (int i = 0; i < GpioWidth; i++) begin
      intr_detect[i] = (intr_ctrl_en_rising_i[i]  & rising_edge[i]) |
                       (intr_ctrl_en_falling_i[i] & falling_edge[i]) |
                       (intr_ctrl_en_lvlhigh_i[i] & gpio_in_sync2_q[i]) |
                       (intr_ctrl_en_lvllow_i[i]  & ~gpio_in_sync2_q[i]);
    end
  end

  // =============================================================================
  // Interrupt State Register (Write-1-to-Clear)
  // =============================================================================
  always_comb begin
    intr_state_d = intr_state_q;

    // Set interrupt bits when detected
    intr_state_d = intr_state_q | intr_detect;

    // Clear interrupt bits on write-1-to-clear
    if (intr_state_we_i) begin
      intr_state_d = intr_state_d & ~intr_state_data_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      intr_state_q <= '0;
    end else begin
      intr_state_q <= intr_state_d;
    end
  end

  assign intr_state_o = intr_state_q;
  assign intr_o = intr_state_q;

  // =============================================================================
  // Assertions for Verification
  // =============================================================================
`ifndef SYNTHESIS
  // Check that direct and masked writes don't occur simultaneously
  always_ff @(posedge clk_i) begin
    if (rst_ni) begin
      assert (!(direct_out_we_i && (masked_out_upper_we_i || masked_out_lower_we_i)))
        else $error("Direct and masked GPIO output writes should not occur simultaneously");
      assert (!(direct_oe_we_i && (masked_oe_upper_we_i || masked_oe_lower_we_i)))
        else $error("Direct and masked GPIO OE writes should not occur simultaneously");
    end
  end
`endif

endmodule