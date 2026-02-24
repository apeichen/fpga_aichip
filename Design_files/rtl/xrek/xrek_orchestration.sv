/**
 * XREK Orchestration & Routing Layer
 * 管理工作流程分解和路由策略
 */
module xrek_orchestration (
    input  logic        clk,
    input  logic        rst_n,
    
    // 工作流程輸入
    input  logic [4095:0] workflow_json,
    input  logic          workflow_valid,
    
    // 路由策略
    input  logic [7:0]    routing_policy,  // 0:cost,1:accuracy,2:latency,3:safety
    input  logic [31:0]   max_cost,
    input  logic [31:0]   min_accuracy,
    input  logic [31:0]   max_latency,
    
    // 可用代理
    input  logic [31:0]   available_agents [0:15],
    input  logic [7:0]    agent_count,
    
    // 分解輸出
    output logic [4095:0] step_sequence [0:31],
    output logic [7:0]    step_count,
    output logic [31:0]   selected_agent,
    output logic [31:0]   estimated_cost,
    output logic [31:0]   estimated_latency,
    output logic [31:0]   estimated_accuracy,
    output logic          orchestration_done
);

    logic [7:0]  num_steps;
    integer i;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_count <= 8'b0;
            selected_agent <= 32'b0;
            estimated_cost <= 32'b0;
            estimated_latency <= 32'b0;
            estimated_accuracy <= 32'b0;
            orchestration_done <= 1'b0;
            num_steps <= 8'b0;
        end else if (workflow_valid) begin
            num_steps <= workflow_json[7:0];
            step_count <= num_steps;
            
            // 根據策略選擇代理
            case (routing_policy)
                8'd0: begin // 最低成本
                    selected_agent <= available_agents[0];
                    estimated_cost <= 32'd100;
                    estimated_latency <= 32'd50;
                    estimated_accuracy <= 32'd95;
                end
                
                8'd1: begin // 最高準確度
                    selected_agent <= available_agents[1];
                    estimated_cost <= 32'd200;
                    estimated_latency <= 32'd100;
                    estimated_accuracy <= 32'd99;
                end
                
                8'd2: begin // 最低延遲
                    selected_agent <= available_agents[2];
                    estimated_cost <= 32'd150;
                    estimated_latency <= 32'd10;
                    estimated_accuracy <= 32'd90;
                end
                
                8'd3: begin // 最高安全性
                    selected_agent <= available_agents[3];
                    estimated_cost <= 32'd250;
                    estimated_latency <= 32'd200;
                    estimated_accuracy <= 32'd98;
                end
                
                default: begin
                    selected_agent <= available_agents[0];
                end
            endcase
            
            for (i = 0; i < 32; i = i + 1) begin
                if (i < num_steps) begin
                    step_sequence[i] <= {workflow_json[4095:256], i[7:0]};
                end
            end
            
            orchestration_done <= 1'b1;
        end
    end

endmodule
