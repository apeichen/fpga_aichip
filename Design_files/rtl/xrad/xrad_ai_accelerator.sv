/**
 * XRAD AI Accelerator
 * 加入真正的卷積運算功能
 */
module xrad_ai_accelerator (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [3:0]  ch_valid,
    input  logic [31:0] ch_data0,
    input  logic [31:0] ch_data1,
    input  logic [31:0] ch_data2,
    input  logic [31:0] ch_data3,
    output logic        ai_busy,
    output logic [31:0] ai_result,
    output logic        ai_done
);

    // 卷積核參數 (3x3 邊緣檢測)
    localparam signed [15:0] KERNEL_00 = 16'h3F80;  // 1.0
    localparam signed [15:0] KERNEL_01 = 16'h4000;  // 2.0
    localparam signed [15:0] KERNEL_02 = 16'h3F80;  // 1.0
    localparam signed [15:0] KERNEL_10 = 16'h0000;  // 0.0
    localparam signed [15:0] KERNEL_11 = 16'h0000;  // 0.0
    localparam signed [15:0] KERNEL_12 = 16'h0000;  // 0.0
    localparam signed [15:0] KERNEL_20 = 16'hBF80;  // -1.0
    localparam signed [15:0] KERNEL_21 = 16'hC000;  // -2.0
    localparam signed [15:0] KERNEL_22 = 16'hBF80;  // -1.0
    
    // 內部暫存器
    logic signed [31:0] mac_result;
    logic [3:0] state;
    
    typedef enum logic [3:0] {
        IDLE       = 4'd0,
        MAC_00     = 4'd1,
        MAC_01     = 4'd2,
        MAC_02     = 4'd3,
        MAC_10     = 4'd4,
        MAC_11     = 4'd5,
        MAC_12     = 4'd6,
        MAC_20     = 4'd7,
        MAC_21     = 4'd8,
        MAC_22     = 4'd9,
        AGGREGATE  = 4'd10,
        DONE       = 4'd11
    } state_t;
    
    state_t current_state, next_state;
    
    // 狀態機
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            mac_result <= 32'b0;
            ai_result <= 32'b0;
            ai_done <= 1'b0;
            ai_busy <= 1'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (|ch_valid) begin
                        mac_result <= 32'b0;
                        ai_busy <= 1'b1;
                    end
                end
                
                MAC_00: mac_result <= ch_data0 * KERNEL_00;
                MAC_01: mac_result <= mac_result + ch_data1 * KERNEL_01;
                MAC_02: mac_result <= mac_result + ch_data2 * KERNEL_02;
                
                MAC_10: mac_result <= mac_result + ch_data0 * KERNEL_10;
                MAC_11: mac_result <= mac_result + ch_data1 * KERNEL_11;
                MAC_12: mac_result <= mac_result + ch_data2 * KERNEL_12;
                
                MAC_20: mac_result <= mac_result + ch_data0 * KERNEL_20;
                MAC_21: mac_result <= mac_result + ch_data1 * KERNEL_21;
                MAC_22: mac_result <= mac_result + ch_data2 * KERNEL_22;
                
                AGGREGATE: ai_result <= mac_result >>> 16;
                
                DONE: begin
                    ai_done <= 1'b1;
                    ai_busy <= 1'b0;
                end
            endcase
        end
    end
    
    // 下一狀態邏輯
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE:       if (|ch_valid) next_state = MAC_00;
            MAC_00:     next_state = MAC_01;
            MAC_01:     next_state = MAC_02;
            MAC_02:     next_state = MAC_10;
            MAC_10:     next_state = MAC_11;
            MAC_11:     next_state = MAC_12;
            MAC_12:     next_state = MAC_20;
            MAC_20:     next_state = MAC_21;
            MAC_21:     next_state = MAC_22;
            MAC_22:     next_state = AGGREGATE;
            AGGREGATE:  next_state = DONE;
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

endmodule
