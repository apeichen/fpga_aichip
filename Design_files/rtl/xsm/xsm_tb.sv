`timescale 1ns/1ps

module xsm_tb();

    // 參數
    parameter CLK_PERIOD = 1;  // 1ns = 1GHz
    parameter SAMPLE_WIDTH = 16;
    
    // 信號
    logic clk;
    logic rst_n;
    
    // ADC 接口
    logic [SAMPLE_WIDTH-1:0] vin_adc;
    logic [SAMPLE_WIDTH-1:0] vout_adc;
    logic [SAMPLE_WIDTH-1:0] iout_adc;
    logic [SAMPLE_WIDTH-1:0] temp_adc;
    
    // 控制接口
    logic capture_en;
    logic trigger_in;
    
    // 輸出接口
    logic [63:0] timestamp;
    logic [47:0] mono_counter;
    logic [SAMPLE_WIDTH-1:0] sample_data;
    logic sample_valid;
    
    // 時鐘生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 測試流程
    initial begin
        // 初始化
        $display("Starting XSM Testbench...");
        rst_n = 0;
        capture_en = 0;
        trigger_in = 0;
        vin_adc = 16'h1000;
        vout_adc = 16'h2000;
        iout_adc = 16'h3000;
        temp_adc = 16'h4000;
        
        // 釋放復位
        #100;
        rst_n = 1;
        $display("Reset released");
        
        // 測試1：基本捕獲
        $display("Test 1: Basic capture");
        capture_en = 1;
        trigger_in = 1;
        #10;
        trigger_in = 0;
        
        // 等待捕獲完成
        #50;
        
        // 測試2：多通道捕獲
        $display("Test 2: Multi-channel capture");
        trigger_in = 1;
        #20;
        trigger_in = 0;
        
        #100;
        
        // 測試3：觸發器測試
        $display("Test 3: Trigger test");
        // 這裡可以加入更多測試
        
        #200;
        
        $display("Simulation complete");
        $finish;
    end
    
    // 監控輸出
    always @(posedge clk) begin
        if (sample_valid) begin
            $display("Time: %0t, Counter: %0d, Data: %h", 
                     $time, mono_counter, sample_data);
        end
    end
    
    // 實例化待測模組
    xsm_capture #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH)
    ) u_xsm_capture (
        .clk(clk),
        .rst_n(rst_n),
        .vin_adc(vin_adc),
        .vout_adc(vout_adc),
        .iout_adc(iout_adc),
        .temp_adc(temp_adc),
        .capture_en(capture_en),
        .trigger_in(trigger_in),
        .timestamp(timestamp),
        .mono_counter(mono_counter),
        .sample_data(sample_data),
        .sample_valid(sample_valid)
    );

endmodule
