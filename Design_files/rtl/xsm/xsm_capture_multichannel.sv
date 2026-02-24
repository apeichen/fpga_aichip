module xsm_capture_multichannel #(
    parameter SAMPLE_WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // 多通道 ADC 接口
    input  logic [SAMPLE_WIDTH-1:0] vin_adc,
    input  logic [SAMPLE_WIDTH-1:0] vout_adc,
    input  logic [SAMPLE_WIDTH-1:0] iout_adc,
    input  logic [SAMPLE_WIDTH-1:0] temp_adc,
    
    // 控制接口
    input  logic                    capture_en,
    input  logic                    trigger_in,
    
    // 輸出接口
    output logic [47:0]              mono_counter,
    output logic [SAMPLE_WIDTH-1:0]  sample_data,
    output logic [1:0]               channel_id,
    output logic                     sample_valid
);

    // 48-bit 單調計數器
    logic [47:0] mono_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) mono_cnt <= 48'h0;
        else mono_cnt <= mono_cnt + 1;
    end
    assign mono_counter = mono_cnt;
    
    // 邊緣檢測
    logic trigger_d1, trigger_rise;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trigger_d1 <= 1'b0;
        end else begin
            trigger_d1 <= trigger_in;
        end
    end
    
    assign trigger_rise = trigger_in & ~trigger_d1;
    
    // 捕獲計數器
    logic [1:0] capture_cnt;
    logic [1:0] valid_cnt;
    logic       first_trigger_done;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_cnt <= 2'b00;
            sample_valid <= 1'b0;
            valid_cnt <= 2'b00;
            first_trigger_done <= 1'b0;
        end else if (trigger_rise && capture_en) begin
            if (!first_trigger_done) begin
                // 第一個 trigger - 捕獲 channel 0
                sample_data <= vin_adc;
                channel_id <= 2'b00;
                first_trigger_done <= 1'b1;
                capture_cnt <= 2'b01;
            end else begin
                // 後續 trigger - 使用 capture_cnt
                case (capture_cnt)
                    2'b00: sample_data <= vin_adc;
                    2'b01: sample_data <= vout_adc;
                    2'b10: sample_data <= iout_adc;
                    2'b11: sample_data <= temp_adc;
                endcase
                channel_id <= capture_cnt;
                capture_cnt <= capture_cnt + 1;
            end
            sample_valid <= 1'b1;
            valid_cnt <= 2'b00;
        end else if (sample_valid) begin
            valid_cnt <= valid_cnt + 1;
            if (valid_cnt == 2'b01) begin
                sample_valid <= 1'b0;
            end
        end
    end

endmodule
