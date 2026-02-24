/**
 * XRAD Real-time Processor
 * 加入真正的 FIR 濾波功能
 */
module xrad_rt_processor (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  xsm_valid,
    input  logic [31:0] xsm_data0,
    input  logic [31:0] xsm_data1,
    input  logic [31:0] xsm_data2,
    input  logic [31:0] xsm_data3,
    input  logic [31:0] xsm_data4,
    input  logic [31:0] xsm_data5,
    input  logic [31:0] xsm_data6,
    input  logic [31:0] xsm_data7,
    input  logic [2:0]  xenos_state,
    output logic [31:0] rt_output
);

    // FIR 濾波器係數 (8階低通濾波器)
    localparam signed [15:0] FIR_0 = 16'h3A9E;  // 0.083
    localparam signed [15:0] FIR_1 = 16'h3B33;  // 0.1
    localparam signed [15:0] FIR_2 = 16'h3C23;  // 0.15
    localparam signed [15:0] FIR_3 = 16'h3D4C;  // 0.2
    localparam signed [15:0] FIR_4 = 16'h3D4C;  // 0.2
    localparam signed [15:0] FIR_5 = 16'h3C23;  // 0.15
    localparam signed [15:0] FIR_6 = 16'h3B33;  // 0.1
    localparam signed [15:0] FIR_7 = 16'h3A9E;  // 0.083
    
    // 延遲線
    logic signed [31:0] delay_line [0:7];
    logic signed [31:0] fir_result;
    integer i;
    
    // FIR 濾波運算
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i++) begin
                delay_line[i] <= 32'b0;
            end
            fir_result <= 32'b0;
            rt_output <= 32'b0;
        end else begin
            // 更新延遲線
            delay_line[0] <= xsm_data0;
            delay_line[1] <= delay_line[0];
            delay_line[2] <= delay_line[1];
            delay_line[3] <= delay_line[2];
            delay_line[4] <= delay_line[3];
            delay_line[5] <= delay_line[4];
            delay_line[6] <= delay_line[5];
            delay_line[7] <= delay_line[6];
            
            // FIR 運算
            fir_result = 32'b0;
            fir_result = fir_result + delay_line[0] * FIR_0;
            fir_result = fir_result + delay_line[1] * FIR_1;
            fir_result = fir_result + delay_line[2] * FIR_2;
            fir_result = fir_result + delay_line[3] * FIR_3;
            fir_result = fir_result + delay_line[4] * FIR_4;
            fir_result = fir_result + delay_line[5] * FIR_5;
            fir_result = fir_result + delay_line[6] * FIR_6;
            fir_result = fir_result + delay_line[7] * FIR_7;
            
            // 根據 XENOS 狀態輸出
            case (xenos_state)
                3'b001: rt_output <= fir_result >>> 16;  // ACTIVE
                3'b010: rt_output <= 32'hFFFFFFFF;       // FAULT
                3'b011: rt_output <= 32'h00000000;       // SAFE
                default: rt_output <= fir_result >>> 16;
            endcase
        end
    end

endmodule
