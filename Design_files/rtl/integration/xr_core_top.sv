/**
 * XR CORE 整合模組
 * 整合XSM 12通道和XENOS邊界治理器
 */
module xr_core_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // 外部觸發輸入
    input  logic [11:0] ext_trigger,
    
    // 邊界參數配置
    input  logic [31:0] vmin_config [0:11],
    input  logic [31:0] vmax_config [0:11],
    input  logic [31:0] imax_config [0:11],
    input  logic [31:0] tmax_config [0:11],
    
    // 掃描模式配置
    input  logic [1:0]  scan_mode,
    
    // 狀態輸出
    output logic [2:0]  system_state,
    output logic        fault_alarm,
    output logic [3:0]  fault_code,
    output logic [3:0]  fault_source,
    
    // 數據輸出
    output logic [31:0] monitor_data [0:11],
    output logic        data_ready,
    
    // 中斷
    output logic        irq_fault,
    output logic        irq_data_ready
);

    // 內部連線
    logic [11:0] xsm_valid;
    logic [31:0] xsm_data [0:11];
    logic        xsm_done;
    
    logic [11:0] xenos_ch_fault;
    logic [3:0]  xenos_fault_code [0:11];
    logic        xenos_violation;
    logic [2:0]  xenos_state;
    
    // 實體化XSM
    xsm_capture_12channel u_xsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .ch_trigger     (ext_trigger),
        .ch_sample_valid(xsm_valid),
        .ch_sample_data (xsm_data),
        .scan_mode      (scan_mode),
        .sample_rate    (8'd10),
        .capture_done   (xsm_done),
        .fifo_full      ()
    );
    
    // 實體化XENOS
    xenos_top u_xenos (
        .clk            (clk),
        .rst_n          (rst_n),
        .xsm_valid      (xsm_valid),
        .xsm_data       (xsm_data),
        .voltage_min    (vmin_config),
        .voltage_max    (vmax_config),
        .current_max    (imax_config),
        .temp_max       (tmax_config),
        .current_state  (xenos_state),
        .fault_detected (fault_alarm),
        .fault_code     (fault_code),
        .fault_channel  (fault_source),
        .safe_mode_active(),
        .recovery_in_progress(),
        .wdg_trigger    (1'b0),
        .wdg_reset      ()
    );
    
    // 輸出分配
    assign system_state = xenos_state;
    assign monitor_data = xsm_data;
    assign data_ready = xsm_done;
    
    // 中斷產生
    assign irq_fault = fault_alarm;
    assign irq_data_ready = xsm_done;

endmodule
