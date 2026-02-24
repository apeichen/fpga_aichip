/**
 * XRAS Reliability Scoring Layer
 * 計算即時可靠性指數
 */
module xras_reliability_scoring (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自 XRAD/XENOA 的語義向量
    input  logic [511:0] semantic_tensor,
    input  logic         tensor_valid,
    
    // 來自 XENOS 的邊界資訊
    input  logic [15:0]  boundary_id,
    input  logic [31:0]  boundary_weight,
    
    // 歷史數據
    input  logic [31:0]  historical_scores [0:15],
    input  logic         history_valid,
    
    // 評分輸出
    output logic [31:0]  reliability_index,  // 0-1000
    output logic [31:0]  boundary_score,
    output logic [31:0]  deviation_impact,
    output logic [7:0]   reliability_trend,  // 0:down,1:stable,2:up
    output logic [1023:0] evidence_bundle,
    output logic         scoring_done
);

    logic [31:0] current_score;
    logic [31:0] drift_value;
    logic [31:0] impact;
    logic [7:0]  trend;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reliability_index <= 32'd1000;
            boundary_score <= 32'd1000;
            deviation_impact <= 32'b0;
            reliability_trend <= 8'd1;
            evidence_bundle <= 1024'b0;
            scoring_done <= 1'b0;
            current_score <= 32'd1000;
        end else if (tensor_valid) begin
            // 從語義張量提取漂移值
            drift_value <= semantic_tensor[63:32];
            
            // 計算可靠性指數 R = 1000 * (1 - D/T) * W
            if (drift_value > 0) begin
                current_score <= 1000 - (drift_value * 1000 / 1000); // 簡化計算
            end else begin
                current_score <= 32'd1000;
            end
            
            reliability_index <= current_score;
            
            // 邊界評分
            boundary_score <= current_score * boundary_weight / 100;
            
            // 偏差影響
            if (historical_scores[0] > current_score) begin
                impact <= historical_scores[0] - current_score;
            end else begin
                impact <= 32'b0;
            end
            deviation_impact <= impact;
            
            // 趨勢判斷
            if (current_score > historical_scores[0] + 10) begin
                trend <= 8'd2;  // 上升
            end else if (current_score < historical_scores[0] - 10) begin
                trend <= 8'd0;  // 下降
            end else begin
                trend <= 8'd1;  // 平穩
            end
            reliability_trend <= trend;
            
            // 產生證據包
            evidence_bundle <= {
                boundary_id,
                current_score,
                drift_value,
                impact,
                trend,
                historical_scores[0]
            };
            
            scoring_done <= 1'b1;
        end
    end

endmodule
