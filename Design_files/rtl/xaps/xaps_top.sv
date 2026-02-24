/**
 * XAPS Top Module
 * 整合 API 核心、解決方案模板和應用層
 */
module xaps_top (
    input  logic        clk,
    input  logic        rst_n,
    
    // XR-BUS 介面
    input  logic [4095:0] xrbus_frame_in,
    input  logic          frame_valid_in,
    output logic [4095:0] xrbus_frame_out,
    output logic          frame_valid_out,
    
    // API 介面 (給外部應用)
    input  logic [31:0]   api_endpoint,
    input  logic [7:0]    api_method,
    input  logic [1023:0] api_payload,
    input  logic          api_request,
    output logic [31:0]   api_status,
    output logic [1023:0] api_response,
    output logic          api_response_valid,
    
    // 解決方案配置
    input  logic [7:0]    solution_type,
    input  logic [31:0]   customer_id,
    input  logic          template_request,
    
    // 應用程式註冊
    input  logic [31:0]   app_id,
    input  logic [255:0]  app_name,
    input  logic [7:0]    app_priority,
    input  logic          app_register,
    
    // 狀態
    output logic [3:0]    xaps_state,
    output logic          xaps_busy
);

    // 內部訊號
    logic [4095:0] api_to_bus;
    logic          api_to_bus_valid;
    logic [4095:0] bus_to_api;
    logic          bus_to_api_valid;
    
    logic [4095:0] template_config;
    logic          template_valid;
    
    logic [1023:0] template_params;
    logic [511:0]  workflow_def;
    logic [255:0]  sla_temp;
    logic          template_ready;
    
    logic [31:0]   notification;
    logic [1023:0] action;
    logic          action_req;
    logic [4095:0] app_message;
    logic          app_msg_valid;
    
    // 路由表
    logic [7:0] route_table [0:255];
    
    // 初始化路由表
    initial begin
        for (int i = 0; i < 256; i++) begin
            route_table[i] = 8'd0;
        end
        route_table[8'h01] = 8'h01;  // XRAD
        route_table[8'h02] = 8'h02;  // XENOS
        route_table[8'h03] = 8'h03;  // XENOA
        route_table[8'h04] = 8'h04;  // XRAS
        route_table[8'h05] = 8'h05;  // XRST
    end
    
    // 狀態機
    typedef enum logic [3:0] {
        IDLE = 4'd0,
        API_PROCESS = 4'd1,
        TEMPLATE = 4'd2,
        APPLICATION = 4'd3,
        RESPOND = 4'd4
    } state_t;
    
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            xaps_busy <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    always_comb begin
        next_state = state;
        xaps_busy = 1'b1;
        
        case (state)
            IDLE: begin
                if (api_request) begin
                    next_state = API_PROCESS;
                end else if (template_request) begin
                    next_state = TEMPLATE;
                end else if (app_register) begin
                    next_state = APPLICATION;
                end else begin
                    xaps_busy = 1'b0;
                end
            end
            
            API_PROCESS: begin
                if (api_response_valid) begin
                    next_state = RESPOND;
                end
            end
            
            TEMPLATE: begin
                if (template_ready) begin
                    next_state = RESPOND;
                end
            end
            
            APPLICATION: begin
                next_state = RESPOND;
            end
            
            RESPOND: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    assign xaps_state = state;
    
    // 實體化子模組
    xaps_api_core u_api (
        .clk            (clk),
        .rst_n          (rst_n),
        .xrbus_frame    (xrbus_frame_in),
        .frame_valid    (frame_valid_in),
        .xrbus_response (api_to_bus),
        .response_valid (api_to_bus_valid),
        .api_endpoint   (api_endpoint),
        .api_method     (api_method),
        .api_payload    (api_payload),
        .api_request    (api_request && state == API_PROCESS),
        .api_status     (api_status),
        .api_response   (api_response),
        .api_response_valid(api_response_valid),
        .route_table    (route_table)
    );
    
    xaps_solution_templates u_templates (
        .clk            (clk),
        .rst_n          (rst_n),
        .solution_type  (solution_type),
        .customer_id    (customer_id),
        .template_request(template_request && state == TEMPLATE),
        .xrbus_config   (template_config),
        .config_valid   (template_valid),
        .template_params(template_params),
        .workflow_definition(workflow_def),
        .sla_template   (sla_temp),
        .template_ready (template_ready)
    );
    
    xaps_application_layer u_app (
        .clk            (clk),
        .rst_n          (rst_n),
        .app_id         (app_id),
        .app_name       (app_name),
        .app_priority   (app_priority),
        .app_register   (app_register && state == APPLICATION),
        .event_type     (xrbus_frame_in[95:64]),
        .event_data     (xrbus_frame_in[1119:96]),
        .event_trigger  (frame_valid_in),
        .notification   (notification),
        .action_payload (action),
        .action_required(action_req),
        .xrbus_message  (app_message),
        .message_valid  (app_msg_valid)
    );
    
    // 輸出選擇
    always_comb begin
        if (api_to_bus_valid) begin
            xrbus_frame_out = api_to_bus;
            frame_valid_out = api_to_bus_valid;
        end else if (template_valid) begin
            xrbus_frame_out = template_config;
            frame_valid_out = template_valid;
        end else if (app_msg_valid) begin
            xrbus_frame_out = app_message;
            frame_valid_out = app_msg_valid;
        end else begin
            xrbus_frame_out = 4096'b0;
            frame_valid_out = 1'b0;
        end
    end

endmodule
