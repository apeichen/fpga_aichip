/**
 * XR-BUS Top Module
 * 整合所有層級，提供完整的因果互連線構
 */
module xrbus_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // 多時鐘域
    input  logic        device_clk,
    input  logic        fabric_clk,
    input  logic        cloud_clk,
    
    // 模組輸入
    input  logic [15:0] src_module_id,
    input  logic [15:0] src_boundary_id,
    input  logic [7:0]  op_code,
    input  logic [1023:0] payload,
    input  logic [9:0]  payload_len,
    input  logic        tx_request,
    
    // 邊界資訊 (來自 XENOS)
    input  logic [15:0] current_boundary,
    input  logic [7:0]  boundary_type,
    
    // 輸出
    output logic [4095:0] rx_frame,
    output logic          rx_valid,
    output logic [15:0]   rx_boundary,
    output logic [15:0]   rx_source,
    
    // 狀態
    output logic          bus_busy,
    output logic          timing_aligned,
    output logic          integrity_ok
);

    // 內部訊號
    logic [63:0] device_time, fabric_time, cloud_time;
    logic [63:0] aligned_time;
    logic [4095:0] framed_packet;
    logic [4095:0] boundary_tagged;
    logic [4095:0] integrity_checked;
    logic [127:0] trace_id, parent_id;
    logic [255:0] frame_hash;
    logic [511:0] signature;
    logic [15:0] dst_boundary;
    logic [31:0] policy_mask;
    logic time_valid, frame_valid, boundary_valid, integrity_valid;
    
    // 時間戳產生器 (簡化版)
    always_ff @(posedge device_clk) device_time <= device_time + 1;
    always_ff @(posedge fabric_clk) fabric_time <= fabric_time + 1;
    always_ff @(posedge cloud_clk) cloud_time <= cloud_time + 1;
    
    // 追蹤 ID 產生器 - 使用從 XENOA 語義鍵值取得的 seed
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trace_id <= 128'h0000_0001_0000_0002_0000_0003_0000_0004;
        end else if (tx_request) begin
            trace_id <= trace_id + 1;
            parent_id <= trace_id;
        end
    end
    
    // 實體化各層
    xrbus_timing u_timing (
        .clk            (clk),
        .rst_n          (rst_n),
        .device_clk     (device_clk),
        .fabric_clk     (fabric_clk),
        .cloud_clk      (cloud_clk),
        .device_timestamp(device_time),
        .fabric_timestamp(fabric_time),
        .cloud_timestamp(cloud_time),
        .jitter_window  (32'd1000),
        .aligned_time   (aligned_time),
        .time_valid     (time_valid),
        .drift_warning  (),
        .jitter_exceeded()
    );
    
    xrbus_frame u_frame (
        .clk            (clk),
        .rst_n          (rst_n),
        .module_id      (src_module_id),
        .boundary_id    (src_boundary_id),
        .op_code        (op_code),
        .device_time    (device_time),
        .fabric_time    (fabric_time),
        .cloud_time     (cloud_time),
        .trace_id       (trace_id),
        .parent_id      (parent_id),
        .semantic_hash  (32'h9e107d9d),
        .payload        (payload),
        .payload_len    (payload_len),
        .version        (32'd2_0),
        .frame_hash     (frame_hash),
        .frame_out      (framed_packet),
        .frame_valid    (frame_valid)
    );
    
    xrbus_boundary u_boundary (
        .clk            (clk),
        .rst_n          (rst_n),
        .boundary_id    (current_boundary),
        .boundary_type  (boundary_type),
        .domain_id      (32'd0),
        .tenant_id      (32'd0),
        .jurisdiction   (256'h0),
        .message_frame  (framed_packet),
        .message_valid  (frame_valid),
        .src_boundary   (rx_boundary),
        .dst_boundary   (dst_boundary),
        .policy_mask    (policy_mask),
        .tagged_frame   (boundary_tagged),
        .frame_tagged   (boundary_valid)
    );
    
    xrbus_integrity u_integrity (
        .clk            (clk),
        .rst_n          (rst_n),
        .protocol_version(8'd2),
        .min_compatible (8'd1),
        .frame_in       (boundary_tagged),
        .frame_valid    (boundary_valid),
        .signing_key    (256'h0102_0304_0506_0000_0102_0304_0506_0000_0102_0304_0506_0000_0102_0304_0506_0000),
        .frame_version  (),
        .version_compatible(integrity_ok),
        .frame_signature(signature),
        .frame_out      (integrity_checked),
        .out_valid      (integrity_valid)
    );
    
    // 輸出
    assign rx_frame = integrity_checked;
    assign rx_valid = integrity_valid;
    assign rx_source = src_module_id;
    assign bus_busy = tx_request | frame_valid | boundary_valid | integrity_valid;
    assign timing_aligned = time_valid;

endmodule
