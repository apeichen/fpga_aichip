/**
 * XROG Orbit Definition Layer
 * 定義可靠性軌道的類型、邊界和穩定性規則
 */
module xrog_orbit_definition (
    input  logic        clk,
    input  logic        rst_n,
    
    // 軌道類型
    input  logic [7:0]  orbit_type,  // 0:cloud, 1:sovereign, 2:enterprise, 3:oem, 4:ai_agent, 5:cluster
    input  logic [31:0] orbit_id,
    input  logic        define_request,
    
    // 軌道參數
    input  logic [31:0] stability_envelope,  // 穩定性包絡 0-1000
    input  logic [31:0] drift_threshold,     // 漂移閾值
    input  logic [31:0] causal_stress_boundary,
    input  logic [31:0] economic_weight,     // 經濟權重 (for XRST)
    
    // 軌道定義輸出
    output logic [7:0]  defined_orbits [0:15],
    output logic [31:0] orbit_envelopes [0:15],
    output logic [31:0] orbit_thresholds [0:15],
    output logic [31:0] orbit_weights [0:15],
    output logic [3:0]  orbit_count,
    output logic        definition_complete
);

    // 軌道寄存器
    logic [7:0]  orbit_reg [0:15];
    logic [31:0] envelope_reg [0:15];
    logic [31:0] threshold_reg [0:15];
    logic [31:0] weight_reg [0:15];
    logic [3:0]  count;
    
    // 軌道類型定義
    localparam [7:0] CLOUD      = 8'd0;
    localparam [7:0] SOVEREIGN  = 8'd1;
    localparam [7:0] ENTERPRISE = 8'd2;
    localparam [7:0] OEM        = 8'd3;
    localparam [7:0] AI_AGENT   = 8'd4;
    localparam [7:0] CLUSTER    = 8'd5;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'b0;
            definition_complete <= 1'b0;
            
            for (int i = 0; i < 16; i++) begin
                orbit_reg[i] <= 8'b0;
                envelope_reg[i] <= 32'b0;
                threshold_reg[i] <= 32'b0;
                weight_reg[i] <= 32'b0;
            end
        end else if (define_request && count < 16) begin
            // 儲存軌道定義
            orbit_reg[count] <= orbit_type;
            envelope_reg[count] <= stability_envelope;
            threshold_reg[count] <= drift_threshold;
            weight_reg[count] <= economic_weight;
            
            count <= count + 1;
            definition_complete <= 1'b1;
        end else begin
            definition_complete <= 1'b0;
        end
    end
    
    // 輸出定義
    assign orbit_count = count;
    assign defined_orbits = orbit_reg;
    assign orbit_envelopes = envelope_reg;
    assign orbit_thresholds = threshold_reg;
    assign orbit_weights = weight_reg;

endmodule
