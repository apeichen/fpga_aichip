/**
 * XR-BUS Frame Format Layer
 * 定義所有 XR 模組間通訊的標準訊框結構
 */
module xrbus_frame (
    input  logic        clk,
    input  logic        rst_n,
    
    // 輸入訊框
    input  logic [15:0] module_id,      // 來源模組 ID
    input  logic [15:0] boundary_id,    // 邊界 ID (XENOS 定義)
    input  logic [7:0]  op_code,        // 操作碼
    
    // 多時鐘對齊
    input  logic [63:0] device_time,    // 裝置時間
    input  logic [63:0] fabric_time,    // 結構時間
    input  logic [63:0] cloud_time,     // 雲端時間
    
    // 因果鏈
    input  logic [127:0] trace_id,      // 追蹤 ID
    input  logic [127:0] parent_id,     // 父事件 ID
    input  logic [31:0]  semantic_hash, // 語義錨點 (XENOA)
    
    // 載荷
    input  logic [1023:0] payload,      // 訊號或策略向量
    input  logic [9:0]    payload_len,  // 有效載荷長度
    
    // 完整性
    input  logic [31:0]   version,      // 版本標記
    output logic [255:0]  frame_hash,   // 完整性雜湊
    output logic [4095:0] frame_out,    // 完整訊框
    output logic          frame_valid
);

    // 訊框結構定義
    // [0:15]    module_id
    // [16:31]   boundary_id
    // [32:39]   op_code
    // [40:103]  device_time (64 bits)
    // [104:167] fabric_time (64 bits)
    // [168:231] cloud_time (64 bits)
    // [232:359] trace_id (128 bits)
    // [360:487] parent_id (128 bits)
    // [488:519] semantic_hash (32 bits)
    // [520:1543] payload (1024 bits)
    // [1544:1553] payload_len (10 bits)
    // [1554:1585] version (32 bits)
    // [1586:4095] 保留
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_out <= 4096'b0;
            frame_valid <= 1'b0;
            frame_hash <= 256'b0;
        end else begin
            // 組裝訊框
            frame_out[15:0]    <= module_id;
            frame_out[31:16]   <= boundary_id;
            frame_out[39:32]   <= op_code;
            frame_out[103:40]  <= device_time;
            frame_out[167:104] <= fabric_time;
            frame_out[231:168] <= cloud_time;
            frame_out[359:232] <= trace_id;
            frame_out[487:360] <= parent_id;
            frame_out[519:488] <= semantic_hash;
            frame_out[1543:520] <= payload;
            frame_out[1553:1544] <= payload_len;
            frame_out[1585:1554] <= version;
            
            // 計算簡易雜湊 (CRC32 簡化版)
            frame_hash <= {module_id, boundary_id, op_code} ^ 
                         {device_time[31:0], fabric_time[31:0]} ^
                         {trace_id[63:0], parent_id[63:0]};
            
            frame_valid <= 1'b1;
        end
    end

endmodule
