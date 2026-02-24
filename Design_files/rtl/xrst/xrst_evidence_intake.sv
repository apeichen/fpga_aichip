/**
 * XRST Evidence Intake Layer
 * 接收並驗證來自 XRAS 的可靠性證據包
 */
module xrst_evidence_intake (
    input  logic        clk,
    input  logic        rst_n,
    
    // 來自 XRAS 的證據包
    input  logic [4095:0] evidence_packet,
    input  logic          packet_valid,
    
    // 解析後的證據
    output logic [31:0]   sla_id,
    output logic [31:0]   timestamp,
    output logic [31:0]   reliability_score,
    output logic [31:0]   penalty_amount,
    output logic [31:0]   credit_amount,
    output logic [15:0]   boundary_id,
    output logic [255:0]  causal_chain,
    output logic [255:0]  compliance_proof,
    output logic [7:0]    evidence_status,  // 0:valid,1:invalid,2:expired
    output logic          intake_done
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sla_id <= 32'b0;
            timestamp <= 32'b0;
            reliability_score <= 32'b0;
            penalty_amount <= 32'b0;
            credit_amount <= 32'b0;
            boundary_id <= 16'b0;
            causal_chain <= 256'b0;
            compliance_proof <= 256'b0;
            evidence_status <= 8'd1;
            intake_done <= 1'b0;
        end else if (packet_valid) begin
            sla_id <= evidence_packet[31:0];
            timestamp <= evidence_packet[63:32];
            reliability_score <= evidence_packet[95:64];
            penalty_amount <= evidence_packet[127:96];
            credit_amount <= evidence_packet[159:128];
            boundary_id <= evidence_packet[175:160];
            causal_chain <= evidence_packet[431:176];
            compliance_proof <= evidence_packet[687:432];
            
            if (evidence_packet[703:688] == 16'hCAFE) begin
                evidence_status <= 8'd0;
            end else begin
                evidence_status <= 8'd1;
            end
            
            intake_done <= 1'b1;
        end
    end

endmodule
