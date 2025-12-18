module true_dual_port_ram #(
    parameter int RAM_WIDTH = 32,
    parameter int RAM_DEPTH = 1024,
    parameter string RAM_PERFORMANCE = "LOW_LATENCY", // or "HIGH_PERFORMANCE"
    parameter string INIT_FILE = ""                    // optional memory init file
)(
    // Port A
    input  logic                     clka,
    input  logic                     wea,
    input  logic [$clog2(RAM_DEPTH)-1:0] addra,
    input  logic [RAM_WIDTH-1:0]      dina,
    output logic [RAM_WIDTH-1:0]      douta,

    // Port B
    input  logic                     clkb,
    input  logic                     web,
    input  logic [$clog2(RAM_DEPTH)-1:0] addrb,
    input  logic [RAM_WIDTH-1:0]      dinb,
    output logic [RAM_WIDTH-1:0]      doutb,

    // Reset (used only for output registers)
    input  logic                     rst
);

    localparam int ADDR_WIDTH = $clog2(RAM_DEPTH);

    // Memory array
    logic [RAM_WIDTH-1:0] ram [0:RAM_DEPTH-1];

    // Internal read data (pre-output register)
    logic [RAM_WIDTH-1:0] douta_int;
    logic [RAM_WIDTH-1:0] doutb_int;

    // ------------------------------------------------------------
    // Optional memory initialization
    // ------------------------------------------------------------
    generate
        if (INIT_FILE != "") begin : gen_init_file
            initial $readmemh(INIT_FILE, ram);
        end else begin : gen_init_zero
            integer i;
            initial begin
                for (i = 0; i < RAM_DEPTH; i = i + 1)
                    ram[i] = '0;
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // Port A - Read-First behavior
    // ------------------------------------------------------------
    always_ff @(posedge clka) begin
        // Read old data first
        douta_int <= ram[addra];

        // Write after read
        if (wea) begin
            ram[addra] <= dina;
        end
    end

    // ------------------------------------------------------------
    // Port B - Read-First behavior
    // ------------------------------------------------------------
    always_ff @(posedge clkb) begin
        // Read old data first
        doutb_int <= ram[addrb];

        // Write after read
        if (web) begin
            ram[addrb] <= dinb;
        end
    end

    // ------------------------------------------------------------
    // Output register stage (performance selection)
    // ------------------------------------------------------------
    generate
        if (RAM_PERFORMANCE == "HIGH_PERFORMANCE") begin : gen_high_perf
            // Extra registered output stage (2-cycle latency)
            always_ff @(posedge clka) begin
                if (rst)
                    douta <= '0;
                else
                    douta <= douta_int;
            end

            always_ff @(posedge clkb) begin
                if (rst)
                    doutb <= '0;
                else
                    doutb <= doutb_int;
            end
        end else begin : gen_low_latency
            // Direct output (1-cycle latency)
            always_comb begin
                douta = douta_int;
                doutb = doutb_int;
            end
        end
    endgenerate

endmodule
