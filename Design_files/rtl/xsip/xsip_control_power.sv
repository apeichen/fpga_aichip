/**
 * XSIP Power Control Interface
 * 控制 OVP/OCP/OCT、電壓/頻率調整、電源門控
 */
module xsip_control_power (
    input  logic        clk,
    input  logic        rst_n,
    
    // OVP/OCP/OCT 控制
    output logic [7:0]  ovp_trip_reset [0:7],
    output logic [7:0]  ocp_trip_reset [0:7],
    output logic [7:0]  oct_trip_reset [0:7],
    
    // 電壓/頻率邊際控制
    input  logic [31:0] current_voltage [0:7],
    input  logic [31:0] current_frequency [0:7],
    output logic [31:0] target_voltage [0:7],
    output logic [31:0] target_frequency [0:7],
    output logic [7:0]  voltage_margin_enable,
    
    // 子系統電源門控
    output logic [15:0] power_cycle_gates,  // 每bit對應一個子系統
    output logic [15:0] power_domain_reset,
    
    // 配置參數
    input  logic [31:0] voltage_min [0:7],
    input  logic [31:0] voltage_max [0:7],
    input  logic [31:0] frequency_min [0:7],
    input  logic [31:0] frequency_max [0:7],
    
    // 控制介面
    input  logic [7:0]  control_type,  // 0:ovp,1:ocp,2:margin,3:gate
    input  logic [31:0] control_value,
    input  logic [3:0]  target_domain,
    input  logic        control_valid,
    
    output logic [31:0] control_response,
    output logic        control_ack
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                ovp_trip_reset[i] <= 8'b0;
                ocp_trip_reset[i] <= 8'b0;
                oct_trip_reset[i] <= 8'b0;
                target_voltage[i] <= 32'd0;
                target_frequency[i] <= 32'd0;
            end
            voltage_margin_enable <= 8'b0;
            power_cycle_gates <= 16'b0;
            power_domain_reset <= 16'b0;
            control_response <= 32'b0;
            control_ack <= 1'b0;
        end else if (control_valid) begin
            case (control_type)
                8'd0: begin // OVP 重置
                    ovp_trip_reset[target_domain] <= control_value[7:0];
                    control_response <= 32'h4F5650; // "OVP"
                end
                
                8'd1: begin // OCP 重置
                    ocp_trip_reset[target_domain] <= control_value[7:0];
                    control_response <= 32'h4F4350; // "OCP"
                end
                
                8'd2: begin // 電壓/頻率邊際
                    if (control_value >= voltage_min[target_domain] && 
                        control_value <= voltage_max[target_domain]) begin
                        target_voltage[target_domain] <= control_value;
                        voltage_margin_enable[target_domain] <= 1'b1;
                        control_response <= 32'h4D5247; // "MRG"
                    end else begin
                        control_response <= 32'h455252; // "ERR"
                    end
                end
                
                8'd3: begin // 電源門控
                    if (control_value == 32'd0) begin
                        power_cycle_gates[target_domain] <= 1'b1;
                        control_response <= 32'h474154; // "GAT"
                    end else begin
                        power_domain_reset[target_domain] <= 1'b1;
                        control_response <= 32'h525354; // "RST"
                    end
                end
                
                default: begin
                    control_response <= 32'h494E56; // "INV"
                end
            endcase
            
            control_ack <= 1'b1;
        end else begin
            control_ack <= 1'b0;
        end
    end

endmodule
