/**
 * XENOA Reasoning Substrate Layer
 * 產生語義張量供 AI 引擎使用
 */
module xenoa_reasoning (
    input  logic        clk,
    input  logic        rst_n,
    
    // 邊界語義輸入
    input  logic [31:0]  boundary_key,
    input  logic [31:0]  contract_bound_value,
    input  logic [7:0]   boundary_severity,
    input  logic [255:0] audit_record,
    input  logic         boundary_valid,
    
    // 歷史數據
    input  logic [31:0]  history_buffer [0:15],  // 16筆歷史記錄
    input  logic         history_valid,
    
    // 輸出語義張量
    output logic [511:0] semantic_tensor,    // 供 AI 使用
    output logic [255:0] interpretable_log,  // 供人類除錯
    output logic [31:0]  pattern_hash,       // 模式識別雜湊
    output logic [3:0]   trend_indicator,    // 趨勢指標
    output logic         tensor_valid
);

    // 趨勢計算
    logic signed [31:0] trend;
    logic [3:0] trend_code;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            semantic_tensor <= 512'b0;
            interpretable_log <= 256'b0;
            pattern_hash <= 32'b0;
            trend_indicator <= 4'b0;
            tensor_valid <= 1'b0;
        end else if (boundary_valid) begin
            // 計算趨勢 (使用歷史數據)
            if (history_valid) begin
                trend = contract_bound_value - history_buffer[0];
                
                if (trend > 32'd100)
                    trend_code <= 4'd3;  // 急遽上升
                else if (trend > 32'd10)
                    trend_code <= 4'd2;  // 緩慢上升
                else if (trend < -32'd100)
                    trend_code <= 4'd13; // 急遽下降
                else if (trend < -32'd10)
                    trend_code <= 4'd12; // 緩慢下降
                else
                    trend_code <= 4'd0;  // 平穩
            end else begin
                trend_code <= 4'd0;
            end
            
            // 產生語義張量 (512 bits)
            semantic_tensor <= {
                boundary_key,               // 32 bits
                contract_bound_value,       // 32 bits
                boundary_severity,          // 8 bits
                trend_code,                  // 4 bits
                audit_record[255:128],       // 128 bits
                history_buffer[0],           // 32 bits
                history_buffer[1],           // 32 bits
                history_buffer[2],           // 32 bits
                history_buffer[3],           // 32 bits
                192'b0                        // 剩餘填充
            };
            
            // 可解釋日誌 (供人類除錯)
            interpretable_log <= {
                "XENOA:",
                "Key=", boundary_key[15:0],
                "Val=", contract_bound_value,
                "Sev=", boundary_severity,
                "Trend=", trend_code
            };
            
            // 模式識別雜湊
            pattern_hash <= boundary_key ^ contract_bound_value ^ 
                           {boundary_severity, trend_code};
            
            trend_indicator <= trend_code;
            tensor_valid <= 1'b1;
        end
    end

endmodule
