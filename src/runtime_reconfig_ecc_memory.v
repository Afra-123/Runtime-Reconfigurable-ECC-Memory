`timescale 1ns / 1ps

module runtime_reconfig_ecc_memory (
    input        clk,
    input        rst_n,

    // 00 = OFF
    // 01 = PARITY
    // 10 = HAMMING
    // 11 = SECDED
    input  [1:0] mode,

    // Memory interface
    input        we,
    input  [2:0] addr,
    input  [7:0] wdata,

    output reg [7:0] rdata,
    output reg       single_error,
    output reg       double_error
);

    // ============================================================
    // MEMORY
    // Maximum codeword = 13 bits
    // 8 data + 4 Hamming parity + 1 overall parity
    // ============================================================

    reg [12:0] memory [0:7];

    reg [12:0] encoded_word;
    reg [12:0] corrected_word;

    wire [12:0] received_word;

    assign received_word = memory[addr];


    // ============================================================
    // ENCODER
    // ============================================================

    always @(*) begin

        // Default
        encoded_word = 13'b0;

        // --------------------------------------------------------
        // OFF MODE
        // --------------------------------------------------------

        if (mode == 2'b00) begin

            encoded_word[7:0] = wdata;

        end

        // --------------------------------------------------------
        // PARITY MODE
        // --------------------------------------------------------

        else if (mode == 2'b01) begin

            encoded_word[7:0] = wdata;

            // Even parity
            encoded_word[8] =
                wdata[0] ^
                wdata[1] ^
                wdata[2] ^
                wdata[3] ^
                wdata[4] ^
                wdata[5] ^
                wdata[6] ^
                wdata[7];

        end

        // --------------------------------------------------------
        // HAMMING / SECDED
        // --------------------------------------------------------

        else begin

            // Hamming positions:
            //
            // Position 1  = P1
            // Position 2  = P2
            // Position 3  = D0
            // Position 4  = P4
            // Position 5  = D1
            // Position 6  = D2
            // Position 7  = D3
            // Position 8  = P8
            // Position 9  = D4
            // Position 10 = D5
            // Position 11 = D6
            // Position 12 = D7

            encoded_word[2]  = wdata[0];
            encoded_word[4]  = wdata[1];
            encoded_word[5]  = wdata[2];
            encoded_word[6]  = wdata[3];

            encoded_word[8]  = wdata[4];
            encoded_word[9]  = wdata[5];
            encoded_word[10] = wdata[6];
            encoded_word[11] = wdata[7];

            // P1
            encoded_word[0] =
                encoded_word[2] ^
                encoded_word[4] ^
                encoded_word[6] ^
                encoded_word[8] ^
                encoded_word[10];

            // P2
            encoded_word[1] =
                encoded_word[2] ^
                encoded_word[5] ^
                encoded_word[6] ^
                encoded_word[9] ^
                encoded_word[10];

            // P4
            encoded_word[3] =
                encoded_word[4] ^
                encoded_word[5] ^
                encoded_word[6] ^
                encoded_word[11];

            // P8
            encoded_word[7] =
                encoded_word[8] ^
                encoded_word[9] ^
                encoded_word[10] ^
                encoded_word[11];

            // SECDED overall parity
            if (mode == 2'b11) begin
                encoded_word[12] = ^encoded_word[11:0];
            end

        end

    end


    // ============================================================
    // MEMORY WRITE
    // ============================================================

    integer i;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            for (i = 0; i < 8; i = i + 1) begin
                memory[i] <= 13'b0;
            end

        end
        else begin

            if (we) begin
                memory[addr] <= encoded_word;
            end

        end

    end


    // ============================================================
    // DECODER
    // ============================================================

    reg p1;
    reg p2;
    reg p4;
    reg p8;

    reg [3:0] syndrome;
    reg overall_check;


    always @(*) begin

        // Defaults
        rdata          = 8'b0;
        single_error   = 1'b0;
        double_error   = 1'b0;

        corrected_word = received_word;

        p1 = 1'b0;
        p2 = 1'b0;
        p4 = 1'b0;
        p8 = 1'b0;

        syndrome      = 4'b0000;
        overall_check = 1'b0;


        // ========================================================
        // OFF
        // ========================================================

        if (mode == 2'b00) begin

            rdata = received_word[7:0];

        end


        // ========================================================
        // PARITY
        // ========================================================

        else if (mode == 2'b01) begin

            rdata = received_word[7:0];

            if (^received_word[8:0] != 1'b0) begin
                single_error = 1'b1;
            end

        end


        // ========================================================
        // HAMMING
        // ========================================================

        else if (mode == 2'b10) begin

            // Calculate syndrome

            p1 =
                received_word[0] ^
                received_word[2] ^
                received_word[4] ^
                received_word[6] ^
                received_word[8] ^
                received_word[10];

            p2 =
                received_word[1] ^
                received_word[2] ^
                received_word[5] ^
                received_word[6] ^
                received_word[9] ^
                received_word[10];

            p4 =
                received_word[3] ^
                received_word[4] ^
                received_word[5] ^
                received_word[6] ^
                received_word[11];

            p8 =
                received_word[7] ^
                received_word[8] ^
                received_word[9] ^
                received_word[10] ^
                received_word[11];

            syndrome = {p8, p4, p2, p1};


            // Correct single-bit error

            if (syndrome != 4'b0000) begin

                if (syndrome <= 4'd12) begin

                    corrected_word[syndrome - 1] =
                        ~corrected_word[syndrome - 1];

                    single_error = 1'b1;

                end

            end


            // Extract data

            rdata[0] = corrected_word[2];
            rdata[1] = corrected_word[4];
            rdata[2] = corrected_word[5];
            rdata[3] = corrected_word[6];

            rdata[4] = corrected_word[8];
            rdata[5] = corrected_word[9];
            rdata[6] = corrected_word[10];
            rdata[7] = corrected_word[11];

        end


        // ========================================================
        // SECDED
        // ========================================================

        else begin

            // Calculate Hamming syndrome

            p1 =
                received_word[0] ^
                received_word[2] ^
                received_word[4] ^
                received_word[6] ^
                received_word[8] ^
                received_word[10];

            p2 =
                received_word[1] ^
                received_word[2] ^
                received_word[5] ^
                received_word[6] ^
                received_word[9] ^
                received_word[10];

            p4 =
                received_word[3] ^
                received_word[4] ^
                received_word[5] ^
                received_word[6] ^
                received_word[11];

            p8 =
                received_word[7] ^
                received_word[8] ^
                received_word[9] ^
                received_word[10] ^
                received_word[11];

            syndrome = {p8, p4, p2, p1};


            // Overall parity

            overall_check = ^received_word;


            // ----------------------------------------------------
            // SECDED decision
            //
            // syndrome = 0, overall = 0
            // -> No error
            //
            // syndrome != 0, overall = 1
            // -> Single-bit error
            //
            // syndrome = 0, overall = 1
            // -> Overall parity-bit error
            //
            // syndrome != 0, overall = 0
            // -> Double-bit error
            // ----------------------------------------------------

            if ((syndrome != 4'b0000) &&
                (overall_check == 1'b1)) begin

                if (syndrome <= 4'd12) begin

                    corrected_word[syndrome - 1] =
                        ~corrected_word[syndrome - 1];

                    single_error = 1'b1;

                end

            end

            else if ((syndrome == 4'b0000) &&
                     (overall_check == 1'b1)) begin

                // Overall parity bit error
                single_error = 1'b1;

            end

            else if ((syndrome != 4'b0000) &&
                     (overall_check == 1'b0)) begin

                // Double-bit error
                double_error = 1'b1;

            end


            // Extract data

            rdata[0] = corrected_word[2];
            rdata[1] = corrected_word[4];
            rdata[2] = corrected_word[5];
            rdata[3] = corrected_word[6];

            rdata[4] = corrected_word[8];
            rdata[5] = corrected_word[9];
            rdata[6] = corrected_word[10];
            rdata[7] = corrected_word[11];

        end

    end

endmodule
