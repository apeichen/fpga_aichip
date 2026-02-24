/**
 * XR-BUS Boundary Contract Layer
 * 整合 XENOS 邊界定義
 */
module xrbus_boundary (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自 XENOS 的邊界定義
    input  logic [15:0] boundary_id,
    input  logic [7:0]  boundary_type,  // 0:rack, 1:cluster, 2:domain, 3:tenant
    input  logic [31:0] domain_id,
    input  logic [31:0] tenant_id,
    input  logic [255:0] jurisdiction,   // 司法管轄區
    
    // 來自 XRAD/XENOA 的訊息
    input  logic [4095:0] message_frame,
    input  logic          message_valid,
    
    // 輸出
    output logic [15:0]  src_boundary,
    output logic [15:0]  dst_boundary,
    output logic [31:0]  policy_mask,
    output logic [4095:0] tagged_frame,
    output logic         frame_tagged
);

    // 邊界標記
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tagged_frame <= 4096'b0;
            frame_tagged <= 1'b0;
            src_boundary <= 16'b0;
            dst_boundary <= 16'b0;
            policy_mask <= 32'b0;
        end else if (message_valid) begin
            // 複製原始訊框
            tagged_frame <= message_frame;
            
            // 標記來源邊界
            src_boundary <= boundary_id;
            
            // 根據邊界類型決定目標邊界和政策遮罩
            case (boundary_type)
                8'd0: begin // rack
                    dst_boundary <= boundary_id;
                    policy_mask <= 32'h00000001;
                end
                8'd1: begin // cluster
                    dst_boundary <= boundary_id + 16'h1000;
                    policy_mask <= 32'h00000003;
                end
                8'd2: begin // domain
                    dst_boundary <= {domain_id[15:0], boundary_id[15:8]};
                    policy_mask <= 32'h0000000F;
                end
                8'd3: begin // tenant
                    dst_boundary <= {tenant_id[15:0], boundary_id[15:8]};
                    policy_mask <= 32'hFFFFFFFF;
                end
                default: begin
                    dst_boundary <= boundary_id;
                    policy_mask <= 32'h00000000;
                end
            endcase
            
            frame_tagged <= 1'b1;
        end
    end

endmodule
