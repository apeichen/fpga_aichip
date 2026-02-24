/**
 * XROG Cross-Orbit Interaction
 * 管理軌道間的交互約束
 */
module xrog_cross_orbit_interaction (
    input  logic        clk,
    input  logic        rst_n,
    
    // 軌道對
    input  logic [7:0]  orbit_a_type,
    input  logic [7:0]  orbit_b_type,
    input  logic        interaction_request,
    
    // 交互約束
    output logic [31:0] interaction_strength,  // 0-1000
    output logic [31:0] coupling_factor,
    output logic [7:0]  allowed_interactions,
    output logic        interaction_defined
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interaction_strength <= 32'b0;
            coupling_factor <= 32'd100;
            allowed_interactions <= 8'b0;
            interaction_defined <= 1'b0;
        end else if (interaction_request) begin
            // 定義軌道間交互強度
            case ({orbit_a_type, orbit_b_type})
                16'h0001: begin // Cloud-Sovereign
                    interaction_strength <= 32'd800;
                    coupling_factor <= 32'd50;
                    allowed_interactions <= 8'h03; // 有限交互
                end
                
                16'h0002: begin // Cloud-Enterprise
                    interaction_strength <= 32'd900;
                    coupling_factor <= 32'd80;
                    allowed_interactions <= 8'h0F; // 多種交互
                end
                
                16'h0102: begin // Sovereign-Enterprise
                    interaction_strength <= 32'd600;
                    coupling_factor <= 32'd30;
                    allowed_interactions <= 8'h01; // 嚴格限制
                end
                
                16'h0203: begin // Enterprise-OEM
                    interaction_strength <= 32'd950;
                    coupling_factor <= 32'd90;
                    allowed_interactions <= 8'hFF; // 完全交互
                end
                
                16'h0304: begin // OEM-AI Agent
                    interaction_strength <= 32'd850;
                    coupling_factor <= 32'd70;
                    allowed_interactions <= 8'h3F;
                end
                
                16'h0405: begin // AI Agent-Cluster
                    interaction_strength <= 32'd750;
                    coupling_factor <= 32'd60;
                    allowed_interactions <= 8'h1F;
                end
                
                default: begin
                    interaction_strength <= 32'd500;
                    coupling_factor <= 32'd50;
                    allowed_interactions <= 8'h00;
                end
            endcase
            
            interaction_defined <= 1'b1;
        end
    end

endmodule
