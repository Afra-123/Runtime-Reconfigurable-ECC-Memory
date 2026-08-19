`default_nettype none
`timescale 1ns / 1ps

/*
 * Tiny Tapeout testbench wrapper.
 *
 * The actual functional tests are performed by cocotb
 * in test.py. This file provides the DUT and exposes
 * all Tiny Tapeout input/output signals to cocotb.
 */

module tb ();

    // ========================================================
    // Waveform dump
    // ========================================================

    initial begin
        $dumpfile("tb.fst");
        $dumpvars(0, tb);
        #1;
    end


    // ========================================================
    // Tiny Tapeout input signals
    // ========================================================

    reg        clk;
    reg        rst_n;
    reg        ena;

    reg [7:0]  ui_in;
    reg [7:0]  uio_in;


    // ========================================================
    // Tiny Tapeout output signals
    // ========================================================

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;


    // ========================================================
    // Power signals for gate-level simulation
    // ========================================================

`ifdef GL_TEST
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
`endif


    // ========================================================
    // DUT
    //
    // Tiny Tapeout top module:
    // tt_um_afra_123_ecc_memory
    // ========================================================

    tt_um_afra_123_ecc_memory user_project (

        // Power ports for gate-level simulation
`ifdef GL_TEST
        .VPWR   (VPWR),
        .VGND   (VGND),
`endif

        // Dedicated inputs
        .ui_in  (ui_in),

        // Dedicated outputs
        .uo_out (uo_out),

        // Bidirectional IO inputs
        .uio_in (uio_in),

        // Bidirectional IO outputs
        .uio_out(uio_out),

        // Bidirectional IO output enable
        .uio_oe (uio_oe),

        // Design enable
        .ena    (ena),

        // Clock
        .clk    (clk),

        // Active-low reset
        .rst_n  (rst_n)
    );

endmodule

`default_nettype wire
