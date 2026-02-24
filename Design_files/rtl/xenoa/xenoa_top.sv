/**
 * XENOA Top Module
 * 整合所有語義層，提供完整的語義協定引擎
 */
module xenoa_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame,
    input  logic          xrbus_valid,
    output logic [4095:0] xrbus_out,
    output logic          xrbus_out_valid,
    
    // 來自 XENOS 的邊界資訊
    input  logic [15:0]   boundary_id,
    input  logic [7:0]    boundary_type,
    input  logic [31:0]   contract_id,
    input  logic [31:0]   sla_id,
    
    // 輸出給 XRAD/XRAS
    output logic [511:0]  semantic_tensor,
    output logic [255:0]  interpretable_log,
    output logic [31:0]   pattern_hash,
    output logic          tensor_valid,
    
    // 狀態
    output logic [3:0]    xenoa_state,
    output logic          xenoa_busy
);

    // 內部訊號
    logic [31:0] semantic_key;
    logic [31:0] normalized_value;
    logic [7:0]  unit_code;
    logic [31:0] nominal_min, nominal_max;
    logic [31:0] current_value;
    logic [31:0] deviation;
    logic [3:0]  severity;
    logic        semantic_valid;
    
    logic [63:0] aligned_timestamp;
    logic [31:0] time_qualified_key;
    logic [31:0] time_window_id;
    logic [127:0] causal_chain_id;
    logic        temporal_valid;
    
    logic [31:0] boundary_key;
    logic [31:0] contract_bound_value;
    logic [7:0]  boundary_severity;
    logic [255:0] audit_record;
    logic        boundary_valid;
    
    logic [31:0] history [0:15];
    logic        history_valid;
    
    // 狀態機
    typedef enum logic [3:0] {
        IDLE = 4'd0,
        SEMANTIC = 4'd1,
        TEMPORAL = 4'd2,
        BOUNDARY = 4'd3,
        REASONING = 4'd4,
        DONE = 4'd5
    } state_t;
    
    state_t state, next_state;
    
    // 狀態機
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            xenoa_busy <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    // 下一狀態邏輯
    always_comb begin
        next_state = state;
        xenoa_busy = 1'b1;
        
        case (state)
            IDLE: begin
                if (xrbus_valid) begin
                    next_state = SEMANTIC;
                end else begin
                    xenoa_busy = 1'b0;
                end
            end
            
            SEMANTIC: begin
                if (semantic_valid)
                    next_state = TEMPORAL;
            end
            
            TEMPORAL: begin
                if (temporal_valid)
                    next_state = BOUNDARY;
            end
            
            BOUNDARY: begin
                if (boundary_valid)
                    next_state = REASONING;
            end
            
            REASONING: begin
                if (tensor_valid)
                    next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end
    
    assign xenoa_state = state;
    
    // 歷史數據緩衝區
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                history[i] <= 32'b0;
            end
            history_valid <= 1'b0;
        end else if (boundary_valid) begin
            // 移位
            for (int i = 15; i > 0; i--) begin
                history[i] <= history[i-1];
            end
            history[0] <= contract_bound_value;
            history_valid <= 1'b1;
        end
    end
    
    // 實體化各層
    xenoa_semantic u_semantic (
        .clk            (clk),
        .rst_n          (rst_n),
        .raw_frame      (xrbus_frame),
        .frame_valid    (xrbus_valid && state == SEMANTIC),
        .signal_type    (xrbus_frame[7:0]),  // 從訊框提取
        .semantic_key   (semantic_key),
        .normalized_value(normalized_value),
        .unit_code      (unit_code),
        .nominal_min    (nominal_min),
        .nominal_max    (nominal_max),
        .current_value  (current_value),
        .deviation      (deviation),
        .severity       (severity),
        .semantic_valid (semantic_valid)
    );
    
    xenoa_temporal u_temporal (
        .clk            (clk),
        .rst_n          (rst_n),
        .device_time    (xrbus_frame[103:40]),
        .fabric_time    (xrbus_frame[167:104]),
        .cloud_time     (xrbus_frame[231:168]),
        .time_valid     (xrbus_valid),
        .semantic_key   (semantic_key),
        .normalized_value(normalized_value),
        .severity       (severity),
        .semantic_valid (semantic_valid),
        .aligned_timestamp(aligned_timestamp),
        .time_qualified_key(time_qualified_key),
        .time_window_id (time_window_id),
        .causal_chain_id(causal_chain_id),
        .temporal_valid (temporal_valid)
    );
    
    xenoa_boundary_map u_boundary (
        .clk            (clk),
        .rst_n          (rst_n),
        .boundary_id    (boundary_id),
        .boundary_type  (boundary_type),
        .contract_id    (contract_id),
        .sla_id         (sla_id),
        .time_qualified_key(time_qualified_key),
        .normalized_value(normalized_value),
        .severity       (severity),
        .causal_chain_id(causal_chain_id),
        .temporal_valid (temporal_valid),
        .boundary_key   (boundary_key),
        .contract_bound_value(contract_bound_value),
        .boundary_severity(boundary_severity),
        .audit_record   (audit_record),
        .boundary_valid (boundary_valid)
    );
    
    xenoa_reasoning u_reasoning (
        .clk            (clk),
        .rst_n          (rst_n),
        .boundary_key   (boundary_key),
        .contract_bound_value(contract_bound_value),
        .boundary_severity(boundary_severity),
        .audit_record   (audit_record),
        .boundary_valid (boundary_valid),
        .history_buffer (history),
        .history_valid  (history_valid),
        .semantic_tensor(semantic_tensor),
        .interpretable_log(interpretable_log),
        .pattern_hash   (pattern_hash),
        .trend_indicator(),
        .tensor_valid   (tensor_valid)
    );
    
    // XR-BUS 輸出
    assign xrbus_out = {semantic_tensor, interpretable_log};
    assign xrbus_out_valid = tensor_valid;

endmodule
