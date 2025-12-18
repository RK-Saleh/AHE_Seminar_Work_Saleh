// Professional Source: Xilinx Vivado Language Template (Fixed)
// Module: True Dual Port RAM with Dual Clocks
// Standardized values: Width=32, Depth=1024 for benchmarking

module xilinx_true_dual_port_ram #(
    parameter RAM_WIDTH = 32,                       // Fixed: 32-bit data
    parameter RAM_DEPTH = 1024,                     // Fixed: 1024 entries
    parameter RAM_PERFORMANCE = "HIGH_PERFORMANCE", // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    parameter INIT_FILE = ""                        // Leave blank
)(
    input [clogb2(RAM_DEPTH-1)-1:0] addra,  // Port A address bus
    input [clogb2(RAM_DEPTH-1)-1:0] addrb,  // Port B address bus
    input [RAM_WIDTH-1:0] dina,             // Port A RAM input data
    input [RAM_WIDTH-1:0] dinb,             // Port B RAM input data
    input clka,                             // Port A clock
    input clkb,                             // Port B clock
    input wea,                              // Port A write enable
    input web,                              // Port B write enable
    input ena,                              // Port A RAM Enable
    input enb,                              // Port B RAM Enable
    input rsta,                             // Port A output reset
    input rstb,                             // Port B output reset
    input regcea,                           // Port A output register enable
    input regceb,                           // Port B output register enable
    output [RAM_WIDTH-1:0] douta,           // Port A RAM output data
    output [RAM_WIDTH-1:0] doutb            // Port B RAM output data
);

    // Scaling function for address width
    function integer clogb2;
    input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
    endfunction

    // 2D Array for RAM storage
    reg [RAM_WIDTH-1:0] BRAM [RAM_DEPTH-1:0];
    reg [RAM_WIDTH-1:0] ram_data_a = {RAM_WIDTH{1'b0}};
    reg [RAM_WIDTH-1:0] ram_data_b = {RAM_WIDTH{1'b0}};

    // Initialize memory to zero
    generate
        if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, BRAM, 0, RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
                    BRAM[ram_index] = {RAM_WIDTH{1'b0}};
        end
    endgenerate

    // PORT A OPERATION
    always @(posedge clka) begin
        if (ena) begin
            if (wea)
                BRAM[addra] <= dina;
            ram_data_a <= BRAM[addra];
        end
    end

    // PORT B OPERATION
    always @(posedge clkb) begin
        if (enb) begin
            if (web)
                BRAM[addrb] <= dinb;
            ram_data_b <= BRAM[addrb];
        end
    end

    // Output Register Stage
    generate
        if (RAM_PERFORMANCE == "LOW_LATENCY") begin: no_output_register
            assign douta = ram_data_a;
            assign doutb = ram_data_b;
        end else begin: output_register
            reg [RAM_WIDTH-1:0] douta_reg = {RAM_WIDTH{1'b0}};
            reg [RAM_WIDTH-1:0] doutb_reg = {RAM_WIDTH{1'b0}};

            always @(posedge clka) begin
                if (rsta)
                    douta_reg <= {RAM_WIDTH{1'b0}};
                else if (regcea)
                    douta_reg <= ram_data_a;
            end

            always @(posedge clkb) begin
                if (rstb)
                    doutb_reg <= {RAM_WIDTH{1'b0}};
                else if (regceb)
                    doutb_reg <= ram_data_b;
            end

            assign douta = douta_reg;
            assign doutb = doutb_reg;
        end
    endgenerate

endmodule