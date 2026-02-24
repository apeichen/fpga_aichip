/**
 * XRAD MAC Unit
 */
module xrad_mac_unit (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] a,
    input  logic [15:0] b,
    input  logic [31:0] weight,
    output logic [31:0] result,
    output logic        valid
);

    logic [31:0] mult_real, mult_imag;
    logic [31:0] acc_real, acc_imag;

    always_ff @(posedge clk) begin
        mult_real <= a * weight[31:16] - b * weight[15:0];
        mult_imag <= a * weight[15:0] + b * weight[31:16];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_real <= 32'b0;
            acc_imag <= 32'b0;
            valid <= 1'b0;
        end else begin
            acc_real <= acc_real + mult_real;
            acc_imag <= acc_imag + mult_imag;
            valid <= 1'b1;
        end
    end

    assign result = {acc_real[31:16], acc_imag[31:16]};

endmodule
