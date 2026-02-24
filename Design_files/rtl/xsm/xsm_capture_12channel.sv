/**
 * XSM (XR Sensing Module) 12通道捕獲模組
 * 支援12通道並行捕獲，可配置掃描模式
 */
module xsm_capture_12channel (
    input  logic        clk,
    input  logic        rst_n,
    
    // 通道介面
    input  logic [11:0] ch_trigger,      // 各通道觸發信號
    output logic [11:0] ch_sample_valid, // 各通道取樣有效
    output logic [31:0] ch_sample_data [0:11], // 各通道取樣數據
    
    // 配置介面
    input  logic [1:0]  scan_mode,       // 00:單次 01:連續 10:突發
    input  logic [7:0]  sample_rate,      // 取樣率配置
    
    // 中斷
    output logic        capture_done,
    output logic        fifo_full
);

    // 每個通道的FIFO
    logic [31:0] fifo_mem [0:11][0:15];  // 16深度FIFO per channel
    logic [3:0]  fifo_wr_ptr [0:11];
    logic [3:0]  fifo_rd_ptr [0:11];
    
    // 掃描計數器
    logic [7:0]  scan_counter;
    logic [7:0]  scan_period;
    
    // 通道控制
    logic [11:0] ch_enable;
    
    // 掃描模式控制
    typedef enum logic [1:0] {
        SINGLE = 2'b00,
        CONTINUOUS = 2'b01,
        BURST = 2'b10
    } scan_mode_t;
    
    scan_mode_t current_mode;
    
    // 主狀態機
    typedef enum logic [2:0] {
        IDLE,
        SCANNING,
        CAPTURE,
        DONE
    } state_t;
    
    state_t state, next_state;
    
    // 狀態機
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // 下一狀態邏輯
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (|ch_trigger) next_state = SCANNING;
            SCANNING: if (scan_counter == scan_period) next_state = CAPTURE;
            CAPTURE: next_state = DONE;
            DONE: if (current_mode == CONTINUOUS) next_state = SCANNING;
                   else next_state = IDLE;
        endcase
    end
    
    // 掃描計數器
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_counter <= 8'b0;
            scan_period <= 8'd10;
        end else if (state == SCANNING) begin
            if (scan_counter == scan_period)
                scan_counter <= 8'b0;
            else
                scan_counter <= scan_counter + 1;
        end
    end
    
    // 通道捕獲邏輯
    genvar i;
    generate
        for (i = 0; i < 12; i++) begin : channel_logic
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    ch_sample_valid[i] <= 1'b0;
                    fifo_wr_ptr[i] <= 4'b0;
                end else if (ch_trigger[i] && state == CAPTURE) begin
                    // 模擬ADC轉換
                    ch_sample_data[i] <= $urandom_range(0, 2**31-1);
                    ch_sample_valid[i] <= 1'b1;
                    
                    // 寫入FIFO
                    fifo_mem[i][fifo_wr_ptr[i]] <= ch_sample_data[i];
                    fifo_wr_ptr[i] <= fifo_wr_ptr[i] + 1;
                end else begin
                    ch_sample_valid[i] <= 1'b0;
                end
            end
        end
    endgenerate
    
    // FIFO滿檢查
    always_ff @(posedge clk) begin
        for (int i = 0; i < 12; i++) begin
            if (fifo_wr_ptr[i] == 4'b1111) begin
                fifo_full <= 1'b1;
            end
        end
    end
    
    assign current_mode = scan_mode_t'(scan_mode);
    assign capture_done = (state == DONE);

endmodule
