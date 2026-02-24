/**
 * XSIP Board-Level Telemetry Interface
 * 收集板級信號：電源軌、風扇、VRM、PLL、振盪器等
 */
module xsip_telemetry_board (
    input  logic        clk,
    input  logic        rst_n,
    
    // 電源軌
    input  logic [31:0] power_rails [0:15],
    input  logic [31:0] rail_current [0:15],
    input  logic [15:0] rail_voltage [0:15],
    
    // 風扇/散熱區
    input  logic [7:0]  fan_speed [0:7],
    input  logic [15:0] thermal_zone [0:7],
    input  logic [7:0]  fan_status,
    
    // VRM 穩定性
    input  logic [31:0] vrm_output [0:7],
    input  logic [31:0] vrm_efficiency,
    input  logic [7:0]  vrm_status,
    
    // PLL 鎖定/抖動
    input  logic [7:0]  pll_lock [0:7],
    input  logic [15:0] pll_jitter [0:7],
    input  logic [31:0] pll_frequency [0:7],
    
    // 振盪器漂移
    input  logic [31:0] osc_drift [0:3],
    input  logic [31:0] osc_frequency [0:3],
    
    // 環境感測器
    input  logic [15:0] ambient_temp,
    input  logic [15:0] ambient_humidity,
    input  logic [15:0] air_flow,
    
    // 板級輸出
    output logic [4095:0] board_telemetry,
    output logic [255:0]  board_summary,
    output logic [31:0]   total_power,
    output logic [7:0]    thermal_status,
    output logic          board_valid
);

    logic [31:0] power_total;
    logic [15:0] max_temp;
    logic [7:0]  thermal_grade;
    integer i;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            board_telemetry <= 4096'b0;
            board_summary <= 256'b0;
            total_power <= 32'b0;
            thermal_status <= 8'b0;
            board_valid <= 1'b0;
            power_total <= 32'b0;
            max_temp <= 16'b0;
        end else begin
            // 計算總功耗
            power_total = 0;
            for (i = 0; i < 16; i = i + 1) begin
                power_total = power_total + power_rails[i];
            end
            
            // 找出最高溫度
            max_temp = 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (thermal_zone[i] > max_temp) begin
                    max_temp = thermal_zone[i];
                end
            end
            
            // 熱狀態評估
            if (max_temp > 16'd85) begin
                thermal_grade <= 8'd3; // 過熱
            end else if (max_temp > 16'd70) begin
                thermal_grade <= 8'd2; // 高溫
            end else if (max_temp > 16'd50) begin
                thermal_grade <= 8'd1; // 溫和
            end else begin
                thermal_grade <= 8'd0; // 正常
            end
            
            // 更新輸出
            total_power <= power_total;
            thermal_status <= thermal_grade;
            
            // 封裝板級遙測
            board_telemetry[31:0] <= power_rails[0];
            board_telemetry[63:32] <= fan_speed[0];
            board_telemetry[95:64] <= thermal_zone[0];
            board_telemetry[127:96] <= vrm_output[0];
            board_telemetry[159:128] <= {8'b0, pll_lock[0]};
            board_telemetry[191:160] <= pll_jitter[0];
            board_telemetry[223:192] <= pll_frequency[0];
            board_telemetry[255:224] <= osc_drift[0];
            board_telemetry[287:256] <= {ambient_temp, ambient_humidity};
            
            // 板級摘要
            board_summary <= {
                power_total[31:0],
                max_temp[15:0],
                thermal_grade[7:0],
                vrm_efficiency[31:0],
                {8'b0, pll_lock[0]},
                osc_drift[0][31:0],
                air_flow[15:0],
                112'b0
            };
            
            board_valid <= 1'b1;
        end
    end

endmodule
