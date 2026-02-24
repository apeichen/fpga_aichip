/**
 * FPGA Top Level Integration Module
 * 整合所有 XR 系統核心組件
 */
module fpga_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // 時鐘與計時參考 (給 xrbus)
    input  logic        device_clk,
    input  logic        fabric_clk,
    input  logic        cloud_clk,
    
    // 外部硬體介面 (給 xsip)
    inout  wire         i3c_scl,
    inout  wire         i3c_sda,
    input  logic [31:0] pmic_voltage [0:7],
    input  logic [31:0] pmic_current [0:7],
    input  logic [15:0] temp_sensors [0:15],
    input  logic [31:0] power_rails [0:15],
    
    // API 介面 (給外部應用，對接 xaps)
    input  logic [31:0]   api_endpoint,
    input  logic [7:0]    api_method,
    input  logic [1023:0] api_payload,
    input  logic          api_request,
    output logic [31:0]   api_status,
    output logic [1023:0] api_response,
    output logic          api_response_valid,

    // 狀態指示
    output logic          system_ready,
    output logic          fault_alarm
);

    // --- 內部連線訊號定義 ---
    
    // XR-BUS 主幹
    logic [4095:0] main_bus_frame;
    logic          main_bus_valid;
    
    // XENOS 邊界資訊 (廣播至多個模組)
    logic [2:0]  xenos_state_sig;
    logic        xenos_fault_sig;
    logic [15:0] current_boundary_sig;
    
    // XENOA 語義張量 (傳送至 XRAS)
    logic [511:0] semantic_tensor_sig;
    logic         tensor_valid_sig;
    
    // XRAD AI 結果
    logic [31:0] ai_result_sig;
    logic        ai_busy_sig;

    // XRAS 封包 (傳送至 XRST)
    logic [4095:0] xras_packet;
    logic          xras_packet_valid;

    // --- 1. XSIP: 硬體整合平面 (實體層與遙測) ---
    xsip_top u_xsip (
        .clk                (clk),
        .rst_n              (rst_n),
        .xrbus_frame_in     (main_bus_frame),
        .frame_valid_in     (main_bus_valid),
        .i3c_scl            (i3c_scl),
        .i3c_sda            (i3c_sda),
        .pmic_voltage       (pmic_voltage),
        .pmic_current       (pmic_current),
        .temp_sensors       (temp_sensors),
        .power_rails        (power_rails),
        .xsip_ready         (system_ready),
        .telemetry_timestamp()
    );

    // --- 2. XENOS: 邊緣節點作業系統 (邊界監控與故障檢測) ---
    xenos_top u_xenos (
        .clk            (clk),
        .rst_n          (rst_n),
        .xsm_valid      (12'hFFF),
        .xsm_data       ({pmic_voltage, 4'b0}), // 補4個0變成12個元素，符合 xsm_data [0:11]
        .voltage_min    ('{default: 32'd700000}),
        .voltage_max    ('{default: 32'd900000}),
        .current_state  (xenos_state_sig),
        .fault_detected (xenos_fault_sig),
        .safe_mode_active(fault_alarm)
    );

    // --- 3. XR-BUS: 因果互連線構 (數據通訊骨幹) ---
    xrbus_top u_xrbus (
        .clk            (clk),
        .rst_n          (rst_n),
        .device_clk     (device_clk),
        .fabric_clk     (fabric_clk),
        .cloud_clk      (cloud_clk),
        .current_boundary(16'h0001),
        .tx_request     (api_request),
        .rx_frame       (main_bus_frame),
        .rx_valid       (main_bus_valid),
        .bus_busy       (),
        .integrity_ok   ()
    );

    // --- 4. XENOA: 語義協定引擎 (數據理解) ---
    xenoa_top u_xenoa (
        .clk            (clk),
        .rst_n          (rst_n),
        .xrbus_frame    (main_bus_frame),
        .xrbus_valid    (main_bus_valid),
        .boundary_id    (16'h0001),
        .semantic_tensor(semantic_tensor_sig),
        .tensor_valid   (tensor_valid_sig)
    );

    // --- 5. XRAD: 高級驅動與 AI 加速器 ---
    xrad_top u_xrad (
        .clk            (clk),
        .rst_n          (rst_n),
        .xsm_ch_valid   (12'h00F),
        .xsm_ch_data    ({pmic_voltage, 4'b0}), // 同樣補4個0，符合 xsm_ch_data [0:11]
        .xenos_state    (xenos_state_sig),
        .xenos_fault    (xenos_fault_sig),
        .ai_result      (ai_result_sig),
        .ai_busy        (ai_busy_sig)
    );

    // --- 6. XROG: 軌道治理與政策控管 ---
    xrog_top u_xrog (
        .clk            (clk),
        .rst_n          (rst_n),
        .xrbus_frame_in (main_bus_frame),
        .frame_valid_in (main_bus_valid),
        .orbit_config   ('{default: 8'h01}),
        .config_count   (4'd8),
        .orbit_stability()
    );

    // --- 7. XRAS: 可靠性服務與 SLA 評分 ---
    xras_top u_xras (
        .clk            (clk),
        .rst_n          (rst_n),
        .semantic_tensor(semantic_tensor_sig),
        .tensor_valid   (tensor_valid_sig),
        .target_reliability(32'd999),
        .current_reliability(),
        .packet_valid   (xras_packet_valid),
        .settlement_packet(xras_packet)
    );

    // --- 8. XREK: 交換核心與工作流程協調 ---
    xrek_top u_xrek (
        .clk            (clk),
        .rst_n          (rst_n),
        .xrbus_frame_in (main_bus_frame),
        .frame_valid_in (main_bus_valid),
        .local_module_id(32'hAAAA_BBBB),
        .xrek_ready     ()
    );

    // --- 9. XRST: 可靠性結算與代幣化 ---
    xrst_top u_xrst (
        .clk                (clk),
        .rst_n              (rst_n),
        .evidence_packet    (xras_packet),
        .packet_valid       (xras_packet_valid),
        .stake_requirement  (32'd1000),
        .total_settlements  (),
        .settlement_valid   ()
    );

    // --- 10. XAPS: API 與應用服務層 (外部存取點) ---
    xaps_top u_xaps (
        .clk            (clk),
        .rst_n          (rst_n),
        .xrbus_frame_in (main_bus_frame),
        .frame_valid_in (main_bus_valid),
        .api_endpoint   (api_endpoint),
        .api_method     (api_method),
        .api_payload    (api_payload),
        .api_request    (api_request),
        .api_status     (api_status),
        .api_response   (api_response),
        .api_response_valid(api_response_valid)
    );

endmodule
