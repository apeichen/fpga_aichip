/**
 * XRST Top Module
 * 整合所有 XRST 層，提供可靠性結算代幣化
 */
module xrst_top (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [4095:0] xrbus_frame_in,
    input  logic          frame_valid_in,
    output logic [4095:0] xrbus_frame_out,
    output logic          frame_valid_out,
    
    input  logic [4095:0] evidence_packet,
    input  logic          packet_valid,
    
    input  logic [31:0]   sla_id_config,
    input  logic [31:0]   stake_requirement,
    input  logic [31:0]   weight_avail,
    input  logic [31:0]   weight_lat,
    input  logic [31:0]   weight_corr,
    input  logic          sla_config_valid,
    
    input  logic [31:0]   participant_a,
    input  logic [31:0]   participant_b,
    input  logic [31:0]   participant_c,
    
    output logic [4095:0] settlement_report,
    output logic          settlement_valid,
    
    output logic [7:0]    xrst_state,
    output logic          xrst_ready,
    output logic [31:0]   total_settlements,
    output logic [31:0]   total_credits_issued,
    output logic [31:0]   total_penalties_issued
);

    logic [31:0] sla_id;
    logic [31:0] timestamp;
    logic [31:0] reliability;
    logic [31:0] penalty;
    logic [31:0] credit;
    logic [15:0] boundary;
    logic [255:0] causal;
    logic [255:0] proof;
    logic [7:0]  ev_status;
    logic        intake_done;
    
    logic [31:0] credit_tok;
    logic [31:0] penalty_tok;
    logic [31:0] stake_adj;
    logic [7:0]  tok_type;
    logic [255:0] tok_id;
    logic        token_done;
    
    logic [31:0] settle_a;
    logic [31:0] settle_b;
    logic [31:0] settle_c;
    logic [31:0] remain_stake;
    logic [7:0]  sla_stat;
    logic        sla_done;
    
    logic [4095:0] audit;
    logic [31:0]   risk;
    logic [255:0]  reg_hash;
    logic [7:0]    comp_level;
    logic          reg_done;
    
    logic [31:0] settlement_counter;
    logic [31:0] credit_counter;
    logic [31:0] penalty_counter;
    
    typedef enum logic [3:0] {
        IDLE,
        EVIDENCE,
        TOKENIZE,
        EXECUTE_SLA,
        SETTLE,
        REPORT
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            xrst_ready <= 1'b0;
            settlement_counter <= 32'b0;
            credit_counter <= 32'b0;
            penalty_counter <= 32'b0;
            total_settlements <= 32'b0;
            total_credits_issued <= 32'b0;
            total_penalties_issued <= 32'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: xrst_ready <= 1'b1;
                EVIDENCE: if (intake_done) settlement_counter <= settlement_counter + 1;
                TOKENIZE: if (token_done) begin
                    if (tok_type == 8'd0) credit_counter <= credit_counter + credit_tok;
                    else if (tok_type == 8'd1) penalty_counter <= penalty_counter + penalty_tok;
                end
                SETTLE: if (reg_done) begin
                    total_settlements <= settlement_counter;
                    total_credits_issued <= credit_counter;
                    total_penalties_issued <= penalty_counter;
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (packet_valid) next_state = EVIDENCE;
                else if (sla_config_valid) next_state = EXECUTE_SLA;
            end
            EVIDENCE: if (intake_done) next_state = TOKENIZE;
            TOKENIZE: if (token_done) next_state = EXECUTE_SLA;
            EXECUTE_SLA: if (sla_done) next_state = SETTLE;
            SETTLE: if (reg_done) next_state = REPORT;
            REPORT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    assign xrst_state = state;
    
    xrst_evidence_intake u_evidence (
        .clk                (clk),
        .rst_n              (rst_n),
        .evidence_packet    (evidence_packet),
        .packet_valid       (packet_valid && state == EVIDENCE),
        .sla_id             (sla_id),
        .timestamp          (timestamp),
        .reliability_score  (reliability),
        .penalty_amount     (penalty),
        .credit_amount      (credit),
        .boundary_id        (boundary),
        .causal_chain       (causal),
        .compliance_proof   (proof),
        .evidence_status    (ev_status),
        .intake_done        (intake_done)
    );
    
    xrst_tokenization_engine u_token (
        .clk                (clk),
        .rst_n              (rst_n),
        .reliability_score  (reliability),
        .penalty_amount     (penalty),
        .credit_amount      (credit),
        .boundary_id        (boundary),
        .evidence_valid     (intake_done && state == TOKENIZE),
        .credit_tokens      (credit_tok),
        .penalty_tokens     (penalty_tok),
        .stake_adjustment   (stake_adj),
        .token_type         (tok_type),
        .token_id           (tok_id),
        .tokenization_done  (token_done)
    );
    
    xrst_smart_sla u_sla (
        .clk                (clk),
        .rst_n              (rst_n),
        .sla_id             (sla_id_config),
        .stake_requirement  (stake_requirement),
        .weight_availability(weight_avail),
        .weight_latency     (weight_lat),
        .weight_correctness (weight_corr),
        .sla_config_valid   (sla_config_valid || (token_done && state == EXECUTE_SLA)),
        .reliability_score  (reliability),
        .credit_tokens      (credit_tok),
        .penalty_tokens     (penalty_tok),
        .stake_adjustment   (stake_adj),
        .token_valid        (token_done),
        .participant_a      (participant_a),
        .participant_b      (participant_b),
        .participant_c      (participant_c),
        .settlement_a       (settle_a),
        .settlement_b       (settle_b),
        .settlement_c       (settle_c),
        .remaining_stake    (remain_stake),
        .sla_status         (sla_stat),
        .execution_done     (sla_done)
    );
    
    xrst_regulated_settlement u_settle (
        .clk                (clk),
        .rst_n              (rst_n),
        .settlement_a       (settle_a),
        .settlement_b       (settle_b),
        .settlement_c       (settle_c),
        .remaining_stake    (remain_stake),
        .sla_status         (sla_stat),
        .settlement_valid   (sla_done && state == SETTLE),
        .sla_id             (sla_id),
        .timestamp          (timestamp),
        .reliability_score  (reliability),
        .compliance_proof   (proof),
        .audit_trail        (audit),
        .risk_index         (risk),
        .regulatory_hash    (reg_hash),
        .compliance_level   (comp_level),
        .settlement_finalized(reg_done)
    );
    
    assign settlement_report = audit;
    assign settlement_valid = reg_done;
    
    always_comb begin
        if (reg_done) begin
            xrbus_frame_out = audit;
        end else if (sla_done) begin
            xrbus_frame_out[31:0] = settle_a;
            xrbus_frame_out[63:32] = settle_b;
            xrbus_frame_out[95:64] = settle_c;
            xrbus_frame_out[127:96] = remain_stake;
            xrbus_frame_out[135:128] = sla_stat;
        end else if (token_done) begin
            xrbus_frame_out[31:0] = credit_tok;
            xrbus_frame_out[63:32] = penalty_tok;
            xrbus_frame_out[95:64] = stake_adj;
            xrbus_frame_out[351:96] = tok_id;
        end else begin
            xrbus_frame_out = 4096'b0;
        end
        
        frame_valid_out = reg_done || sla_done || token_done;
    end

endmodule
