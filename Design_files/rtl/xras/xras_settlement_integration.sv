/**
 * XRAS Settlement Integration Layer
 * 產生結算證據包 (給 XRST)
 */
module xras_settlement_integration (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自評分層的證據
    input  logic [1023:0] evidence_bundle,
    input  logic          evidence_valid,
    
    // 來自政策層的罰則/信用
    input  logic [31:0]   penalty_amount,
    input  logic [31:0]   credit_amount,
    input  logic [31:0]   accountable_actor,
    input  logic          policy_valid,
    
    // SLA 資訊
    input  logic [31:0]   sla_id,
    input  logic [31:0]   sla_reliability,
    input  logic [7:0]    sla_status,
    
    // 結算輸出 (給 XRST)
    output logic [4095:0] settlement_packet,
    output logic [31:0]   settlement_id,
    output logic [31:0]   net_settlement,  // credit - penalty
    output logic [7:0]    settlement_type, // 0:credit,1:penalty,2:adjustment
    output logic [255:0]  compliance_proof,
    output logic          packet_ready
);

    logic [31:0] packet_counter;
    logic [31:0] net_value;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            settlement_packet <= 4096'b0;
            settlement_id <= 32'b0;
            net_settlement <= 32'b0;
            settlement_type <= 8'd0;
            compliance_proof <= 256'b0;
            packet_ready <= 1'b0;
            packet_counter <= 32'b0;
        end else if (evidence_valid && policy_valid) begin
            packet_counter <= packet_counter + 1;
            settlement_id <= packet_counter;
            
            // 計算淨值
            net_value <= credit_amount - penalty_amount;
            net_settlement <= net_value;
            
            // 決定結算類型
            if (net_value > 0) begin
                settlement_type <= 8'd0; // 信用
            end else if (net_value < 0) begin
                settlement_type <= 8'd1; // 罰則
            end else begin
                settlement_type <= 8'd2; // 調整
            end
            
            // 產生合規證明 (簡化版)
            compliance_proof <= {
                sla_id[15:0],
                sla_status,
                net_value[15:0],
                accountable_actor[15:0],
                192'hCAFEBABE
            };
            
            // 組裝結算包
            settlement_packet[31:0] <= sla_id;
            settlement_packet[63:32] <= packet_counter;
            settlement_packet[127:64] <= net_value;
            settlement_packet[159:128] <= penalty_amount;
            settlement_packet[191:160] <= credit_amount;
            settlement_packet[447:192] <= evidence_bundle;
            settlement_packet[703:448] <= compliance_proof;
            
            packet_ready <= 1'b1;
        end
    end

endmodule
