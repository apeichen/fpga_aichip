/**
 * XREK Capability Registry Layer
 * 管理模組能力宣告和發現
 */
module xrek_capability_registry (
    input  logic        clk,
    input  logic        rst_n,
    
    // 能力宣告
    input  logic [31:0] module_id,
    input  logic [255:0] capability_name,
    input  logic [31:0] capability_version,
    input  logic [255:0] platform_constraints,
    input  logic [31:0] usage_limits,
    input  logic [255:0] dependencies,
    input  logic         declare_valid,
    
    // 能力查詢
    input  logic [255:0] query_capability,
    input  logic         query_valid,
    
    // 註冊表輸出
    output logic [31:0]  found_module,
    output logic [31:0]  found_version,
    output logic [255:0] found_constraints,
    output logic [31:0]  found_limits,
    output logic [255:0] found_deps,
    output logic         capability_found,
    
    // 註冊表狀態
    output logic [15:0]  registered_count,
    output logic         registry_ready
);

    // 能力註冊表 (最多 32 個條目)
    logic [31:0]  module_reg [0:31];
    logic [255:0] capability_reg [0:31];
    logic [31:0]  version_reg [0:31];
    logic [255:0] constraint_reg [0:31];
    logic [31:0]  limit_reg [0:31];
    logic [255:0] dep_reg [0:31];
    logic         valid_reg [0:31];
    
    logic [5:0]  reg_count;
    integer i;
    logic found;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_count <= 6'b0;
            registry_ready <= 1'b0;
            found_module <= 32'b0;
            found_version <= 32'b0;
            found_constraints <= 256'b0;
            found_limits <= 32'b0;
            found_deps <= 256'b0;
            capability_found <= 1'b0;
            
            for (i = 0; i < 32; i = i + 1) begin
                valid_reg[i] <= 1'b0;
            end
        end else begin
            // 能力宣告
            if (declare_valid && reg_count < 32) begin
                module_reg[reg_count] <= module_id;
                capability_reg[reg_count] <= capability_name;
                version_reg[reg_count] <= capability_version;
                constraint_reg[reg_count] <= platform_constraints;
                limit_reg[reg_count] <= usage_limits;
                dep_reg[reg_count] <= dependencies;
                valid_reg[reg_count] <= 1'b1;
                reg_count <= reg_count + 1;
            end
            
            // 能力查詢 - 使用固定迴圈邊界
            if (query_valid) begin
                found = 1'b0;
                capability_found <= 1'b0;
                for (i = 0; i < 32; i = i + 1) begin
                    if (i < reg_count && !found && valid_reg[i] && capability_reg[i] == query_capability) begin
                        found_module <= module_reg[i];
                        found_version <= version_reg[i];
                        found_constraints <= constraint_reg[i];
                        found_limits <= limit_reg[i];
                        found_deps <= dep_reg[i];
                        capability_found <= 1'b1;
                        found = 1'b1;
                    end
                end
            end
            
            registry_ready <= 1'b1;
        end
    end
    
    assign registered_count = reg_count;

endmodule
