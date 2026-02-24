/**
 * XR-BUS Timing Contract Layer
 * 處理多時鐘域對齊和因果順序
 */
module xrbus_timing (
    input  logic        clk,
    input  logic        rst_n,
    
    // 多時鐘輸入
    input  logic        device_clk,
    input  logic        fabric_clk,
    input  logic        cloud_clk,
    
    input  logic [63:0] device_timestamp,
    input  logic [63:0] fabric_timestamp,
    input  logic [63:0] cloud_timestamp,
    
    // 抖動容忍視窗
    input  logic [31:0] jitter_window,  // 最大允許抖動
    
    // 輸出
    output logic [63:0] aligned_time,    // 對齊後的時間
    output logic        time_valid,
    output logic        drift_warning,   // 漂移警告
    output logic        jitter_exceeded  // 抖動超出
);

    // 時鐘漂移計算
    logic signed [63:0] device_fabric_delta;
    logic signed [63:0] fabric_cloud_delta;
    logic signed [63:0] accumulated_drift;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aligned_time <= 64'b0;
            time_valid <= 1'b0;
            drift_warning <= 1'b0;
            jitter_exceeded <= 1'b0;
            device_fabric_delta <= 64'b0;
            fabric_cloud_delta <= 64'b0;
        end else begin
            // 計算時鐘差異
            device_fabric_delta <= device_timestamp - fabric_timestamp;
            fabric_cloud_delta <= fabric_timestamp - cloud_timestamp;
            
            // 累積漂移
            accumulated_drift <= device_fabric_delta + fabric_cloud_delta;
            
            // 檢查抖動是否超出容忍視窗
            if (($signed(device_fabric_delta) > $signed(jitter_window)) ||
                ($signed(fabric_cloud_delta) > $signed(jitter_window))) begin
                jitter_exceeded <= 1'b1;
            end
            
            // 漂移警告 (累積超過 1ms)
            if ($signed(accumulated_drift) > 64'd1000000) begin
                drift_warning <= 1'b1;
            end
            
            // 使用雲端時間為主，補償漂移
            aligned_time <= cloud_timestamp + accumulated_drift;
            time_valid <= 1'b1;
        end
    end

endmodule
