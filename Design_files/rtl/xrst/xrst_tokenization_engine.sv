/**
 * XRST Tokenization Engine
 * 將可靠性轉換為可結算的代幣
 */
module xrst_tokenization_engine (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [31:0]   reliability_score,
    input  logic [31:0]   penalty_amount,
    input  logic [31:0]   credit_amount,
    input  logic [15:0]   boundary_id,
    input  logic          evidence_valid,
    
    output logic [31:0]   credit_tokens,
    output logic [31:0]   penalty_tokens,
    output logic [31:0]   stake_adjustment,
    output logic [7:0]    token_type,
    output logic [255:0]  token_id,
    output logic          tokenization_done
);

    logic [31:0] credit_counter;
    logic [31:0] penalty_counter;
    logic [31:0] token_counter;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_tokens <= 32'b0;
            penalty_tokens <= 32'b0;
            stake_adjustment <= 32'b0;
            token_type <= 8'd0;
            token_id <= 256'b0;
            tokenization_done <= 1'b0;
            credit_counter <= 32'b0;
            penalty_counter <= 32'b0;
            token_counter <= 32'b0;
        end else if (evidence_valid) begin
            token_counter <= token_counter + 1;
            
            if (credit_amount > penalty_amount) begin
                credit_tokens <= credit_amount - penalty_amount;
                penalty_tokens <= 32'b0;
                token_type <= 8'd0;
                token_id <= {boundary_id, token_counter, 208'h435245444954}; // "CREDIT"
                
            end else if (penalty_amount > credit_amount) begin
                penalty_tokens <= penalty_amount - credit_amount;
                credit_tokens <= 32'b0;
                token_type <= 8'd1;
                token_id <= {boundary_id, token_counter, 208'h50454E414C5459}; // "PENALTY"
                stake_adjustment <= (penalty_amount - credit_amount) / 10;
                
            end else begin
                credit_tokens <= 32'b0;
                penalty_tokens <= 32'b0;
                token_type <= 8'd2;
                stake_adjustment <= 32'b0;
                token_id <= {boundary_id, token_counter, 208'h5354414B45}; // "STAKE"
            end
            
            tokenization_done <= 1'b1;
        end
    end

endmodule
