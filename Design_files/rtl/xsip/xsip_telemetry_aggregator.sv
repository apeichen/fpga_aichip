/**
 * XSIP Telemetry Aggregator
 * 聚合所有遙測數據，路由到 PCIe/XR-BUS
 */
module xsip_telemetry_aggregator (
    input  logic        clk,
    input  logic        rst_n,
    
    // IC級遙測
    input  logic [4095:0] ic_telemetry,
    input  logic [255:0]  ic_summary,
    input  logic          ic_valid,
    
    // 板級遙測
    input  logic [4095:0] board_telemetry,
    input  logic [255:0]  board_summary,
    input  logic          board_valid,
    
    // PCIe 用戶定義介面
    output logic [511:0]  pcie_vendor_message,
    output logic          pcie_valid,
    
    // XR-BUS 介面 (備用)
    output logic [4095:0] xrbus_telemetry,
    output logic          xrbus_valid,
    
    // 遙測資料庫
    output logic [8191:0] telemetry_database,
    output logic [15:0]   sample_count,
    output logic          database_valid
);

    logic [8191:0] db;
    logic [15:0]   count;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pcie_vendor_message <= 512'b0;
            pcie_valid <= 1'b0;
            xrbus_telemetry <= 4096'b0;
            xrbus_valid <= 1'b0;
            telemetry_database <= 8192'b0;
            sample_count <= 16'b0;
            database_valid <= 1'b0;
            count <= 16'b0;
            db <= 8192'b0;
        end else begin
            // PCIe 輸出 (512-bit)
            pcie_vendor_message <= {
                ic_telemetry[255:0],
                board_telemetry[255:0]
            };
            pcie_valid <= ic_valid && board_valid;
            
            // XR-BUS 輸出 (4096-bit)
            xrbus_telemetry <= {
                ic_telemetry[2047:0],
                board_telemetry[2047:0]
            };
            xrbus_valid <= ic_valid && board_valid;
            
            // 更新遙測資料庫 (循環緩衝)
            if (ic_valid && board_valid) begin
                db[count*512 +: 512] <= {
                    ic_telemetry[255:0],
                    board_telemetry[255:0]
                };
                count <= count + 1;
                if (count >= 16) count <= 0;
            end
            
            telemetry_database <= db;
            sample_count <= count;
            database_valid <= 1'b1;
        end
    end

endmodule
