/**
 * XREK Verification & Trace Integrity Layer
 * 管理執行追蹤和驗證循環
 */
module xrek_verification (
    input  logic        clk,
    input  logic        rst_n,
    
    // 執行步驟
    input  logic [4095:0] current_step,
    input  logic [31:0]   step_id,
    input  logic          step_executed,
    
    // 預期結果
    input  logic [255:0]  expected_observations,
    input  logic [255:0]  actual_observations,
    
    // 驗證參數
    input  logic [7:0]    max_retries,
    input  logic [7:0]    retry_count,
    input  logic          verification_valid,
    
    // 追蹤輸出
    output logic [8191:0] execution_trace,
    output logic [15:0]   trace_length,
    output logic [31:0]   trace_timestamp,
    
    // 驗證結果
    output logic          verification_passed,
    output logic          need_retry,
    output logic          need_rollback,
    output logic [7:0]    final_retry_count,
    output logic          verification_done
);

    // 驗證狀態機
    typedef enum logic [3:0] {
        IDLE,
        VERIFY,
        RETRY,
        ROLLBACK,
        SUCCESS,
        FAIL
    } state_t;
    
    state_t state, next_state;
    state_t current_state;
    
    logic [8191:0] trace_reg;
    logic [15:0]   trace_len;
    logic [7:0]    retry_cnt;
    logic [31:0]   time_stamp;
    logic          passed;
    logic          retry_req;
    logic          rollback_req;
    logic [7:0]    retry_final;
    logic          done;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            trace_reg <= 8192'b0;
            trace_len <= 16'b0;
            time_stamp <= 32'b0;
            passed <= 1'b0;
            retry_req <= 1'b0;
            rollback_req <= 1'b0;
            retry_final <= 8'b0;
            done <= 1'b0;
            retry_cnt <= 8'b0;
        end else begin
            current_state <= next_state;
            time_stamp <= time_stamp + 1;
            
            case (current_state)
                IDLE: begin
                    if (step_executed) begin
                        trace_reg <= {step_id, time_stamp, current_step[4063:0]};
                        trace_len <= trace_len + 1;
                    end
                    
                    if (verification_valid) begin
                        if (actual_observations == expected_observations) begin
                            passed <= 1'b1;
                        end else begin
                            if (retry_cnt < max_retries) begin
                                retry_req <= 1'b1;
                                retry_cnt <= retry_cnt + 1;
                            end else begin
                                rollback_req <= 1'b1;
                            end
                        end
                    end
                end
                
                SUCCESS: begin
                    passed <= 1'b1;
                    done <= 1'b1;
                end
                
                FAIL: begin
                    passed <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (verification_valid) begin
                    if (actual_observations == expected_observations) begin
                        next_state = SUCCESS;
                    end else if (retry_cnt < max_retries) begin
                        next_state = RETRY;
                    end else begin
                        next_state = ROLLBACK;
                    end
                end
            end
            
            RETRY: next_state = IDLE;
            ROLLBACK: next_state = FAIL;
            SUCCESS: next_state = IDLE;
            FAIL: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    assign execution_trace = trace_reg;
    assign trace_length = trace_len;
    assign trace_timestamp = time_stamp;
    assign verification_passed = passed;
    assign need_retry = retry_req;
    assign need_rollback = rollback_req;
    assign final_retry_count = retry_final;
    assign verification_done = done;

endmodule
