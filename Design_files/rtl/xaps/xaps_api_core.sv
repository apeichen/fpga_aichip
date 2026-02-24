/**
 * XAPS API Core
 * 提供標準化應用程式介面
 */
module xaps_api_core (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame,
    input  logic          frame_valid,
    output logic [4095:0] xrbus_response,
    output logic          response_valid,
    
    // API 端點
    input  logic [31:0]   api_endpoint,
    input  logic [7:0]    api_method,
    input  logic [1023:0] api_payload,
    input  logic          api_request,
    
    // API 回應
    output logic [31:0]   api_status,
    output logic [1023:0] api_response,
    output logic          api_response_valid,
    
    // 路由表
    input  logic [7:0]    route_table [0:255]
);

    // API 狀態機
    typedef enum logic [3:0] {
        IDLE = 4'd0,
        ROUTE = 4'd1,
        AUTH = 4'd2,
        EXECUTE = 4'd3,
        RESPOND = 4'd4,
        ERROR = 4'd5
    } state_t;
    
    state_t state, next_state;
    
    // API 方法定義
    localparam [7:0] GET    = 8'd0;
    localparam [7:0] POST   = 8'd1;
    localparam [7:0] PUT    = 8'd2;
    localparam [7:0] DELETE = 8'd3;
    
    // HTTP 狀態碼
    localparam [31:0] OK          = 32'd200;
    localparam [31:0] CREATED     = 32'd201;
    localparam [31:0] BAD_REQUEST = 32'd400;
    localparam [31:0] NOT_FOUND   = 32'd404;
    localparam [31:0] SERVER_ERROR= 32'd500;
    
    // 內部暫存器
    logic [7:0]  target_module;
    logic [31:0] transaction_id;
    logic [31:0] timestamp;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            api_status <= OK;
            api_response <= 1024'b0;
            api_response_valid <= 1'b0;
            xrbus_response <= 4096'b0;
            response_valid <= 1'b0;
            transaction_id <= 32'b0;
            timestamp <= 32'b0;
        end else begin
            state <= next_state;
            timestamp <= timestamp + 1;
            
            case (state)
                IDLE: begin
                    if (api_request) begin
                        transaction_id <= transaction_id + 1;
                    end
                end
                
                ROUTE: begin
                    target_module <= route_table[api_endpoint[7:0]];
                end
                
                AUTH: begin
                    if (api_endpoint[31:24] != 8'hAA) begin
                        api_status <= NOT_FOUND;
                    end
                end
                
                EXECUTE: begin
                    xrbus_response[31:0] <= api_endpoint;
                    xrbus_response[63:32] <= transaction_id;
                    xrbus_response[95:64] <= timestamp;
                    xrbus_response[1119:96] <= api_payload;
                    response_valid <= 1'b1;
                end
                
                RESPOND: begin
                    api_response <= xrbus_frame[1119:96];
                    api_response_valid <= 1'b1;
                    api_status <= OK;
                end
                
                ERROR: begin
                    api_response_valid <= 1'b1;
                end
            endcase
        end
    end
    
    // 下一狀態邏輯
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: if (api_request) next_state = ROUTE;
            ROUTE: next_state = AUTH;
            AUTH: if (api_status == OK) next_state = EXECUTE;
                  else next_state = ERROR;
            EXECUTE: if (response_valid) next_state = RESPOND;
            RESPOND: next_state = IDLE;
            ERROR: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule
