/**
 * XSIP EC Control Interface
 * 提供對 EC 關鍵控制引腳的訪問
 */
module xsip_control_ec (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR 控制請求
    input  logic [7:0]  control_code,
    input  logic [31:0] control_param,
    input  logic        control_request,
    
    // EC 控制引腳
    output logic        ec_reset,
    output logic        ec_shutdown,
    output logic        ec_recovery,
    output logic [7:0]  ec_gpio [0:15],
    
    // 狀態
    input  logic [7:0]  ec_status,
    input  logic        ec_ready,
    
    // 控制響應
    output logic [31:0] control_result,
    output logic [7:0]  control_status,
    output logic        control_done
);

    typedef enum logic [3:0] {
        IDLE,
        RESET,
        SHUTDOWN,
        RECOVERY,
        GPIO_SET,
        STATUS_READ,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ec_reset <= 1'b0;
            ec_shutdown <= 1'b0;
            ec_recovery <= 1'b0;
            control_result <= 32'b0;
            control_status <= 8'd0;
            control_done <= 1'b0;
            
            for (int i = 0; i < 16; i++) begin
                ec_gpio[i] <= 8'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (control_request) begin
                        case (control_code)
                            8'd0: next_state = RESET;      // EC 重置
                            8'd1: next_state = SHUTDOWN;   // EC 關機
                            8'd2: next_state = RECOVERY;   // EC 恢復
                            8'd3: next_state = GPIO_SET;   // GPIO 設置
                            8'd4: next_state = STATUS_READ; // 狀態讀取
                            default: next_state = DONE;
                        endcase
                    end
                end
                
                RESET: begin
                    ec_reset <= 1'b1;
                    control_result <= 32'h52455354; // "REST"
                    next_state <= DONE;
                end
                
                SHUTDOWN: begin
                    ec_shutdown <= 1'b1;
                    control_result <= 32'h5348444E; // "SHDN"
                    next_state <= DONE;
                end
                
                RECOVERY: begin
                    ec_recovery <= 1'b1;
                    control_result <= 32'h52454356; // "RECV"
                    next_state <= DONE;
                end
                
                GPIO_SET: begin
                    ec_gpio[control_param[7:0]] <= control_param[15:8];
                    control_result <= {24'b0, control_param[7:0]};
                    next_state <= DONE;
                end
                
                STATUS_READ: begin
                    control_result <= {24'b0, ec_status};
                    next_state <= DONE;
                end
                
                DONE: begin
                    ec_reset <= 1'b0;
                    ec_shutdown <= 1'b0;
                    ec_recovery <= 1'b0;
                    control_status <= 8'd1;
                    control_done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end

endmodule
