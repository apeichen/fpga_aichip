module xsm_capture_simple #(
    parameter SAMPLE_WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    input  logic [SAMPLE_WIDTH-1:0] vin_adc,
    input  logic                    capture_en,
    input  logic                    trigger_in,
    
    output logic [47:0]              mono_counter,
    output logic [SAMPLE_WIDTH-1:0]  sample_data,
    output logic                     sample_valid
);

    // 48-bit 單調計數器
    logic [47:0] mono_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) mono_cnt <= 48'h0;
        else mono_cnt <= mono_cnt + 1;
    end
    assign mono_counter = mono_cnt;
    
    // 超簡單捕獲邏輯
    logic captured;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            captured <= 1'b0;
            sample_data <= 0;
        end else if (trigger_in && capture_en && !captured) begin
            sample_data <= vin_adc;
            captured <= 1'b1;
        end
    end
    
    assign sample_valid = captured;

endmodule
