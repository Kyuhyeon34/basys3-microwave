`timescale 1ns / 1ps

// [원본] 12.dc_motor_control/tick_generator.v (그대로 재사용)
// INPUT_FREQ / TICK_Hz 마다 1클럭 펄스 (기본 1kHz = 1ms)
module tick_generator #(
    parameter INPUT_FREQ = 100_000_000,
    parameter TICK_Hz    = 1000
)(
    input clk,
    input reset,
    output reg tick
    );

    localparam TICK_COUNT = INPUT_FREQ / TICK_Hz;

    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter=0;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tick <= 0;
            r_tick_counter <= 0;
        end else begin
            if (r_tick_counter == TICK_COUNT-1) begin
                r_tick_counter <= 0;
                tick <= 1'b1;
            end else begin
                r_tick_counter <= r_tick_counter + 1;
                tick <= 0;
            end
        end
    end
endmodule
