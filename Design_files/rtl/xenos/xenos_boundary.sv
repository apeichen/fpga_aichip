/**
 * XENOS 邊界檢查器
 * 檢查12通道的電壓、電流、溫度是否超出範圍
 */
module xenos_boundary (
    input  logic        clk,
    input  logic        rst_n,
    
    // XSM數據
    input  logic [11:0] xsm_valid,
    input  logic [31:0] xsm_data [0:11],
    
    // 邊界閾值
    input  logic [31:0] voltage_min [0:11],
    input  logic [31:0] voltage_max [0:11],
    input  logic [31:0] current_max [0:11],
    input  logic [31:0] temp_max [0:11],
    
    // 故障輸出
    output logic [11:0] channel_fault,
    output logic [3:0]  fault_code [0:11],
    output logic        violation
);

    // 邊界檢查類型
    typedef enum logic [3:0] {
        NO_FAULT    = 4'b0000,
        OVER_VOLT   = 4'b0001,
        UNDER_VOLT  = 4'b0010,
        OVER_CURRENT= 4'b0100,
        OVER_TEMP   = 4'b1000
    } fault_type_t;
    
    // 通道數據解析
    logic [7:0] temp_value  [0:11];
    logic [7:0] current_value [0:11];
    logic [15:0] volt_value [0:11];
    
    // 解析輸入數據
    always_comb begin
        for (int i = 0; i < 12; i++) begin
            temp_value[i] = xsm_data[i][31:24];
            current_value[i] = xsm_data[i][23:16];
            volt_value[i] = xsm_data[i][15:0];
        end
    end
    
    // 邊界檢查邏輯
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            channel_fault <= 12'b0;
            violation <= 1'b0;
            for (int i = 0; i < 12; i++) begin
                fault_code[i] <= 4'b0;
            end
        end else begin
            channel_fault <= 12'b0;
            violation <= 1'b0;
            
            for (int i = 0; i < 12; i++) begin
                if (xsm_valid[i]) begin
                    fault_code[i] <= 4'b0;
                    
                    // 電壓檢查
                    if (volt_value[i] > voltage_max[i][15:0]) begin
                        channel_fault[i] <= 1'b1;
                        fault_code[i] <= fault_code[i] | OVER_VOLT;
                        violation <= 1'b1;
                    end
                    
                    if (volt_value[i] < voltage_min[i][15:0]) begin
                        channel_fault[i] <= 1'b1;
                        fault_code[i] <= fault_code[i] | UNDER_VOLT;
                        violation <= 1'b1;
                    end
                    
                    // 電流檢查
                    if (current_value[i] > current_max[i][23:16]) begin
                        channel_fault[i] <= 1'b1;
                        fault_code[i] <= fault_code[i] | OVER_CURRENT;
                        violation <= 1'b1;
                    end
                    
                    // 溫度檢查
                    if (temp_value[i] > temp_max[i][31:24]) begin
                        channel_fault[i] <= 1'b1;
                        fault_code[i] <= fault_code[i] | OVER_TEMP;
                        violation <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
