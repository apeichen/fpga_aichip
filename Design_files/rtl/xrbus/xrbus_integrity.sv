/**
 * XR-BUS Integrity & Version Layer
 * 處理版本相容性和加密簽章
 */
module xrbus_integrity (
    input  logic        clk,
    input  logic        rst_n,
    
    // 協議版本
    input  logic [7:0]  protocol_version,  // 當前版本
    input  logic [7:0]  min_compatible,    // 最小相容版本
    
    // 輸入訊框
    input  logic [4095:0] frame_in,
    input  logic          frame_valid,
    
    // 簽章金鑰 (簡化版)
    input  logic [255:0] signing_key,
    
    // 輸出
    output logic [7:0]   frame_version,
    output logic         version_compatible,
    output logic [511:0] frame_signature,
    output logic [4095:0] frame_out,
    output logic         out_valid
);

    // 版本檢查
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_version <= 8'b0;
            version_compatible <= 1'b0;
            frame_signature <= 512'b0;
            frame_out <= 4096'b0;
            out_valid <= 1'b0;
        end else if (frame_valid) begin
            // 提取版本 (假設存在於訊框的特定位置)
            frame_version <= frame_in[1585:1554];
            
            // 檢查相容性
            if (frame_in[1585:1554] >= min_compatible) begin
                version_compatible <= 1'b1;
                
                // 計算簡易簽章 (XOR 雜湊鏈)
                frame_signature <= {256'b0, 
                                   frame_in[255:0] ^ 
                                   frame_in[511:256] ^ 
                                   frame_in[767:512]};
                
                frame_out <= frame_in;
                out_valid <= 1'b1;
            end else begin
                version_compatible <= 1'b0;
                out_valid <= 1'b0;
            end
        end
    end

endmodule
