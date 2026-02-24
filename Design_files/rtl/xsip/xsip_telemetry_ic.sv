/**
 * XSIP IC-Level Telemetry Interface
 * 收集 IC 級信號：I2C/I3C、PMIC、溫度、電壓、電流等
 */
module xsip_telemetry_ic (
    input  logic        clk,
    input  logic        rst_n,
    
    // I3C/I2C 服務匯流排
    inout  wire         i3c_scl,
    inout  wire         i3c_sda,
    input  logic        i3c_valid,
    
    // PMIC 讀數
    input  logic [31:0] pmic_voltage [0:7],
    input  logic [31:0] pmic_current [0:7],
    input  logic [7:0]  pmic_status,
    
    // 溫度感測器
    input  logic [15:0] temp_sensors [0:15],
    input  logic [7:0]  temp_valid,  // 改為 8 bits
    
    // 電壓邊界點
    input  logic [31:0] voltage_margin [0:7],
    input  logic [7:0]  margin_valid,
    
    // 電流感測
    input  logic [31:0] current_sense [0:7],
    
    // SERDES 健康
    input  logic [15:0] serdes_eye [0:7],
    input  logic [15:0] serdes_jitter [0:7],
    input  logic [7:0]  serdes_status,
    
    // DRAM 訓練狀態
    input  logic [31:0] dram_ecc_count,
    input  logic [7:0]  dram_training_status,
    input  logic        dram_valid,
    
    // SSD/NAND 耐久度
    input  logic [31:0] nand_endurance [0:7],
    input  logic [31:0] nand_wear_level,
    
    // 遙測輸出
    output logic [4095:0] telemetry_data,
    output logic [255:0]  telemetry_summary,
    output logic [31:0]   sample_timestamp,
    output logic          telemetry_valid
);

    logic [31:0] pmic_sum;
    logic [15:0] temp_max;
    logic [15:0] temp_min;
    logic [15:0] temp_avg;
    logic [31:0] voltage_min;
    logic [31:0] voltage_max;
    logic [31:0] current_total;
    integer i;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            telemetry_data <= 4096'b0;
            telemetry_summary <= 256'b0;
            sample_timestamp <= 32'b0;
            telemetry_valid <= 1'b0;
            pmic_sum <= 32'b0;
            temp_max <= 16'b0;
            temp_min <= 16'hFFFF;
            temp_avg <= 16'b0;
            voltage_min <= 32'hFFFFFFFF;
            voltage_max <= 32'b0;
            current_total <= 32'b0;
        end else begin
            sample_timestamp <= sample_timestamp + 1;
            
            telemetry_data[31:0] <= pmic_voltage[0];
            telemetry_data[63:32] <= pmic_current[0];
            telemetry_data[95:64] <= temp_sensors[0];
            telemetry_data[127:96] <= voltage_margin[0];
            telemetry_data[159:128] <= current_sense[0];
            telemetry_data[191:160] <= serdes_eye[0];
            telemetry_data[223:192] <= serdes_jitter[0];
            telemetry_data[255:224] <= dram_ecc_count;
            telemetry_data[287:256] <= nand_endurance[0];
            
            pmic_sum = 0;
            for (i = 0; i < 8; i = i + 1) begin
                pmic_sum = pmic_sum + pmic_current[i];
            end
            
            temp_max = 0;
            temp_min = 16'hFFFF;
            temp_avg = 0;
            for (i = 0; i < 16; i = i + 1) begin
                if (temp_sensors[i] > temp_max) temp_max = temp_sensors[i];
                if (temp_sensors[i] < temp_min) temp_min = temp_sensors[i];
                temp_avg = temp_avg + temp_sensors[i];
            end
            temp_avg = temp_avg >> 4;
            
            voltage_min = 32'hFFFFFFFF;
            voltage_max = 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (voltage_margin[i] < voltage_min) voltage_min = voltage_margin[i];
                if (voltage_margin[i] > voltage_max) voltage_max = voltage_margin[i];
            end
            
            telemetry_summary <= {
                pmic_sum[31:0],
                temp_max[15:0],
                temp_min[15:0],
                temp_avg[15:0],
                voltage_min[31:0],
                voltage_max[31:0],
                dram_ecc_count[31:0],
                nand_wear_level[31:0]
            };
            
            telemetry_valid <= 1'b1;
        end
    end

endmodule
