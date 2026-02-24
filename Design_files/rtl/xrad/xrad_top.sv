/**
 * XRAD (XR Advanced Driver) Top Module
 */
module xrad_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] xsm_ch_valid,
    input  logic [31:0] xsm_ch_data [0:11],
    input  logic [2:0]  xenos_state,
    input  logic        xenos_fault,
    output logic        xrad_ready,
    output logic        ai_busy,
    output logic [31:0] ai_result,
    output logic [31:0] rt_output,
    output logic [63:0] high_speed_data,
    output logic        data_valid
);

    logic        ai_done;
    
    xrad_ai_accelerator u_ai_accel (
        .clk        (clk),
        .rst_n      (rst_n),
        .ch_valid   (xsm_ch_valid[3:0]),
        .ch_data0   (xsm_ch_data[0]),
        .ch_data1   (xsm_ch_data[1]),
        .ch_data2   (xsm_ch_data[2]),
        .ch_data3   (xsm_ch_data[3]),
        .ai_busy    (ai_busy),
        .ai_result  (ai_result),
        .ai_done    (ai_done)
    );
    
    xrad_rt_processor u_rt_proc (
        .clk        (clk),
        .rst_n      (rst_n),
        .xsm_valid  (xsm_ch_valid[11:4]),
        .xsm_data0  (xsm_ch_data[4]),
        .xsm_data1  (xsm_ch_data[5]),
        .xsm_data2  (xsm_ch_data[6]),
        .xsm_data3  (xsm_ch_data[7]),
        .xsm_data4  (xsm_ch_data[8]),
        .xsm_data5  (xsm_ch_data[9]),
        .xsm_data6  (xsm_ch_data[10]),
        .xsm_data7  (xsm_ch_data[11]),
        .xenos_state(xenos_state),
        .rt_output  (rt_output)
    );
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            high_speed_data <= 64'b0;
            data_valid <= 1'b0;
        end else begin
            high_speed_data <= {ai_result[31:0], rt_output[31:0]};
            data_valid <= ai_done;
        end
    end
    
    assign xrad_ready = ~ai_busy;

endmodule
