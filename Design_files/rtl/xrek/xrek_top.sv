/**
 * XREK Top Module
 * 整合所有 XREK 層，提供完整的交換核心
 */
module xrek_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame_in,
    input  logic          frame_valid_in,
    output logic [4095:0] xrbus_frame_out,
    output logic          frame_valid_out,
    
    // 合約輸入
    input  logic [4095:0] contract_in,
    input  logic          contract_valid,
    
    // 能力宣告
    input  logic [31:0]   local_module_id,
    input  logic [255:0]  local_capability,
    input  logic [31:0]   local_version,
    input  logic [255:0]  local_constraints,
    input  logic [31:0]   local_limits,
    input  logic [255:0]  local_deps,
    input  logic          declare_capability,
    
    // 能力查詢
    input  logic [255:0]  query_capability,
    input  logic          query_valid,
    
    // 工作流程
    input  logic [4095:0] workflow_in,
    input  logic          workflow_valid,
    
    // 驗證回饋
    input  logic [255:0]  observation_feedback,
    input  logic          feedback_valid,
    
    // 狀態輸出
    output logic [7:0]    xrek_state,
    output logic          xrek_ready,
    output logic [31:0]   active_workflows,
    output logic [31:0]   completed_steps,
    output logic [31:0]   failed_steps
);

    // 內部信號
    logic [31:0] contract_workflow_id;
    logic [31:0] contract_step_id;
    logic [7:0]  contract_action;
    logic [255:0] contract_target;
    logic [1023:0] contract_params;
    logic [255:0] contract_pre;
    logic [255:0] contract_exp;
    logic [7:0]  contract_fallback;
    logic [7:0]  contract_rollback;
    logic        contract_parsed;
    
    logic [31:0] found_module;
    logic [31:0] found_version;
    logic [255:0] found_constraints;
    logic [31:0] found_limits;
    logic [255:0] found_deps;
    logic        capability_found;
    logic [15:0] reg_count;
    logic        reg_ready;
    
    logic [4095:0] step_seq [0:31];
    logic [7:0]    step_cnt;
    logic [31:0]   selected_agent;
    logic [31:0]   est_cost;
    logic [31:0]   est_latency;
    logic [31:0]   est_accuracy;
    logic          orch_done;
    
    logic [8191:0] exec_trace;
    logic [15:0]   trace_len;
    logic [31:0]   trace_time;
    logic          verify_passed;
    logic          need_retry;
    logic          need_rollback;
    logic [7:0]    retry_final;
    logic          verify_done;
    
    logic [31:0] workflow_counter;
    logic [31:0] step_counter;
    logic [31:0] fail_counter;
    
    // 可用代理陣列
    logic [31:0] agents [0:15];
    
    // 狀態機
    typedef enum logic [3:0] {
        IDLE,
        CONTRACT,
        DISCOVER,
        ORCHESTRATE,
        EXECUTE,
        VERIFY,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            xrek_ready <= 1'b0;
            workflow_counter <= 32'b0;
            step_counter <= 32'b0;
            fail_counter <= 32'b0;
            agents[0] <= 32'b0;
            for (int i = 1; i < 16; i++) agents[i] <= 32'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    xrek_ready <= 1'b1;
                end
                
                CONTRACT: begin
                    if (contract_parsed) begin
                        workflow_counter <= workflow_counter + 1;
                    end
                end
                
                EXECUTE: begin
                    step_counter <= step_counter + 1;
                end
                
                VERIFY: begin
                    if (!verify_passed) begin
                        fail_counter <= fail_counter + 1;
                    end
                end
            endcase
            
            agents[0] <= found_module;
        end
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (contract_valid) begin
                    next_state = CONTRACT;
                end else if (query_valid) begin
                    next_state = DISCOVER;
                end else if (workflow_valid) begin
                    next_state = ORCHESTRATE;
                end
            end
            
            CONTRACT: begin
                if (contract_parsed) begin
                    next_state = DISCOVER;
                end
            end
            
            DISCOVER: begin
                if (capability_found || reg_ready) begin
                    next_state = ORCHESTRATE;
                end
            end
            
            ORCHESTRATE: begin
                if (orch_done) begin
                    next_state = EXECUTE;
                end
            end
            
            EXECUTE: begin
                next_state = VERIFY;
            end
            
            VERIFY: begin
                if (verify_done) begin
                    if (verify_passed) begin
                        next_state = COMPLETE;
                    end else if (need_retry) begin
                        next_state = EXECUTE;
                    end else begin
                        next_state = COMPLETE;
                    end
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    assign xrek_state = state;
    assign active_workflows = workflow_counter;
    assign completed_steps = step_counter;
    assign failed_steps = fail_counter;
    
    // 實體化子模組
    xrek_action_contract u_contract (
        .clk                (clk),
        .rst_n              (rst_n),
        .contract_json      (contract_in),
        .contract_valid     (contract_valid && state == CONTRACT),
        .workflow_id        (contract_workflow_id),
        .step_id            (contract_step_id),
        .action_type        (contract_action),
        .target_artifact    (contract_target),
        .action_params      (contract_params),
        .preconditions      (contract_pre),
        .expected_results   (contract_exp),
        .fallback_strategy  (contract_fallback),
        .rollback_strategy  (contract_rollback),
        .contract_parsed    (contract_parsed)
    );
    
    xrek_capability_registry u_registry (
        .clk                (clk),
        .rst_n              (rst_n),
        .module_id          (local_module_id),
        .capability_name    (local_capability),
        .capability_version (local_version),
        .platform_constraints(local_constraints),
        .usage_limits       (local_limits),
        .dependencies       (local_deps),
        .declare_valid      (declare_capability),
        .query_capability   (query_capability),
        .query_valid        (query_valid || (state == DISCOVER && contract_parsed)),
        .found_module       (found_module),
        .found_version      (found_version),
        .found_constraints  (found_constraints),
        .found_limits       (found_limits),
        .found_deps         (found_deps),
        .capability_found   (capability_found),
        .registered_count   (reg_count),
        .registry_ready     (reg_ready)
    );
    
    xrek_orchestration u_orch (
        .clk                (clk),
        .rst_n              (rst_n),
        .workflow_json      (workflow_in),
        .workflow_valid     (workflow_valid || (state == ORCHESTRATE && capability_found)),
        .routing_policy     (8'd1),
        .max_cost           (32'd1000),
        .min_accuracy       (32'd95),
        .max_latency        (32'd100),
        .available_agents   (agents),
        .agent_count        (8'd1),
        .step_sequence      (step_seq),
        .step_count         (step_cnt),
        .selected_agent     (selected_agent),
        .estimated_cost     (est_cost),
        .estimated_latency  (est_latency),
        .estimated_accuracy (est_accuracy),
        .orchestration_done (orch_done)
    );
    
    xrek_verification u_verify (
        .clk                (clk),
        .rst_n              (rst_n),
        .current_step       (step_seq[0]),
        .step_id            (contract_step_id),
        .step_executed      (state == EXECUTE),
        .expected_observations(contract_exp),
        .actual_observations(observation_feedback),
        .max_retries        (8'd3),
        .retry_count        (8'd0),
        .verification_valid (feedback_valid && state == VERIFY),
        .execution_trace    (exec_trace),
        .trace_length       (trace_len),
        .trace_timestamp    (trace_time),
        .verification_passed(verify_passed),
        .need_retry         (need_retry),
        .need_rollback      (need_rollback),
        .final_retry_count  (retry_final),
        .verification_done  (verify_done)
    );
    
    // XR-BUS 輸出
    always_comb begin
        xrbus_frame_out = 4096'b0;
        frame_valid_out = 1'b0;
        
        if (verify_done) begin
            xrbus_frame_out[31:0] = {24'b0, verify_passed};
            xrbus_frame_out[63:32] = retry_final;
            xrbus_frame_out[95:64] = trace_time;
            frame_valid_out = 1'b1;
        end else if (orch_done) begin
            xrbus_frame_out[31:0] = selected_agent;
            xrbus_frame_out[63:32] = est_cost;
            xrbus_frame_out[95:64] = est_accuracy;
            xrbus_frame_out[127:96] = est_latency;
            frame_valid_out = 1'b1;
        end else if (capability_found) begin
            xrbus_frame_out[31:0] = found_module;
            xrbus_frame_out[63:32] = found_version;
            xrbus_frame_out[287:64] = found_constraints;
            frame_valid_out = 1'b1;
        end
    end

endmodule
