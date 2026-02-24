module xsm_trigger #(
    parameter THRESHOLD_WIDTH = 16
)(
    input  logic                        clk,
    input  logic                        rst_n,
    
    // 輸入信號
    input  logic [THRESHOLD_WIDTH-1:0]  signal_in,
    
    // 觸發配置
    input  logic [THRESHOLD_WIDTH-1:0]  threshold_high,
    input  logic [THRESHOLD_WIDTH-1:0]  threshold_low,
    input  logic                         edge_trigger_en,
    input  logic                         level_trigger_en,
    
    // 觸發輸出
    output logic                         trigger_out,
    output logic                         trigger_type  // 0:level, 1:edge
);

    logic [THRESHOLD_WIDTH-1:0] signal_delayed;
    logic above_high, below_low;
    logic level_trigger, edge_trigger;
    
    // 延遲一個時鐘（用於邊緣檢測）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            signal_delayed <= 0;
        end else begin
            signal_delayed <= signal_in;
        end
    end
    
    // 電平比較
    assign above_high = (signal_in >= threshold_high);
    assign below_low  = (signal_in <= threshold_low);
    
    // 電平觸發
    assign level_trigger = level_trigger_en && (above_high || below_low);
    
    // 邊緣觸發（上升沿或下降沿）
    assign edge_trigger = edge_trigger_en && 
                          ((signal_in > threshold_high && signal_delayed <= threshold_high) ||
                           (signal_in < threshold_low && signal_delayed >= threshold_low));
    
    // 觸發輸出
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trigger_out <= 1'b0;
            trigger_type <= 1'b0;
        end else begin
            if (level_trigger) begin
                trigger_out <= 1'b1;
                trigger_type <= 1'b0;
            end else if (edge_trigger) begin
                trigger_out <= 1'b1;
                trigger_type <= 1'b1;
            end else begin
                trigger_out <= 1'b0;
            end
        end
    end

endmodule
