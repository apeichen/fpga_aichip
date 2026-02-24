/**
 * XROG Top Module
 * 整合軌道定義和跨邊界政策治理
 */
module xrog_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame_in,
    input  logic          frame_valid_in,
    output logic [4095:0] xrbus_frame_out,
    output logic          frame_valid_out,
    
    // 軌道配置
    input  logic [7:0]    orbit_config [0:7],
    input  logic [3:0]    config_count,
    
    // 政策域
    input  logic [7:0]    policy_domains [0:7],
    input  logic [3:0]    domain_count,
    
    // 狀態輸出
    output logic [3:0]    xrog_state,
    output logic          xrog_busy,
    
    // 治理報告
    output logic [31:0]   orbit_stability,
    output logic [31:0]   policy_compliance,
    output logic [7:0]    active_treaties
);

    // 軌道定義訊號
    logic [7:0]  defined_orbits [0:15];
    logic [31:0] orbit_envelopes [0:15];
    logic [31:0] orbit_thresholds [0:15];
    logic [31:0] orbit_weights [0:15];
    logic [3:0]  orbit_count;
    logic        orbit_def_done;
    
    // 穩定性訊號
    logic [31:0] stability_idx;
    logic [31:0] composite_drift;
    logic        drift_warn;
    logic        instability;
    logic        stability_valid;
    
    // 政策訊號
    logic [4095:0] unified_policies;
    logic [31:0]   policy_score;
    logic [7:0]    policy_conflicts [0:15];
    logic [3:0]    conflict_cnt;
    logic          policy_valid;
    
    // 條約訊號
    logic [4095:0] treaty_terms;
    logic [31:0]   treaty_dur;
    logic [31:0]   penalty;
    logic [7:0]    treaty_stat;
    logic          treaty_active;
    
    // 狀態機
    typedef enum logic [3:0] {
        IDLE = 4'd0,
        ORBIT_DEF = 4'd1,
        STABILITY = 4'd2,
        POLICY = 4'd3,
        TREATY = 4'd4,
        REPORT = 4'd5
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            xrog_busy <= 1'b0;
            orbit_stability <= 32'd1000;
            policy_compliance <= 32'd100;
            active_treaties <= 8'b0;
        end else begin
            state <= next_state;
        end
    end
    
    always_comb begin
        next_state = state;
        xrog_busy = 1'b1;
        
        case (state)
            IDLE: begin
                if (frame_valid_in) begin
                    next_state = ORBIT_DEF;
                end else begin
                    xrog_busy = 1'b0;
                end
            end
            
            ORBIT_DEF: begin
                if (orbit_def_done) begin
                    next_state = STABILITY;
                end
            end
            
            STABILITY: begin
                if (stability_valid) begin
                    next_state = POLICY;
                end
            end
            
            POLICY: begin
                if (policy_valid) begin
                    next_state = TREATY;
                end
            end
            
            TREATY: begin
                if (treaty_active) begin
                    next_state = REPORT;
                end
            end
            
            REPORT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    assign xrog_state = state;
    
    // 軌道定義層
    xrog_orbit_definition u_orbit_def (
        .clk            (clk),
        .rst_n          (rst_n),
        .orbit_type     (xrbus_frame_in[7:0]),
        .orbit_id       (xrbus_frame_in[63:32]),
        .define_request (frame_valid_in && state == ORBIT_DEF),
        .stability_envelope(32'd800),
        .drift_threshold(32'd950),
        .causal_stress_boundary(32'd900),
        .economic_weight(xrbus_frame_in[127:96]),
        .defined_orbits (defined_orbits),
        .orbit_envelopes(orbit_envelopes),
        .orbit_thresholds(orbit_thresholds),
        .orbit_weights  (orbit_weights),
        .orbit_count    (orbit_count),
        .definition_complete(orbit_def_done)
    );
    
    // 軌道穩定性計算
    xrog_orbit_stability u_stability (
        .clk            (clk),
        .rst_n          (rst_n),
        .orbit_type     (defined_orbits[0]),
        .stability_envelope(orbit_envelopes[0]),
        .drift_threshold(orbit_thresholds[0]),
        .operational_drift(xrbus_frame_in[159:128]),
        .semantic_drift (xrbus_frame_in[191:160]),
        .temporal_drift (xrbus_frame_in[223:192]),
        .policy_drift   (xrbus_frame_in[255:224]),
        .jurisdiction_drift(xrbus_frame_in[287:256]),
        .stability_index(stability_idx),
        .composite_drift(composite_drift),
        .drift_warning  (drift_warn),
        .instability_alert(instability),
        .calculation_valid(stability_valid)
    );
    
    // 跨邊界政策治理器
    xrog_policy_governor u_policy (
        .clk            (clk),
        .rst_n          (rst_n),
        .policy_domain  (xrbus_frame_in[15:8]),
        .domain_id      (xrbus_frame_in[95:64]),
        .policy_request (stability_valid && state == POLICY),
        .local_policies (xrbus_frame_in[511:416]),
        .global_policies(xrbus_frame_in[927:832]),
        .unified_policies(unified_policies),
        .policy_compliance(policy_score),
        .policy_conflicts(policy_conflicts),
        .conflict_count (conflict_cnt),
        .policy_valid   (policy_valid)
    );
    
    // 條約管理器
    xrog_treaty_manager u_treaty (
        .clk            (clk),
        .rst_n          (rst_n),
        .treaty_type    (xrbus_frame_in[23:16]),
        .signatory_a    (xrbus_frame_in[191:160]),
        .signatory_b    (xrbus_frame_in[223:192]),
        .treaty_request (policy_valid && state == TREATY),
        .treaty_terms   (treaty_terms),
        .treaty_duration(treaty_dur),
        .penalty_clause (penalty),
        .treaty_status  (treaty_stat),
        .treaty_active  (treaty_active)
    );
    
    // 輸出選擇
    always_comb begin
        if (treaty_active) begin
            xrbus_frame_out <= treaty_terms;
        end else if (policy_valid) begin
            xrbus_frame_out <= unified_policies;
        end else if (stability_valid) begin
            xrbus_frame_out[31:0] <= stability_idx;
            xrbus_frame_out[63:32] <= composite_drift;
            xrbus_frame_out[95:64] <= {24'b0, drift_warn, instability};
        end else if (orbit_def_done) begin
            xrbus_frame_out[31:0] <= orbit_count;
        end else begin
            xrbus_frame_out <= 4096'b0;
        end
        
        frame_valid_out <= treaty_active || policy_valid || stability_valid || orbit_def_done;
    end
    
    // 輸出報告
    assign orbit_stability = stability_idx;
    assign policy_compliance = policy_score;
    assign active_treaties = treaty_stat;

endmodule
