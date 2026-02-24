/**
 * XENOA Temporal Alignment Layer
 * 處理跨模組的時間同步與因果關係追蹤
 */
module xenoa_temporal (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自 XR-BUS 的時間戳
    input  logic [63:0] device_timestamp,
    input  logic [63:0] fabric_timestamp,
    input  logic [63:0] cloud_timestamp,
    input  logic        timestamp_valid,
    
    // 因果鏈介面
    input  logic [127:0] parent_chain_id,
    input  logic         chain_valid,
    
    // 輸出
    output logic [127:0] chain_id,
    output logic [63:0]  aligned_timestamp,
    output logic [31:0]  causal_distance,
    output logic         temporal_valid,
    
    // 漂移監測
    output logic [31:0]  device_drift,
    output logic [31:0]  fabric_drift,
    output logic [31:0]  cloud_drift,
    output logic         drift_warning
);

    // ======================================================================
    // 內部訊號
    // ======================================================================
    logic [63:0] device_time_last, fabric_time_last, cloud_time_last;
    logic [31:0] device_drift_acc, fabric_drift_acc, cloud_drift_acc;
    logic [63:0] temporal_base;
    logic [127:0] chain_counter;
    
    // ======================================================================
    // XENOA 常數定義
    // ======================================================================
    // 因果種子值 - 取代 'hxenoa_causal_seed
    localparam logic [127:0] XENOA_CAUSAL_SEED = 128'hA1B2_C3D4_E5F6_7890_1234_5678_9ABC_DEF0;
    
    // 漂移容忍閾值 (ppm)
    localparam logic [31:0] DRIFT_THRESHOLD = 32'd100;  // 100 ppm
    
    // 最大因果距離
    localparam logic [31:0] MAX_CAUSAL_DISTANCE = 32'd1000;
    // ======================================================================
    
    // 時間戳鎖存與漂移計算
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            device_time_last <= 64'h0;
            fabric_time_last <= 64'h0;
            cloud_time_last <= 64'h0;
            device_drift_acc <= 32'h0;
            fabric_drift_acc <= 32'h0;
            cloud_drift_acc <= 32'h0;
            drift_warning <= 1'b0;
        end else if (timestamp_valid) begin
            // 計算各時鐘域的漂移
            if (device_time_last != 64'h0) begin
                device_drift_acc <= (device_timestamp - device_time_last) * 1000000 / 64'd1000;
            end
            if (fabric_time_last != 64'h0) begin
                fabric_drift_acc <= (fabric_timestamp - fabric_time_last) * 1000000 / 64'd1000;
            end
            if (cloud_time_last != 64'h0) begin
                cloud_drift_acc <= (cloud_timestamp - cloud_time_last) * 1000000 / 64'd1000;
            end
            
            // 更新上次值
            device_time_last <= device_timestamp;
            fabric_time_last <= fabric_timestamp;
            cloud_time_last <= cloud_timestamp;
            
            // 檢查是否超過閾值
            drift_warning <= (device_drift_acc > DRIFT_THRESHOLD) ||
                            (fabric_drift_acc > DRIFT_THRESHOLD) ||
                            (cloud_drift_acc > DRIFT_THRESHOLD);
        end
    end
    
    assign device_drift = device_drift_acc;
    assign fabric_drift = fabric_drift_acc;
    assign cloud_drift = cloud_drift_acc;
    
    // 因果鏈管理
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chain_counter <= 128'h0;
            temporal_base <= 64'h0;
            causal_distance <= 32'h0;
        end else begin
            if (chain_valid) begin
                // 繼承父鏈 ID，並增加計數器
                chain_counter <= parent_chain_id + 1;
                causal_distance <= causal_distance + 1;
                
                // 檢查因果距離
                if (causal_distance > MAX_CAUSAL_DISTANCE) begin
                    causal_distance <= MAX_CAUSAL_DISTANCE;
                end
            end
            
            // 更新時間基數（使用最快時鐘域）
            temporal_base <= (device_timestamp > fabric_timestamp) ? 
                             (device_timestamp > cloud_timestamp ? device_timestamp : cloud_timestamp) :
                             (fabric_timestamp > cloud_timestamp ? fabric_timestamp : cloud_timestamp);
        end
    end
    
    // 因果鏈 ID 產生
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chain_id <= XENOA_CAUSAL_SEED;  // ✅ 使用 localparam，取代 'hxenoa_causal_seed
        end else if (chain_valid) begin
            chain_id <= chain_counter;
        end
    end
    
    // 對齊時間戳輸出
    assign aligned_timestamp = temporal_base;
    assign temporal_valid = timestamp_valid;

endmodule
