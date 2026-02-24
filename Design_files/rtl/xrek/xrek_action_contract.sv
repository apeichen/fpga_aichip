/**
 * XREK Action Contract Layer
 * 定義標準化的行動合約格式
 */
module xrek_action_contract (
    input  logic        clk,
    input  logic        rst_n,
    
    // 合約輸入
    input  logic [4095:0] contract_json,
    input  logic          contract_valid,
    
    // 合約解析
    output logic [31:0]   workflow_id,
    output logic [31:0]   step_id,
    output logic [7:0]    action_type,
    output logic [255:0]  target_artifact,
    output logic [1023:0] action_params,
    output logic [255:0]  preconditions,
    output logic [255:0]  expected_results,
    output logic [7:0]    fallback_strategy,
    output logic [7:0]    rollback_strategy,
    output logic          contract_parsed
);

    // 合約解析狀態機
    typedef enum logic [3:0] {
        IDLE,
        PARSE_HEADER,
        PARSE_TARGET,
        PARSE_PARAMS,
        PARSE_PRE,
        PARSE_EXPECT,
        PARSE_FAIL,
        COMPLETE
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            workflow_id <= 32'b0;
            step_id <= 32'b0;
            action_type <= 8'b0;
            target_artifact <= 256'b0;
            action_params <= 1024'b0;
            preconditions <= 256'b0;
            expected_results <= 256'b0;
            fallback_strategy <= 8'b0;
            rollback_strategy <= 8'b0;
            contract_parsed <= 1'b0;
            state <= IDLE;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (contract_valid) begin
                        workflow_id <= contract_json[31:0];
                        step_id <= contract_json[63:32];
                        action_type <= contract_json[71:64];
                    end
                end
                
                PARSE_TARGET: begin
                    target_artifact <= contract_json[327:72];
                end
                
                PARSE_PARAMS: begin
                    action_params <= contract_json[1351:328];
                end
                
                PARSE_PRE: begin
                    preconditions <= contract_json[1607:1352];
                end
                
                PARSE_EXPECT: begin
                    expected_results <= contract_json[1863:1608];
                end
                
                PARSE_FAIL: begin
                    fallback_strategy <= contract_json[1871:1864];
                    rollback_strategy <= contract_json[1879:1872];
                end
                
                COMPLETE: begin
                    contract_parsed <= 1'b1;
                end
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (contract_valid) next_state = PARSE_TARGET;
            PARSE_TARGET: next_state = PARSE_PARAMS;
            PARSE_PARAMS: next_state = PARSE_PRE;
            PARSE_PRE: next_state = PARSE_EXPECT;
            PARSE_EXPECT: next_state = PARSE_FAIL;
            PARSE_FAIL: next_state = COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule
