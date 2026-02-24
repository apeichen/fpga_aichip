/**
 * XROG Orbit Stability Calculator
 * 計算軌道穩定性指標
 */
module xrog_orbit_stability (
    input  logic        clk,
    input  logic        rst_n,
    
    // 軌道定義
    input  logic [7:0]  orbit_type,
    input  logic [31:0] stability_envelope,
    input  logic [31:0] drift_threshold,
    
    // 當前漂移測量
    input  logic [31:0] operational_drift,
    input  logic [31:0] semantic_drift,
    input  logic [31:0] temporal_drift,
    input  logic [31:0] policy_drift,
    input  logic [31:0] jurisdiction_drift,
    
    // 穩定性輸出
    output logic [31:0] stability_index,    // 0-1000
    output logic [31:0] composite_drift,
    output logic        drift_warning,
    output logic        instability_alert,
    output logic        calculation_valid
);

    logic [31:0] weighted_drift;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stability_index <= 32'd1000;
            composite_drift <= 32'b0;
            drift_warning <= 1'b0;
            instability_alert <= 1'b0;
            calculation_valid <= 1'b0;
            weighted_drift <= 32'b0;
        end else begin
            // 根據軌道類型計算加權漂移
            case (orbit_type)
                8'd0: begin // Cloud
                    weighted_drift <= (operational_drift * 3 + 
                                      semantic_drift * 2 + 
                                      temporal_drift * 2 + 
                                      policy_drift * 2 + 
                                      jurisdiction_drift * 1) / 10;
                end
                
                8'd1: begin // Sovereign
                    weighted_drift <= (operational_drift * 1 + 
                                      semantic_drift * 2 + 
                                      temporal_drift * 1 + 
                                      policy_drift * 3 + 
                                      jurisdiction_drift * 3) / 10;
                end
                
                8'd2: begin // Enterprise
                    weighted_drift <= (operational_drift * 3 + 
                                      semantic_drift * 2 + 
                                      temporal_drift * 2 + 
                                      policy_drift * 2 + 
                                      jurisdiction_drift * 1) / 10;
                end
                
                8'd3: begin // OEM
                    weighted_drift <= (operational_drift * 4 + 
                                      semantic_drift * 2 + 
                                      temporal_drift * 2 + 
                                      policy_drift * 1 + 
                                      jurisdiction_drift * 1) / 10;
                end
                
                8'd4: begin // AI Agent
                    weighted_drift <= (operational_drift * 2 + 
                                      semantic_drift * 4 + 
                                      temporal_drift * 2 + 
                                      policy_drift * 1 + 
                                      jurisdiction_drift * 1) / 10;
                end
                
                8'd5: begin // Cluster
                    weighted_drift <= (operational_drift * 3 + 
                                      semantic_drift * 1 + 
                                      temporal_drift * 3 + 
                                      policy_drift * 2 + 
                                      jurisdiction_drift * 1) / 10;
                end
                
                default: begin
                    weighted_drift <= (operational_drift + semantic_drift + 
                                      temporal_drift + policy_drift + 
                                      jurisdiction_drift) / 5;
                end
            endcase
            
            composite_drift <= weighted_drift;
            
            // 計算穩定性指數 (1000 - 漂移)
            if (weighted_drift < stability_envelope) begin
                stability_index <= 1000 - (weighted_drift * 1000 / stability_envelope);
                drift_warning <= 1'b0;
                instability_alert <= 1'b0;
            end else if (weighted_drift < drift_threshold) begin
                stability_index <= 1000 - (weighted_drift * 1000 / drift_threshold);
                drift_warning <= 1'b1;
                instability_alert <= 1'b0;
            end else begin
                stability_index <= 1000 - (weighted_drift * 1000 / drift_threshold);
                drift_warning <= 1'b1;
                instability_alert <= 1'b1;
            end
            
            calculation_valid <= 1'b1;
        end
    end

endmodule
