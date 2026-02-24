/**
 * XRST Smart-SLA Execution Layer
 * 執行多參與者結算邏輯
 */
module xrst_smart_sla (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [31:0] sla_id,
    input  logic [31:0] stake_requirement,
    input  logic [31:0] weight_availability,
    input  logic [31:0] weight_latency,
    input  logic [31:0] weight_correctness,
    input  logic        sla_config_valid,
    
    input  logic [31:0] reliability_score,
    input  logic [31:0] credit_tokens,
    input  logic [31:0] penalty_tokens,
    input  logic [31:0] stake_adjustment,
    input  logic        token_valid,
    
    input  logic [31:0] participant_a,
    input  logic [31:0] participant_b,
    input  logic [31:0] participant_c,
    
    output logic [31:0] settlement_a,
    output logic [31:0] settlement_b,
    output logic [31:0] settlement_c,
    output logic [31:0] remaining_stake,
    output logic [7:0]  sla_status,
    output logic        execution_done
);

    logic [31:0] weighted_score;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            settlement_a <= 32'b0;
            settlement_b <= 32'b0;
            settlement_c <= 32'b0;
            remaining_stake <= 32'b0;
            sla_status <= 8'd0;
            execution_done <= 1'b0;
            weighted_score <= 32'b0;
        end else if (token_valid) begin
            weighted_score <= (reliability_score * weight_availability + 
                               reliability_score * weight_latency + 
                               reliability_score * weight_correctness) / 100;
            
            if (weighted_score >= 950) begin
                settlement_a <= credit_tokens * 50 / 100;
                settlement_b <= credit_tokens * 30 / 100;
                settlement_c <= credit_tokens * 20 / 100;
                sla_status <= 8'd0;
                
            end else if (weighted_score >= 900) begin
                settlement_a <= credit_tokens * 40 / 100;
                settlement_b <= credit_tokens * 40 / 100;
                settlement_c <= credit_tokens * 20 / 100;
                sla_status <= 8'd0;
                
            end else if (weighted_score >= 800) begin
                settlement_a <= penalty_tokens * 60 / 100;
                settlement_b <= penalty_tokens * 30 / 100;
                settlement_c <= penalty_tokens * 10 / 100;
                sla_status <= 8'd1;
                remaining_stake <= stake_requirement - stake_adjustment;
                
            end else begin
                settlement_a <= penalty_tokens;
                settlement_b <= 32'b0;
                settlement_c <= 32'b0;
                sla_status <= 8'd1;
                remaining_stake <= stake_requirement - stake_adjustment * 2;
            end
            
            execution_done <= 1'b1;
        end
    end

endmodule
