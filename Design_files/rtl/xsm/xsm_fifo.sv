module xsm_fifo #(
    parameter FIFO_DEPTH = 1024,
    parameter DATA_WIDTH = 128
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // 寫入接口
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic                    full,
    
    // 讀取接口
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty,
    
    // 狀態
    output logic [$clog2(FIFO_DEPTH):0] fill_level
);

    localparam PTR_WIDTH = $clog2(FIFO_DEPTH);
    
    // 記憶體（使用 BRAM）
    logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    
    // 指針
    logic [PTR_WIDTH:0] wr_ptr;  // 包含溢出位
    logic [PTR_WIDTH:0] rd_ptr;
    
    // 狀態信號
    assign full = (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]) && 
                  (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]);
    assign empty = (wr_ptr == rd_ptr);
    assign fill_level = wr_ptr - rd_ptr;
    
    // 寫入邏輯
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end
    
    // 讀取邏輯
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end
    
    // 讀取數據（異步讀）
    assign rd_data = mem[rd_ptr[PTR_WIDTH-1:0]];

endmodule
