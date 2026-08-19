`default_nettype none

// ============================================================
// Tiny Tapeout Top Module
// Runtime-Reconfigurable ECC Memory
//
// Mode:
// 00 = OFF
// 01 = PARITY
// 10 = HAMMING
// 11 = SECDED
// ============================================================

module tt_um_afra_123_ecc_memory (
    input  wire [7:0] ui_in,      // Dedicated inputs
    output wire [7:0] uo_out,     // Dedicated outputs
    input  wire [7:0] uio_in,     // Bidirectional inputs
    output wire [7:0] uio_out,    // Bidirectional outputs
    output wire [7:0] uio_oe,     // Bidirectional output enable
    input  wire       ena,        // Design enable
    input  wire       clk,        // Clock
    input  wire       rst_n       // Active-low reset
);

    // ========================================================
    // Internal signals
    // ========================================================

    wire [1:0] mode;
    wire       we;
    wire [2:0] addr;
    wire [7:0] wdata;

    wire [7:0] rdata;
    wire       single_error;
    wire       double_error;


    // ========================================================
    // INPUT PIN MAPPING
    // ========================================================

    // ui_in[1:0] = ECC mode
    // 00 = OFF
    // 01 = PARITY
    // 10 = HAMMING
    // 11 = SECDED

    assign mode = ui_in[1:0];

    // ui_in[2] = Write Enable
    assign we = ui_in[2];

    // ui_in[5:3] = Memory Address
    assign addr = ui_in[5:3];

    // ui_in[7:6] = Write Data bits [1:0]
    assign wdata[1:0] = ui_in[7:6];

    // uio_in[7:2] = Write Data bits [7:2]
    assign wdata[7:2] = uio_in[7:2];


    // ========================================================
    // OUTPUT PIN MAPPING
    // ========================================================

    // uo_out[7:0] = Read Data
    assign uo_out = rdata;


    // ========================================================
    // ERROR FLAG OUTPUTS
    // ========================================================

    // uio_out[0] = Single-bit error detected/corrected
    assign uio_out[0] = single_error;

    // uio_out[1] = Double-bit error detected
    assign uio_out[1] = double_error;

    // Unused output pins
    assign uio_out[7:2] = 6'b0;


    // ========================================================
    // BIDIRECTIONAL PIN DIRECTION
    //
    // uio_oe = 1 -> output
    // uio_oe = 0 -> input
    //
    // uio[1:0] = error outputs
    // uio[7:2] = write-data inputs
    // ========================================================

    assign uio_oe[1:0] = 2'b11;

    assign uio_oe[7:2] = 6'b000000;


    // ========================================================
    // ECC MEMORY CORE
    // ========================================================

    runtime_reconfig_ecc_memory dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .mode         (mode),
        .we           (we),
        .addr         (addr),
        .wdata        (wdata),
        .rdata        (rdata),
        .single_error (single_error),
        .double_error (double_error)
    );


    // ========================================================
    // UNUSED INPUT
    // ========================================================

    // ena is provided by the Tiny Tapeout interface.
    // The ECC core does not require a separate enable signal.
    wire _unused;

    assign _unused = ena;

endmodule

`default_nettype wire
