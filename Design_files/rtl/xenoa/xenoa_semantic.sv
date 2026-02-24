/**
 * XENOA Semantic Standardization Layer
 * 將原始信號轉換為標準化語義記錄
 */
module xenoa_semantic (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自 XR-BUS 的原始信號
    input  logic [4095:0] raw_frame,
    input  logic          frame_valid,
    
    // 信號類型定義
    input  logic [7:0]    signal_type,  // 0:SI/PI, 1:thermal, 2:storage, 3:firmware, 4:jitter, 5:micro-event
    
    // 標準化輸出
    output logic [31:0]   semantic_key,    // 語義鍵值
    output logic [31:0]   normalized_value, // 歸一化數值
    output logic [7:0]    unit_code,       // 單位代碼
    output logic [31:0]   nominal_min,     // 標稱最小值
    output logic [31:0]   nominal_max,     // 標稱最大值
    output logic [31:0]   current_value,   // 當前值
    output logic [31:0]   deviation,       // 偏差值
    output logic [3:0]    severity,        // 嚴重程度 0-15
    output logic          semantic_valid
);

    // 語義鍵值定義
    localparam [31:0] KEY_SI_PI_DRIFT     = 32'h0000_0001;
    localparam [31:0] KEY_THERMAL_DECAY   = 32'h0000_0002;
    localparam [31:0] KEY_SSD_LATENCY     = 32'h0000_0003;
    localparam [31:0] KEY_FIRMWARE_DIVERGE = 32'h0000_0004;
    localparam [31:0] KEY_JITTER_ACCUM    = 32'h0000_0005;
    localparam [31:0] KEY_MICRO_EVENT     = 32'h0000_0006;
    
    // 單位代碼
    localparam [7:0] UNIT_NONE     = 8'd0;
    localparam [7:0] UNIT_MV       = 8'd1;  // 毫伏
    localparam [7:0] UNIT_MA       = 8'd2;  // 毫安
    localparam [7:0] UNIT_MW       = 8'd3;  // 毫瓦
    localparam [7:0] UNIT_CELSIUS  = 8'd4;  // 攝氏度
    localparam [7:0] UNIT_US       = 8'd5;  // 微秒
    localparam [7:0] UNIT_PPM      = 8'd6;  // 百萬分比
    localparam [7:0] UNIT_COUNT    = 8'd7;  // 計數
    
    // 信號解析
    logic [31:0] raw_signal;
    logic [31:0] raw_min, raw_max;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            semantic_key <= 32'b0;
            normalized_value <= 32'b0;
            unit_code <= 8'b0;
            nominal_min <= 32'b0;
            nominal_max <= 32'b0;
            current_value <= 32'b0;
            deviation <= 32'b0;
            severity <= 4'b0;
            semantic_valid <= 1'b0;
        end else if (frame_valid) begin
            // 從訊框中提取原始信號 (簡化版)
            raw_signal <= raw_frame[31:0];
            raw_min <= raw_frame[63:32];
            raw_max <= raw_frame[95:64];
            
            // 根據信號類型進行語義映射
            case (signal_type)
                8'd0: begin // SI/PI drift
                    semantic_key <= KEY_SI_PI_DRIFT;
                    unit_code <= UNIT_MV;
                    nominal_min <= 32'd1100;  // 1.1V
                    nominal_max <= 32'd1300;  // 1.3V
                end
                
                8'd1: begin // thermal decay
                    semantic_key <= KEY_THERMAL_DECAY;
                    unit_code <= UNIT_CELSIUS;
                    nominal_min <= 32'd25;     // 25°C
                    nominal_max <= 32'd85;     // 85°C
                end
                
                8'd2: begin // SSD tail latency
                    semantic_key <= KEY_SSD_LATENCY;
                    unit_code <= UNIT_US;
                    nominal_min <= 32'd100;    // 100µs
                    nominal_max <= 32'd1000;   // 1ms
                end
                
                8'd3: begin // firmware divergence
                    semantic_key <= KEY_FIRMWARE_DIVERGE;
                    unit_code <= UNIT_COUNT;
                    nominal_min <= 32'd0;
                    nominal_max <= 32'd1;
                end
                
                8'd4: begin // jitter accumulation
                    semantic_key <= KEY_JITTER_ACCUM;
                    unit_code <= UNIT_US;
                    nominal_min <= 32'd0;
                    nominal_max <= 32'd1000;
                end
                
                8'd5: begin // micro-event
                    semantic_key <= KEY_MICRO_EVENT;
                    unit_code <= UNIT_NONE;
                    nominal_min <= 32'd0;
                    nominal_max <= 32'd1;
                end
                
                default: begin
                    semantic_key <= 32'b0;
                    unit_code <= UNIT_NONE;
                end
            endcase
            
            // 計算偏差和嚴重程度
            current_value <= raw_signal;
            
            if (raw_signal < nominal_min) begin
                deviation <= nominal_min - raw_signal;
                severity <= 4'd8;  // 欠標
            end else if (raw_signal > nominal_max) begin
                deviation <= raw_signal - nominal_max;
                severity <= 4'd12; // 過標
            end else begin
                deviation <= 32'b0;
                severity <= 4'd0;  // 正常
            end
            
            // 歸一化數值 (0-1000 範圍)
            normalized_value <= (raw_signal - nominal_min) * 1000 / 
                               (nominal_max - nominal_min);
            
            semantic_valid <= 1'b1;
        end
    end

endmodule
