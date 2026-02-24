/**
 * XENOS (XR Edge Node Operating System) 頂層模組
 * 整合邊界檢查器、狀態機和控制邏輯
 */
module xenos_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自XSM的數據
    input  logic [11:0] xsm_valid,
    input  logic [31:0] xsm_data [0:11],
    
    // 邊界參數
    input  logic [31:0] voltage_min [0:11],
    input  logic [31:0] voltage_max [0:11],
    input  logic [31:0] current_max [0:11],
    input  logic [31:0] temp_max [0:11],
    
    // 狀態輸出
    output logic [2:0]  current_state,   // 當前狀態
    output logic        fault_detected,  // 故障檢測
    output logic [3:0]  fault_code,      // 故障代碼
    output logic [3:0]  fault_channel,   // 故障通道
    
    // 控制輸出
    output logic        safe_mode_active,
    output logic        recovery_in_progress,
    
    // 看門狗
    input  logic        wdg_trigger,
    output logic        wdg_reset
);

    // 內部連線
    logic [11:0] channel_fault;
    logic [3:0]  channel_fault_code [0:11];
    logic [2:0]  fsm_state;
    logic        boundary_violation;
    
    // 實體化邊界檢查器
    xenos_boundary u_boundary (
        .clk            (clk),
        .rst_n          (rst_n),
        .xsm_valid      (xsm_valid),
        .xsm_data       (xsm_data),
        .voltage_min    (voltage_min),
        .voltage_max    (voltage_max),
        .current_max    (current_max),
        .temp_max       (temp_max),
        .channel_fault  (channel_fault),
        .fault_code     (channel_fault_code),
        .violation      (boundary_violation)
    );
    
    // 實體化狀態機
    xenos_fsm u_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .fault_input    (boundary_violation),
        .wdg_trigger    (wdg_trigger),
        .current_state  (fsm_state),
        .fault_detected (fault_detected),
        .safe_mode      (safe_mode_active),
        .recovery       (recovery_in_progress),
        .wdg_reset      (wdg_reset)
    );
    
    // 故障聚合
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_code <= 4'b0;
            fault_channel <= 4'b0;
        end else begin
            for (int i = 0; i < 12; i++) begin
                if (channel_fault[i]) begin
                    fault_code <= channel_fault_code[i];
                    fault_channel <= i;
                end
            end
        end
    end
    
    assign current_state = fsm_state;

endmodule
