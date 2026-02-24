/**
 * XENOS 狀態機
 * 管理系統狀態：IDLE, ACTIVE, FAULT, SAFE, BOOT, RECOVER
 */
module xenos_fsm (
    input  logic        clk,
    input  logic        rst_n,
    
    // 輸入事件
    input  logic        fault_input,
    input  logic        wdg_trigger,
    
    // 狀態輸出
    output logic [2:0]  current_state,
    output logic        fault_detected,
    output logic        safe_mode,
    output logic        recovery,
    output logic        wdg_reset
);

    // 狀態編碼
    typedef enum logic [2:0] {
        IDLE    = 3'b000,
        ACTIVE  = 3'b001,
        FAULT   = 3'b010,
        SAFE    = 3'b011,
        BOOT    = 3'b100,
        RECOVER = 3'b101
    } state_t;
    
    state_t state, next_state;
    
    // 計數器
    logic [7:0] fault_counter;
    logic [7:0] recovery_counter;
    logic [15:0] boot_counter;
    
    // 計數器參數
    parameter FAULT_THRESHOLD = 8'd3;
    parameter RECOVERY_TIME = 8'd100;
    parameter BOOT_TIME = 16'd1000;
    
    // 狀態機
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= BOOT;
            fault_counter <= 8'b0;
            recovery_counter <= 8'b0;
            boot_counter <= 16'b0;
        end else begin
            state <= next_state;
            
            if (fault_input) begin
                if (fault_counter < FAULT_THRESHOLD)
                    fault_counter <= fault_counter + 1;
            end else begin
                fault_counter <= 8'b0;
            end
            
            if (state == RECOVER) begin
                if (recovery_counter < RECOVERY_TIME)
                    recovery_counter <= recovery_counter + 1;
            end else begin
                recovery_counter <= 8'b0;
            end
            
            if (state == BOOT) begin
                if (boot_counter < BOOT_TIME)
                    boot_counter <= boot_counter + 1;
            end else begin
                boot_counter <= 16'b0;
            end
        end
    end
    
    // 下一狀態邏輯
    always_comb begin
        next_state = state;
        
        case (state)
            BOOT: begin
                if (boot_counter >= BOOT_TIME)
                    next_state = IDLE;
            end
            
            IDLE: begin
                if (wdg_trigger)
                    next_state = ACTIVE;
            end
            
            ACTIVE: begin
                if (fault_counter >= FAULT_THRESHOLD)
                    next_state = FAULT;
                else if (wdg_trigger)
                    next_state = IDLE;
            end
            
            FAULT: begin
                next_state = SAFE;
            end
            
            SAFE: begin
                next_state = RECOVER;
            end
            
            RECOVER: begin
                if (recovery_counter >= RECOVERY_TIME)
                    next_state = ACTIVE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    assign current_state = state;
    assign fault_detected = (state == FAULT);
    assign safe_mode = (state == SAFE);
    assign recovery = (state == RECOVER);
    assign wdg_reset = (state == BOOT) || (wdg_trigger && state != ACTIVE);

endmodule
