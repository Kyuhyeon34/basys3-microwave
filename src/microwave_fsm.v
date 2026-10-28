`timescale 1ns / 1ps

// [신규] 11.stopwatch/stopwatch_fsm.v 형식 (상태 레지스터 / 다음 상태 / 출력) 으로 작성
//
// 전자레인지 FSM
//   IDLE  : 시간 설정 (로터리 / +30초)
//   COOK  : 조리 중 (1초마다 감소, 턴테이블 모터 ON)
//   PAUSE : 일시정지 (문 열림 또는 START 다시 누름)
//   DONE  : 종료 알림 (0 깜박임 3회 + 종료 멜로디, 3초 후 IDLE)
//
//   IDLE  --START (문 닫힘, 시간>0)--> COOK
//   IDLE  --+30초 (문 닫힘)---------> COOK   (Quick Start)
//   COOK  --문 열림 / START---------> PAUSE
//   COOK  --CANCEL------------------> IDLE   (시간 0으로)
//   COOK  --남은 시간 0-------------> DONE
//   PAUSE --START (문 닫힘)---------> COOK
//   PAUSE --CANCEL------------------> IDLE
//   DONE  --3초 / 아무 버튼 / 문----> IDLE
module microwave_fsm #(
    parameter MAX_TIME  = 13'd5999,   // 99분 59초
    parameter DONE_TIME = 12'd3000    // 종료 알림 3초 (ms)
)(
    input clk,
    input reset,
    input tick_1ms,
    // 디바운싱된 버튼 (레벨)
    input btn_start,      // btnC : 시작 / 일시정지
    input btn_cancel,     // btnR : 취소
    input btn_door,       // btnL : 문 열기 / 닫기
    input btn_quick,      // btnU : +30초 (Quick Start)
    input btn_power,      // btnD : 모터 세기 1~5
    input btn_key,        // 로터리 key : 분 / 초 설정 단위 전환
    // 로터리 (1클럭 펄스)
    input rot_cw,
    input rot_ccw,
    // 상태 출력
    output [1:0]      state,
    output reg [12:0] time_sec,      // 남은 시간 (초) 0 ~ 5999
    output reg        door_open,
    output reg [2:0]  power_level,   // 1 ~ 5
    output reg        edit_min,      // 0: 초 단위(10초)  1: 분 단위(1분)
    output            ev_power,      // 세기 변경 (FND 메시지용)
    // 효과음 트리거 (1클럭 펄스)
    output snd_click,
    output snd_beep,
    output snd_error,
    output snd_open,
    output snd_close,
    output snd_done
    );

    localparam [1:0] IDLE  = 2'd0,
                     COOK  = 2'd1,
                     PAUSE = 2'd2,
                     DONE  = 2'd3;

    reg [1:0]  curr_state, next_state;
    reg [11:0] r_ms_cnt;       // COOK: 0~999 (1초),  DONE: 0~2999 (3초)

    // ---- 버튼 엣지 검출 : 눌린 순간 1클럭
    wire [5:0] w_btn = {btn_key, btn_power, btn_quick, btn_door, btn_cancel, btn_start};
    reg  [5:0] r_prev_btn;

    always @(posedge clk, posedge reset) begin
        if (reset) r_prev_btn <= 0;
        else       r_prev_btn <= w_btn;
    end

    wire [5:0] w_push = w_btn & ~r_prev_btn;
    wire start  = w_push[0];
    wire cancel = w_push[1];
    wire door   = w_push[2];
    wire quick  = w_push[3];
    wire power  = w_push[4];
    wire key    = w_push[5];

    wire w_time_zero = (time_sec == 0);
    wire w_can_start = !door_open && !w_time_zero;
    wire w_sec_tick  = (curr_state == COOK) && tick_1ms && (r_ms_cnt == 12'd999);
    wire w_done_end  = (curr_state == DONE) && tick_1ms && (r_ms_cnt == DONE_TIME-1);

    // ---- 상태 레지스터
    always @(posedge clk, posedge reset) begin
        if (reset) curr_state <= IDLE;
        else       curr_state <= next_state;
    end

    // ---- 다음 상태 결정
    always @(*) begin
        case (curr_state)
        IDLE: begin
            if (start && w_can_start)       next_state = COOK;
            else if (quick && !door_open)   next_state = COOK;   // Quick Start
            else                            next_state = IDLE;
        end
        COOK: begin
            if (cancel)                     next_state = IDLE;
            else if (door_open || start)    next_state = PAUSE;
            else if (w_time_zero)           next_state = DONE;
            else                            next_state = COOK;
        end
        PAUSE: begin
            if (cancel)                     next_state = IDLE;
            else if (start && w_can_start)  next_state = COOK;
            else if (quick && !door_open)   next_state = COOK;
            else                            next_state = PAUSE;
        end
        DONE: begin
            if (w_done_end || cancel || start || door) next_state = IDLE;
            else                                        next_state = DONE;
        end
        default: next_state = IDLE;
        endcase
    end

    assign state = curr_state;

    // ---- ms 카운터 : 상태가 바뀌면 0부터 다시
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_ms_cnt <= 0;
        end else if (curr_state != next_state) begin
            r_ms_cnt <= 0;
        end else if (tick_1ms) begin
            if (curr_state == COOK && r_ms_cnt == 12'd999) r_ms_cnt <= 0;
            else                                           r_ms_cnt <= r_ms_cnt + 1;
        end
    end

    // ---- 남은 시간 (초)
    wire [12:0] w_step     = edit_min ? 13'd60 : 13'd10;
    wire [13:0] w_add_step = time_sec + w_step;
    wire [13:0] w_add_30   = time_sec + 13'd30;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            time_sec <= 0;
        end else if (curr_state == DONE) begin
            time_sec <= 0;
        end else if (cancel) begin                         // 취소 : 시간 지움
            time_sec <= 0;
        end else if (quick) begin                          // +30초
            time_sec <= (w_add_30 > MAX_TIME) ? MAX_TIME : w_add_30[12:0];
        end else if (rot_cw) begin                         // 로터리 시계 : 증가
            time_sec <= (w_add_step > MAX_TIME) ? MAX_TIME : w_add_step[12:0];
        end else if (rot_ccw) begin                        // 로터리 반시계 : 감소
            time_sec <= (time_sec > w_step) ? time_sec - w_step : 13'd0;
        end else if (w_sec_tick && !w_time_zero) begin     // 조리 중 1초마다 감소
            time_sec <= time_sec - 1;
        end
    end

    // ---- 문 / 모터 세기 / 설정 단위
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            door_open   <= 0;
            power_level <= 3'd3;
            edit_min    <= 0;
        end else begin
            if (door)  door_open   <= ~door_open;
            if (power) power_level <= (power_level == 3'd5) ? 3'd1 : power_level + 1;
            if (key)   edit_min    <= ~edit_min;
        end
    end

    assign ev_power = power;

    // ---- 효과음 트리거
    assign snd_open  = door &&  !door_open;
    assign snd_close = door &&   door_open;
    assign snd_done  = (curr_state != DONE) && (next_state == DONE);
    assign snd_error = start && !w_can_start && (curr_state == IDLE || curr_state == PAUSE);
    assign snd_beep  = (start && !snd_error) || cancel || quick || power || key;
    assign snd_click = (rot_cw || rot_ccw) && (curr_state != DONE);

endmodule
