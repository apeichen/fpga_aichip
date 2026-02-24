/**
 * XAPS Application Layer
 * 提供應用層服務和介面
 */
module xaps_application_layer (
    input  logic        clk,
    input  logic        rst_n,
    
    // 應用程式註冊
    input  logic [31:0]  app_id,
    input  logic [255:0] app_name,
    input  logic [7:0]   app_priority,
    input  logic         app_register,
    
    // 應用程式事件
    input  logic [31:0]  event_type,
    input  logic [1023:0] event_data,
    input  logic         event_trigger,
    
    // 應用程式輸出
    output logic [31:0]  notification,
    output logic [1023:0] action_payload,
    output logic         action_required,
    
    // XR-BUS 介面
    output logic [4095:0] xrbus_message,
    output logic          message_valid
);

    // 應用程式註冊表
    logic [31:0]  app_id_table [0:15];
    logic [255:0] app_name_table [0:15];
    logic [7:0]   app_priority_table [0:15];
    logic         app_active [0:15];
    logic [3:0]   app_count;
    logic [3:0]   selected_app;
    logic         app_found;
    
    // 事件佇列
    logic [31:0]  event_timestamp [0:63];
    logic [31:0]  event_type_queue [0:63];
    logic [1023:0] event_data_queue [0:63];
    logic [3:0]   event_target [0:63];
    logic [5:0]   queue_wr_ptr;
    logic [5:0]   queue_rd_ptr;
    logic [5:0]   queue_level;
    
    // 應用程式註冊
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            app_count <= 4'b0;
            queue_wr_ptr <= 6'b0;
            queue_rd_ptr <= 6'b0;
            queue_level <= 6'b0;
            
            for (int i = 0; i < 16; i++) begin
                app_active[i] <= 1'b0;
            end
        end else begin
            // 註冊新應用程式
            if (app_register && app_count < 16) begin
                app_id_table[app_count] <= app_id;
                app_name_table[app_count] <= app_name;
                app_priority_table[app_count] <= app_priority;
                app_active[app_count] <= 1'b1;
                app_count <= app_count + 1;
            end
            
            // 事件入佇列
            if (event_trigger && queue_level < 64) begin
                event_timestamp[queue_wr_ptr] <= $time;
                event_type_queue[queue_wr_ptr] <= event_type;
                event_data_queue[queue_wr_ptr] <= event_data;
                event_target[queue_wr_ptr] <= app_id[3:0];
                queue_wr_ptr <= queue_wr_ptr + 1;
                queue_level <= queue_level + 1;
            end
        end
    end
    
    // 事件分派（不使用 break）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            notification <= 32'b0;
            action_payload <= 1024'b0;
            action_required <= 1'b0;
            xrbus_message <= 4096'b0;
            message_valid <= 1'b0;
            selected_app <= 4'b0;
            app_found <= 1'b0;
        end else if (queue_level > 0 && !app_found) begin
            app_found <= 1'b0;
            
            // 順序檢查每個應用程式
            if (app_active[0] && app_priority_table[0] > 4 && !app_found) begin
                selected_app <= 4'd0;
                app_found <= 1'b1;
            end
            if (app_active[1] && app_priority_table[1] > 4 && !app_found) begin
                selected_app <= 4'd1;
                app_found <= 1'b1;
            end
            if (app_active[2] && app_priority_table[2] > 4 && !app_found) begin
                selected_app <= 4'd2;
                app_found <= 1'b1;
            end
            if (app_active[3] && app_priority_table[3] > 4 && !app_found) begin
                selected_app <= 4'd3;
                app_found <= 1'b1;
            end
            if (app_active[4] && app_priority_table[4] > 4 && !app_found) begin
                selected_app <= 4'd4;
                app_found <= 1'b1;
            end
            if (app_active[5] && app_priority_table[5] > 4 && !app_found) begin
                selected_app <= 4'd5;
                app_found <= 1'b1;
            end
            if (app_active[6] && app_priority_table[6] > 4 && !app_found) begin
                selected_app <= 4'd6;
                app_found <= 1'b1;
            end
            if (app_active[7] && app_priority_table[7] > 4 && !app_found) begin
                selected_app <= 4'd7;
                app_found <= 1'b1;
            end
            
            if (app_found) begin
                notification <= {app_id_table[selected_app][15:0], event_type_queue[queue_rd_ptr][15:0]};
                action_payload <= event_data_queue[queue_rd_ptr];
                action_required <= 1'b1;
                
                xrbus_message[31:0] <= app_id_table[selected_app];
                xrbus_message[63:32] <= event_timestamp[queue_rd_ptr];
                xrbus_message[95:64] <= event_type_queue[queue_rd_ptr];
                xrbus_message[1119:96] <= event_data_queue[queue_rd_ptr];
                message_valid <= 1'b1;
                
                queue_rd_ptr <= queue_rd_ptr + 1;
                queue_level <= queue_level - 1;
            end
        end else begin
            app_found <= 1'b0;
        end
    end

endmodule
