module xsm_capture_12channel #(
    parameter SAMPLE_WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // 12通道 ADC 接口
    input  logic [SAMPLE_WIDTH-1:0] ch0_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch1_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch2_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch3_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch4_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch5_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch6_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch7_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch8_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch9_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch10_adc,
    input  logic [SAMPLE_WIDTH-1:0] ch11_adc,
    
    // 控制接口
    input  logic                    capture_en,
    input  logic                    trigger_in,
    
    // 輸出接口
    output logic [47:0]              mono_counter,
    output logic [SAMPLE_WIDTH-1:0]  sample_data,
    output logic [3:0]               channel_id,  // 4-bit 支援16通道
    output logic                     sample_valid
);

    // 48-bit 單調計數器
    logic [47:0] mono_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) mono_cnt <= 48'h0;
        else mono_cnt <= mono_cnt + 1;
    end
    assign mono_counter = mono_cnt;
    
    // 捕獲計數器 (0-11)
    logic [3:0] capture_cnt;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_cnt <= 4'b0000;
            sample_valid <= 1'b0;
        end else if (trigger_in && capture_en) begin
            // 每個 trigger 都捕獲
            case (capture_cnt)
                4'b0000: sample_data <= ch0_adc;
                4'b0001: sample_data <= ch1_adc;
                4'b0010: sample_data <= ch2_adc;
                4'b0011: sample_data <= ch3_adc;
                4'b0100: sample_data <= ch4_adc;
                4'b0101: sample_data <= ch5_adc;
                4'b0110: sample_data <= ch6_adc;
                4'b0111: sample_data <= ch7_adc;
                4'b1000: sample_data <= ch8_adc;
                4'b1001: sample_data <= ch9_adc;
                4'b1010: sample_data <= ch10_adc;
                4'b1011: sample_data <= ch11_adc;
                default: sample_data <= ch0_adc;
            endcase
            channel_id <= capture_cnt;
            sample_valid <= 1'b1;
            capture_cnt <= capture_cnt + 1;
        end else begin
            sample_valid <= 1'b0;
        end
    end

endmodule
