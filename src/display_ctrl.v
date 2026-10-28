`timescale 1ns / 1ps

// [신규] 상태에 따라 FND에 보낼 4자리 문자 코드 / dot / blank / 애니메이션 결정
//
//   IDLE  : MM.SS
//   COOK  : circle 애니메이션 1.2초 <-> 남은 시간 1.2초 번갈아 표시
//   PAUSE : MM.SS 0.5초마다 깜박임
//   DONE  : 00.00 0.5초 ON / 0.5초 OFF x 3회
//   메시지 (1초) : 문 열림 "OPEN",  모터 세기 변경 "P--3"
module display_ctrl #(parameter MSG_TIME = 10'd1000) (   // 메시지 표시 1초 (ms)
    input clk,
    input reset,
    input tick_1ms,
    input [1:0]  state,
    input [12:0] time_sec,
    input [2:0]  power_level,
    input        ev_door_open,
    input        ev_power,
    output reg [15:0] digits,     // {d1000, d100, d10, d1}
    output reg        dot,
    output reg        blank,
    output reg        anim,
    output reg [3:0]  anim_step
    );

    localparam [1:0] IDLE = 2'd0, COOK = 2'd1, PAUSE = 2'd2, DONE = 2'd3;

    // fnd_controller 문자 코드
    localparam [3:0] C_P = 4'd10, C_E = 4'd11, C_n = 4'd12, C_DASH = 4'd13;

    localparam [1:0] MSG_NONE = 2'd0, MSG_OPEN = 2'd1, MSG_PWR = 2'd2;

    // ---- 상태별 ms 카운터 (상태가 바뀌면 0부터)
    reg [1:0]  r_prev_state;
    reg [11:0] r_ms;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_prev_state <= IDLE;
            r_ms         <= 0;
        end else begin
            r_prev_state <= state;
            if (state != r_prev_state)
                r_ms <= 0;
            else if (tick_1ms) begin
                if      (state == COOK  && r_ms == 12'd2399) r_ms <= 0;   // 2.4초 주기
                else if (state == PAUSE && r_ms == 12'd999)  r_ms <= 0;   // 1초 주기
                else if (state == IDLE)                      r_ms <= 0;
                else                                         r_ms <= r_ms + 1;
            end
        end
    end

    // ---- 메시지 1초 표시
    reg [1:0] r_msg;
    reg [9:0] r_msg_ms;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_msg    <= MSG_NONE;
            r_msg_ms <= 0;
        end else if (ev_door_open) begin
            r_msg    <= MSG_OPEN;
            r_msg_ms <= 0;
        end else if (ev_power) begin
            r_msg    <= MSG_PWR;
            r_msg_ms <= 0;
        end else if (r_msg != MSG_NONE && tick_1ms) begin
            if (r_msg_ms == MSG_TIME-1) r_msg <= MSG_NONE;
            else                        r_msg_ms <= r_msg_ms + 1;
        end
    end

    // ---- 남은 시간 -> MM.SS 자리별 숫자 (나눗셈이 길어서 레지스터로 한 번 끊음)
    wire [6:0] w_min = time_sec / 60;
    wire [5:0] w_sec = time_sec % 60;
    wire [3:0] w_min10 = w_min / 10;    // 각 자리를 4bit 로 잘라서 이어 붙인다
    wire [3:0] w_min1  = w_min % 10;
    wire [3:0] w_sec10 = w_sec / 10;
    wire [3:0] w_sec1  = w_sec % 10;
    reg [15:0] r_time_digits;

    always @(posedge clk, posedge reset) begin
        if (reset) r_time_digits <= 0;
        else       r_time_digits <= {w_min10, w_min1, w_sec10, w_sec1};
    end

    // ---- DONE : 0~0.5 / 1~1.5 / 2~2.5초 에만 켜짐
    wire w_done_on = (r_ms < 500) || (r_ms >= 1000 && r_ms < 1500) || (r_ms >= 2000 && r_ms < 2500);

    // ---- 최종 표시 선택
    always @(*) begin
        digits    = r_time_digits;
        dot       = 1'b1;
        blank     = 1'b0;
        anim      = 1'b0;
        anim_step = 4'd0;

        if (state == DONE) begin
            digits = 16'h0000;                         // 00.00
            blank  = !w_done_on;
        end else if (r_msg == MSG_OPEN) begin
            digits = {4'd0, C_P, C_E, C_n};            // OPEN
            dot    = 1'b0;
        end else if (r_msg == MSG_PWR) begin
            digits = {C_P, C_DASH, C_DASH, 1'b0, power_level};   // P--3
            dot    = 1'b0;
        end else if (state == COOK && r_ms < 1200) begin
            anim      = 1'b1;
            anim_step = r_ms / 100;                    // 100ms 마다 한 칸, 12칸 = 1.2초
        end else if (state == PAUSE) begin
            blank = (r_ms >= 500);
        end
    end

endmodule
