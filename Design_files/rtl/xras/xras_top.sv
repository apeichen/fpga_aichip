/**
 * XRAS Top Module
 * 整合所有 XRAS 層，提供可靠性服務
 */
module xras_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame_in,
    input  logic          frame_valid_in,
    output logic [4095:0] xrbus_frame_out,
    output logic          frame_valid_out,
    
    // 來自 XRAD 的診斷向量
    input  logic [511:0]  diagnostic_vector,
    input  logic          diagnostic_valid,
    
    // 來自 XENOA 的語義張量
    input  logic [511:0]  semantic_tensor,
    input  logic          tensor_valid,
    
    // 來自 XENOS 的邊界資訊
    input  logic [15:0]   boundary_id,
    input  logic [7:0]    boundary_type,
    input  logic [31:0]   boundary_policies [0:15],
    
    // SLA 配置
    input  logic [7:0]    sla_level,
    input  logic [31:0]   target_reliability,
    input  logic [31:0]   tolerated_drift,
    input  logic [31:0]   financial_weight,
    input  logic          sla_config_valid,
    
    // 輸出給 XRST 的結算包
    output logic [4095:0] settlement_packet,
    output logic          packet_valid,
    
    // 狀態輸出
    output logic [7:0]    xras_state,
    output logic          xras_ready,
    output logic [31:0]   current_reliability,
    output logic [31:0]   total_penalties,
    output logic [31:0]   total_credits
);

    // 內部信號
    logic [31:0] sla_id;
    logic [31:0] sla_reliability;
    logic [31:0] sla_gap;
    logic [7:0]  sla_status;
    logic        sla_updated;
    
    logic [31:0] penalty;
    logic [31:0] credit;
    logic [7:0]  action;
    logic [31:0] actor;
    logic        policy_done;
    
    logic [31:0] reliability_idx;
    logic [31:0] boundary_score;
    logic [31:0] deviation;
    logic [7:0]  trend;
    logic [1023:0] evidence;
    logic        scoring_done;
    
    logic [4095:0] packet;
    logic [31:0]   settle_id;
    logic [31:0]   net;
    logic [7:0]    settle_type;
    logic [255:0]  proof;
    logic          packet_rdy;
    
    // 邊界規則轉換 (32-bit to 8-bit)
    logic [7:0]  boundary_rules [0:15];
    integer i;
    
    always_comb begin
        for (i = 0; i < 16; i = i + 1) begin
            boundary_rules[i] = boundary_policies[i][7:0];
        end
    end
    
    // 計數器
    logic [31:0] penalty_acc;
    logic [31:0] credit_acc;
    
    // 歷史分數
    logic [31:0] history [0:15];
    
    // 狀態機
    typedef enum logic [3:0] {
        IDLE,
        SLA_CONFIG,
        SCORING,
        POLICY,
        SETTLEMENT,
        REPORT
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            xras_ready <= 1'b0;
            penalty_acc <= 32'b0;
            credit_acc <= 32'b0;
            current_reliability <= 32'd1000;
            total_penalties <= 32'b0;
            total_credits <= 32'b0;
            
            for (i = 0; i < 16; i = i + 1) begin
                history[i] <= 32'd1000;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    xras_ready <= 1'b1;
                end
                
                SCORING: begin
                    if (scoring_done) begin
                        current_reliability <= reliability_idx;
                        // 更新歷史
                        for (i = 15; i > 0; i = i - 1) begin
                            history[i] <= history[i-1];
                        end
                        history[0] <= reliability_idx;
                    end
                end
                
                POLICY: begin
                    if (policy_done) begin
                        penalty_acc <= penalty_acc + penalty;
                        credit_acc <= credit_acc + credit;
                        total_penalties <= penalty_acc;
                        total_credits <= credit_acc;
                    end
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (sla_config_valid) begin
                    next_state = SLA_CONFIG;
                end else if (tensor_valid || diagnostic_valid) begin
                    next_state = SCORING;
                end
            end
            
            SLA_CONFIG: begin
                if (sla_updated) begin
                    next_state = IDLE;
                end
            end
            
            SCORING: begin
                if (scoring_done) begin
                    next_state = POLICY;
                end
            end
            
            POLICY: begin
                if (policy_done) begin
                    next_state = SETTLEMENT;
                end
            end
            
            SETTLEMENT: begin
                if (packet_rdy) begin
                    next_state = REPORT;
                end
            end
            
            REPORT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    assign xras_state = state;
    
    // 實體化子模組
    xras_sla_orchestration u_sla (
        .clk                (clk),
        .rst_n              (rst_n),
        .sla_level          (sla_level),
        .target_reliability (target_reliability),
        .tolerated_drift    (tolerated_drift),
        .causal_envelope    (32'd100),
        .financial_weight   (financial_weight),
        .sla_valid          (sla_config_valid && state == SLA_CONFIG),
        .sla_id             (sla_id),
        .current_reliability(sla_reliability),
        .reliability_gap    (sla_gap),
        .sla_status         (sla_status),
        .sla_updated        (sla_updated)
    );
    
    xras_reliability_scoring u_scoring (
        .clk                (clk),
        .rst_n              (rst_n),
        .semantic_tensor    (semantic_tensor),
        .tensor_valid       (tensor_valid && state == SCORING),
        .boundary_id        (boundary_id),
        .boundary_weight    (32'd100),
        .historical_scores  (history),
        .history_valid      (1'b1),
        .reliability_index  (reliability_idx),
        .boundary_score     (boundary_score),
        .deviation_impact   (deviation),
        .reliability_trend  (trend),
        .evidence_bundle    (evidence),
        .scoring_done       (scoring_done)
    );
    
    xras_policy_execution u_policy (
        .clk                (clk),
        .rst_n              (rst_n),
        .boundary_rules     (boundary_rules),
        .rule_count         (4'd16),
        .event_id           (sla_id),
        .event_type         (sla_status),
        .event_severity     (sla_gap),
        .event_boundary     ({16'b0, boundary_id}),
        .event_valid        (scoring_done && state == POLICY),
        .penalty_amount     (penalty),
        .credit_amount      (credit),
        .action_required    (action),
        .accountable_actor  (actor),
        .policy_executed    (policy_done)
    );
    
    xras_settlement_integration u_settle (
        .clk                (clk),
        .rst_n              (rst_n),
        .evidence_bundle    (evidence),
        .evidence_valid     (scoring_done),
        .penalty_amount     (penalty),
        .credit_amount      (credit),
        .accountable_actor  (actor),
        .policy_valid       (policy_done),
        .sla_id             (sla_id),
        .sla_reliability    (reliability_idx),
        .sla_status         (sla_status),
        .settlement_packet  (packet),
        .settlement_id      (settle_id),
        .net_settlement     (net),
        .settlement_type    (settle_type),
        .compliance_proof   (proof),
        .packet_ready       (packet_rdy)
    );
    
    // 輸出
    assign settlement_packet = packet;
    assign packet_valid = packet_rdy;
    
    // XR-BUS 輸出
    always_comb begin
        if (packet_rdy) begin
            xrbus_frame_out = packet;
        end else if (sla_updated) begin
            xrbus_frame_out[31:0] = sla_id;
            xrbus_frame_out[63:32] = sla_reliability;
            xrbus_frame_out[95:64] = sla_status;
        end else if (scoring_done) begin
            xrbus_frame_out[31:0] = reliability_idx;
            xrbus_frame_out[63:32] = boundary_score;
            xrbus_frame_out[95:64] = deviation;
        end else begin
            xrbus_frame_out = 4096'b0;
        end
        
        frame_valid_out = packet_rdy || sla_updated || scoring_done;
    end

endmodule
