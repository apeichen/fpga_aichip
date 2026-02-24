/**
 * XSIP Debug Control Interface
 * 提供 JTAG/SWD/邊界掃描控制
 */
module xsip_control_debug (
    input  logic        clk,
    input  logic        rst_n,
    
    // JTAG 介面
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    output logic        jtag_tdo,
    
    // SWD 介面
    input  logic        swd_clk,
    inout  wire         swd_io,
    
    // 邊界掃描
    output logic [15:0] boundary_scan_chain,
    input  logic [15:0] scan_input,
    
    // 除錯代理模式
    input  logic        debug_proxy_enable,
    output logic        debug_proxy_active,
    
    // 韌體服務埠
    input  logic [31:0] firmware_port_in,
    output logic [31:0] firmware_port_out,
    
    // BMC 穿透
    input  logic [31:0] bmc_command,
    output logic [31:0] bmc_response,
    
    // SoC 除錯鉤子
    input  logic [7:0]  soc_debug_hooks [0:15],
    
    // XR 控制介面
    input  logic [7:0]  debug_command,
    input  logic [31:0] debug_data,
    input  logic        debug_valid,
    
    output logic [31:0] debug_result,
    output logic        debug_ready
);

    typedef enum logic [3:0] {
        IDLE,
        JTAG_CAPTURE,
        SWD_ACCESS,
        BOUNDARY_SCAN,
        FIRMWARE_READ,
        BMC_PASSTHROUGH,
        HOOK_READ,
        RESPOND
    } state_t;
    
    state_t state, next_state;
    logic [31:0] result_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            debug_result <= 32'b0;
            debug_ready <= 1'b0;
            debug_proxy_active <= 1'b0;
            result_reg <= 32'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (debug_valid) begin
                        debug_proxy_active <= 1'b1;
                    end
                end
                
                JTAG_CAPTURE: begin
                    result_reg <= {jtag_tdi, jtag_tms, jtag_tck, 29'b0};
                end
                
                SWD_ACCESS: begin
                    result_reg <= {swd_io, 31'b0};
                end
                
                BOUNDARY_SCAN: begin
                    boundary_scan_chain <= scan_input;
                    result_reg <= {16'b0, scan_input};
                end
                
                FIRMWARE_READ: begin
                    firmware_port_out <= firmware_port_in + 32'd1;
                    result_reg <= firmware_port_in;
                end
                
                BMC_PASSTHROUGH: begin
                    bmc_response <= bmc_command + 32'd1;
                    result_reg <= bmc_command;
                end
                
                HOOK_READ: begin
                    result_reg <= {24'b0, soc_debug_hooks[debug_data[3:0]]};
                end
                
                RESPOND: begin
                    debug_result <= result_reg;
                    debug_ready <= 1'b1;
                    debug_proxy_active <= 1'b0;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (debug_valid) begin
                case (debug_command)
                    8'd0: next_state = JTAG_CAPTURE;
                    8'd1: next_state = SWD_ACCESS;
                    8'd2: next_state = BOUNDARY_SCAN;
                    8'd3: next_state = FIRMWARE_READ;
                    8'd4: next_state = BMC_PASSTHROUGH;
                    8'd5: next_state = HOOK_READ;
                    default: next_state = RESPOND;
                endcase
            end
            JTAG_CAPTURE: next_state = RESPOND;
            SWD_ACCESS: next_state = RESPOND;
            BOUNDARY_SCAN: next_state = RESPOND;
            FIRMWARE_READ: next_state = RESPOND;
            BMC_PASSTHROUGH: next_state = RESPOND;
            HOOK_READ: next_state = RESPOND;
            RESPOND: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule
