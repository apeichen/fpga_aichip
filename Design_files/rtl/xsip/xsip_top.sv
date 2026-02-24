/**
 * XSIP Top Module
 * 整合所有 XSIP 層，提供完整的硬體整合平面
 */
module xsip_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame_in,
    input  logic          frame_valid_in,
    output logic [4095:0] xrbus_frame_out,
    output logic          frame_valid_out,
    
    // PCIe 介面 (可選)
    input  logic [511:0]  pcie_vendor_in,
    input  logic          pcie_valid_in,
    output logic [511:0]  pcie_vendor_out,
    output logic          pcie_valid_out,
    
    // 硬體信號 (來自 PCB)
    // IC級遙測
    inout  wire         i3c_scl,
    inout  wire         i3c_sda,
    input  logic [31:0] pmic_voltage [0:7],
    input  logic [31:0] pmic_current [0:7],
    input  logic [15:0] temp_sensors [0:15],
    input  logic [31:0] voltage_margin [0:7],
    input  logic [31:0] current_sense [0:7],
    input  logic [31:0] dram_ecc_count,
    input  logic [31:0] nand_endurance [0:7],
    
    // 板級遙測
    input  logic [31:0] power_rails [0:15],
    input  logic [7:0]  fan_speed [0:7],
    input  logic [15:0] thermal_zone [0:7],
    input  logic [31:0] vrm_output [0:7],
    input  logic [7:0]  pll_lock [0:7],
    input  logic [15:0] pll_jitter [0:7],
    input  logic [15:0] ambient_temp,
    
    // 控制介面
    output logic        ec_reset,
    output logic        ec_shutdown,
    output logic [7:0]  ec_gpio [0:15],
    output logic [31:0] target_voltage [0:7],
    output logic [31:0] target_frequency [0:7],
    output logic [15:0] power_cycle_gates,
    
    // 除錯介面
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    output logic        jtag_tdo,
    
    // 啟動狀態
    output logic [7:0]  xsip_state,
    output logic        xsip_ready,
    output logic [31:0] telemetry_timestamp
);

    // 內部信號
    logic [4095:0] ic_telemetry;
    logic [255:0]  ic_summary;
    logic          ic_valid;
    
    logic [4095:0] board_telemetry;
    logic [255:0]  board_summary;
    logic          board_valid;
    
    logic [8191:0] telemetry_db;
    logic [15:0]   sample_cnt;
    logic          db_valid;
    
    logic [31:0]   ec_result;
    logic [7:0]    ec_status;
    logic          ec_done;
    
    logic [31:0]   power_response;
    logic          power_ack;
    
    logic [31:0]   debug_result;
    logic          debug_ready;
    
    logic          xrad_en, xenoa_en, xenos_en, xaps_en, xras_en, xrst_en;
    logic [7:0]    act_state;
    logic          act_complete;
    logic [4095:0] xr_config;
    logic          config_valid;
    
    // 常數陣列定義 (使用 generate 或直接在連接時定義)
    logic [15:0] serdes_eye_default [0:7];
    logic [15:0] serdes_jitter_default [0:7];
    logic [31:0] rail_current_default [0:15];
    logic [15:0] rail_voltage_default [0:15];
    logic [31:0] pll_frequency_default [0:7];
    logic [31:0] osc_drift_default [0:3];
    logic [31:0] osc_frequency_default [0:3];
    logic [31:0] current_frequency_default [0:7];
    logic [31:0] voltage_min_default [0:7];
    logic [31:0] voltage_max_default [0:7];
    logic [31:0] frequency_min_default [0:7];
    logic [31:0] frequency_max_default [0:7];
    logic [7:0]  soc_debug_hooks_default [0:15];
    
    integer i;
    
    // 初始化所有預設陣列
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            serdes_eye_default[i] = 16'd0;
            serdes_jitter_default[i] = 16'd0;
            pll_frequency_default[i] = 32'd1000000000;
            current_frequency_default[i] = 32'd1000000000;
            voltage_min_default[i] = 32'd700000;
            voltage_max_default[i] = 32'd900000;
            frequency_min_default[i] = 32'd500000000;
            frequency_max_default[i] = 32'd1500000000;
        end
        
        for (i = 0; i < 16; i = i + 1) begin
            rail_current_default[i] = 32'd0;
            rail_voltage_default[i] = 16'd0;
        end
        
        for (i = 0; i < 4; i = i + 1) begin
            osc_drift_default[i] = 32'd0;
            osc_frequency_default[i] = 32'd100000000;
        end
        
        for (i = 0; i < 16; i = i + 1) begin
            soc_debug_hooks_default[i] = 8'd0;
        end
    end
    
    // 實體化子模組
    xsip_telemetry_ic u_ic (
        .clk                (clk),
        .rst_n              (rst_n),
        .i3c_scl            (i3c_scl),
        .i3c_sda            (i3c_sda),
        .i3c_valid          (1'b1),
        .pmic_voltage       (pmic_voltage),
        .pmic_current       (pmic_current),
        .pmic_status        (8'hFF),
        .temp_sensors       (temp_sensors),
        .temp_valid         (8'hFF),  // 改為 8 bits
        .voltage_margin     (voltage_margin),
        .margin_valid       (8'hFF),
        .current_sense      (current_sense),
        .serdes_eye         (serdes_eye_default),
        .serdes_jitter      (serdes_jitter_default),
        .serdes_status      (8'hFF),
        .dram_ecc_count     (dram_ecc_count),
        .dram_training_status(8'hFF),
        .dram_valid         (1'b1),
        .nand_endurance     (nand_endurance),
        .nand_wear_level    (32'd50),
        .telemetry_data     (ic_telemetry),
        .telemetry_summary  (ic_summary),
        .sample_timestamp   (telemetry_timestamp),
        .telemetry_valid    (ic_valid)
    );
    
    xsip_telemetry_board u_board (
        .clk                (clk),
        .rst_n              (rst_n),
        .power_rails        (power_rails),
        .rail_current       (rail_current_default),
        .rail_voltage       (rail_voltage_default),
        .fan_speed          (fan_speed),
        .thermal_zone       (thermal_zone),
        .fan_status         (8'hFF),
        .vrm_output         (vrm_output),
        .vrm_efficiency     (32'd90),
        .vrm_status         (8'hFF),
        .pll_lock           (pll_lock),
        .pll_jitter         (pll_jitter),
        .pll_frequency      (pll_frequency_default),
        .osc_drift          (osc_drift_default),
        .osc_frequency      (osc_frequency_default),
        .ambient_temp       (ambient_temp),
        .ambient_humidity   (16'd50),
        .air_flow           (16'd100),
        .board_telemetry    (board_telemetry),
        .board_summary      (board_summary),
        .total_power        (),
        .thermal_status     (),
        .board_valid        (board_valid)
    );
    
    xsip_telemetry_aggregator u_agg (
        .clk                (clk),
        .rst_n              (rst_n),
        .ic_telemetry       (ic_telemetry),
        .ic_summary         (ic_summary),
        .ic_valid           (ic_valid),
        .board_telemetry    (board_telemetry),
        .board_summary      (board_summary),
        .board_valid        (board_valid),
        .pcie_vendor_message(pcie_vendor_out),
        .pcie_valid         (pcie_valid_out),
        .xrbus_telemetry    (xrbus_frame_out),
        .xrbus_valid        (frame_valid_out),
        .telemetry_database (telemetry_db),
        .sample_count       (sample_cnt),
        .database_valid     (db_valid)
    );
    
    xsip_control_ec u_ec (
        .clk                (clk),
        .rst_n              (rst_n),
        .control_code       (xrbus_frame_in[7:0]),
        .control_param      (xrbus_frame_in[63:32]),
        .control_request    (frame_valid_in),
        .ec_reset           (ec_reset),
        .ec_shutdown        (ec_shutdown),
        .ec_recovery        (),
        .ec_gpio            (ec_gpio),
        .ec_status          (8'hFF),
        .ec_ready           (1'b1),
        .control_result     (ec_result),
        .control_status     (ec_status),
        .control_done       (ec_done)
    );
    
    xsip_control_power u_power (
        .clk                (clk),
        .rst_n              (rst_n),
        .ovp_trip_reset     (),
        .ocp_trip_reset     (),
        .oct_trip_reset     (),
        .current_voltage    (pmic_voltage),
        .current_frequency  (current_frequency_default),
        .target_voltage     (target_voltage),
        .target_frequency   (target_frequency),
        .voltage_margin_enable(),
        .power_cycle_gates  (power_cycle_gates),
        .power_domain_reset (),
        .voltage_min        (voltage_min_default),
        .voltage_max        (voltage_max_default),
        .frequency_min      (frequency_min_default),
        .frequency_max      (frequency_max_default),
        .control_type       (xrbus_frame_in[15:8]),
        .control_value      (xrbus_frame_in[95:64]),
        .target_domain      (xrbus_frame_in[19:16]),
        .control_valid      (frame_valid_in),
        .control_response   (power_response),
        .control_ack        (power_ack)
    );
    
    xsip_control_debug u_debug (
        .clk                (clk),
        .rst_n              (rst_n),
        .jtag_tck           (jtag_tck),
        .jtag_tms           (jtag_tms),
        .jtag_tdi           (jtag_tdi),
        .jtag_tdo           (jtag_tdo),
        .swd_clk            (1'b0),
        .swd_io             (),
        .boundary_scan_chain(),
        .scan_input         (16'd0),
        .debug_proxy_enable (1'b1),
        .debug_proxy_active (),
        .firmware_port_in   (32'd0),
        .firmware_port_out  (),
        .bmc_command        (32'd0),
        .bmc_response       (),
        .soc_debug_hooks    (soc_debug_hooks_default),
        .debug_command      (xrbus_frame_in[23:16]),
        .debug_data         (xrbus_frame_in[127:96]),
        .debug_valid        (frame_valid_in),
        .debug_result       (debug_result),
        .debug_ready        (debug_ready)
    );
    
    xsip_activation u_activation (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .pcie_detected          (pcie_valid_in),
        .xrbus_detected         (frame_valid_in),
        .power_good             (1'b1),
        .telemetry_schema_version(32'd1),
        .vendor_id              (256'h58525F56454E444F52),
        .product_id             (256'h585349505F3031),
        .xrad_enable            (xrad_en),
        .xenoa_enable           (xenoa_en),
        .xenos_enable           (xenos_en),
        .xaps_enable            (xaps_en),
        .xras_enable            (xras_en),
        .xrst_enable            (xrst_en),
        .activation_state       (act_state),
        .activation_timestamp   (),
        .activation_complete    (act_complete),
        .xr_config              (xr_config),
        .config_valid           (config_valid)
    );
    
    // 狀態輸出
    assign xsip_state = act_state;
    assign xsip_ready = act_complete;

endmodule
