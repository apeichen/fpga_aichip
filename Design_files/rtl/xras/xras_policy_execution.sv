/**
 * XRAS Policy Execution Layer
 * 執行可靠性政策和罰則計算
 */
module xras_policy_execution (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自 XENOS 的邊界規則
    input  logic [7:0]  boundary_rules [0:15],
    input  logic [3:0]  rule_count,
    
    // 事件輸入
    input  logic [31:0] event_id,
    input  logic [7:0]  event_type,     // 0:normal,1:drift,2:anomaly,3:fault,4:fatal
    input  logic [31:0] event_severity,
    input  logic [31:0] event_boundary,
    input  logic        event_valid,
    
    // 政策輸出
    output logic [31:0] penalty_amount,
    output logic [31:0] credit_amount,
    output logic [7:0]  action_required,  // 0:none,1:warn,2:throttle,3:isolate,4:shutdown
    output logic [31:0] accountable_actor,
    output logic        policy_executed
);

    // 基礎罰款金額
    localparam [31:0] BASE_PENALTY = 32'd1000;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            penalty_amount <= 32'b0;
            credit_amount <= 32'b0;
            action_required <= 8'd0;
            accountable_actor <= 32'b0;
            policy_executed <= 1'b0;
        end else if (event_valid) begin
            // 根據事件類型決定行動
            case (event_type)
                8'd0: begin // 正常
                    credit_amount <= 32'd100;
                    action_required <= 8'd0;
                end
                
                8'd1: begin // 輕微漂移
                    penalty_amount <= BASE_PENALTY * event_severity / 100;
                    action_required <= 8'd1; // 警告
                end
                
                8'd2: begin // 中度異常
                    penalty_amount <= BASE_PENALTY * event_severity / 50;
                    action_required <= 8'd2; // 限流
                end
                
                8'd3: begin // 嚴重故障
                    penalty_amount <= BASE_PENALTY * event_severity / 10;
                    action_required <= 8'd3; // 隔離
                end
                
                8'd4: begin // 致命錯誤
                    penalty_amount <= BASE_PENALTY * event_severity / 5;
                    action_required <= 8'd4; // 停機
                end
                
                default: begin
                    penalty_amount <= 32'b0;
                    action_required <= 8'd0;
                end
            endcase
            
            // 根據邊界決定責任歸屬
            accountable_actor <= event_boundary;
            
            policy_executed <= 1'b1;
        end
    end

endmodule
