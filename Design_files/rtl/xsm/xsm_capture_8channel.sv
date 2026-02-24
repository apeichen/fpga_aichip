module xsm_capture_8channel #(
    parameter SAMPLE_WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // 8通道 ADC 接口
    input  logic [SAMPLE_WIDTH-1:0] ch0_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch1_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch2_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch3_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch4_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch5_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch6_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch7_adc,
    
    // 控制接口
    input  logic                    capture_en,
    input  logic                    trigger_in,
    
    // 輸出接口
    output logic [47:0]              mono_counter,
    output logic [SAMPLE_WIDTH-1:0]  sample_data,
    output logic [2:0]               channel_id,
    output logic                     sample_valid
);

    // 48-bit 單調計數器
    logic [47:0] mono_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) mono_cnt <= 48'h0;
        else mono_cnt <= mono_cnt + 1;
    end
    assign mono_counter = mono_cnt;
    
    // 觸發檢測 - 直接使用 trigger_in
    logic trigger_active;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trigger_active <= 1'b0;
        end else if (trigger_in) begin
            trigger_active <= 1'b1;
        end else begin
            trigger_active <= 1'b0;
        end
    end
    
    // 捕獲計數器
    logic [2:0] capture_cnt;
    logic       capture_pending;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_cnt <= 3'b000;
            sample_valid <= 1'b0;
            capture_pending <= 1'b0;
        end else if (trigger_active && capture_en && !capture_pending) begin
            // 開始捕獲
            capture_pending <= 1'b1;
        end else if (capture_pending) begin
            // 執行捕獲
            case (capture_cnt)
                3'b000: sample_data <= ch0_adc;
                3'b001: sample_data <= ch1_adc;
                3'b010: sample_data <= ch2_adc;
                3'b011: sample_data <= ch3_adc;
                3'b100: sample_data <= ch4_adc;
                3'b101: sample_data <= ch5_adc;
                3'b110: sample_data <= ch6_adc;
                3'b111: sample_data <= ch7_adc;
            endcase
            channel_id <= capture_cnt;
            sample_valid <= 1'b1;
            capture_cnt <= capture_cnt + 1;
            capture_pending <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
        end
    end

endmodule
