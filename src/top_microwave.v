`timescale 1ns / 1ps

// [신규] 전자레인지 최상위
//
//   btnU : +30초 (문 닫혀 있으면 바로 시작 - Quick Start)
//   btnL : 문 열기 / 닫기 (서보 모터)
//   btnC : 시작 / 일시정지
//   btnR : 취소
//   btnD : 턴테이블 모터 세기 1 ~ 5 (PWM)
//   로터리 회전 : 시간 +/- (초 단위 10초, 분 단위 1분)
//   로터리 key  : 분 / 초 설정 단위 전환
//   sw15 : reset
module top_microwave #(
    parameter INPUT_FREQ         = 100_000_000,
    parameter DEBOUNCE_LIMIT     = 20'd999_999,   // 버튼 10ms
    parameter ROT_DEBOUNCE_LIMIT = 20'd199_999    // 로터리 2ms
)(
    input         clk,
    input         reset,
    input  [4:0]  btn,          // [0]U [1]L [2]C [3]R [4]D
    input         rot_s1,
    input         rot_s2,
    input         rot_key,
    output [7:0]  seg,
    output [3:0]  an,
    output [15:0] led,
    output        buzzer,
    output        servo_pwm,
    output        motor_pwm,
    output [1:0]  in1_in2
    );

    // ---------------------------------------------------------------- 디바운스
    wire [4:0] w_btn;
    wire w_s1, w_s2, w_key;

    genvar i;
    generate
        for (i = 0; i < 5; i = i + 1) begin : g_btn_debouncer
            debouncer #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) u_btn_debouncer (
                .clk(clk),
                .reset(reset),
                .noisy_btn(btn[i]),
                .clean_btn(w_btn[i])
            );
        end
    endgenerate

    debouncer #(.DEBOUNCE_LIMIT(DEBOUNCE_LIMIT)) u_key_debouncer (
        .clk(clk),
        .reset(reset),
        .noisy_btn(rot_key),
        .clean_btn(w_key)
    );

    debouncer #(.DEBOUNCE_LIMIT(ROT_DEBOUNCE_LIMIT)) u_s1_debouncer (
        .clk(clk),
        .reset(reset),
        .noisy_btn(rot_s1),
        .clean_btn(w_s1)
    );

    debouncer #(.DEBOUNCE_LIMIT(ROT_DEBOUNCE_LIMIT)) u_s2_debouncer (
        .clk(clk),
        .reset(reset),
        .noisy_btn(rot_s2),
        .clean_btn(w_s2)
    );

    // ---------------------------------------------------------------- 1ms tick
    wire w_tick_1ms;

    tick_generator #(.INPUT_FREQ(INPUT_FREQ), .TICK_Hz(1000)) u_tick_generator (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1ms)
    );

    // ---------------------------------------------------------------- 로터리
    wire w_rot_cw, w_rot_ccw;

    // [수정] 실제 보드에서 방향이 반대로 동작 -> 출력을 바꿔 연결
    //        오른쪽(시계)으로 돌리면 시간 증가, 왼쪽(반시계)으로 돌리면 시간 감소
    rotary_encoder u_rotary_encoder (
        .clk(clk),
        .reset(reset),
        .s1(w_s1),
        .s2(w_s2),
        .cw(w_rot_ccw),
        .ccw(w_rot_cw)
    );

    // ---------------------------------------------------------------- FSM
    wire [1:0]  w_state;
    wire [12:0] w_time_sec;
    wire        w_door_open;
    wire [2:0]  w_power_level;
    wire        w_edit_min;
    wire        w_ev_power;
    wire        w_snd_click, w_snd_beep, w_snd_error, w_snd_open, w_snd_close, w_snd_done;

    microwave_fsm u_microwave_fsm (
        .clk(clk),
        .reset(reset),
        .tick_1ms(w_tick_1ms),
        .btn_start(w_btn[2]),     // btnC
        .btn_cancel(w_btn[3]),    // btnR
        .btn_door(w_btn[1]),      // btnL
        .btn_quick(w_btn[0]),     // btnU
        .btn_power(w_btn[4]),     // btnD
        .btn_key(w_key),
        .rot_cw(w_rot_cw),
        .rot_ccw(w_rot_ccw),
        .state(w_state),
        .time_sec(w_time_sec),
        .door_open(w_door_open),
        .power_level(w_power_level),
        .edit_min(w_edit_min),
        .ev_power(w_ev_power),
        .snd_click(w_snd_click),
        .snd_beep(w_snd_beep),
        .snd_error(w_snd_error),
        .snd_open(w_snd_open),
        .snd_close(w_snd_close),
        .snd_done(w_snd_done)
    );

    // ---------------------------------------------------------------- FND
    wire [15:0] w_digits;
    wire        w_dot, w_blank, w_anim;
    wire [3:0]  w_anim_step;

    display_ctrl u_display_ctrl (
        .clk(clk),
        .reset(reset),
        .tick_1ms(w_tick_1ms),
        .state(w_state),
        .time_sec(w_time_sec),
        .power_level(w_power_level),
        .ev_door_open(w_snd_open),
        .ev_power(w_ev_power),
        .digits(w_digits),
        .dot(w_dot),
        .blank(w_blank),
        .anim(w_anim),
        .anim_step(w_anim_step)
    );

    fnd_controller u_fnd_controller (
        .clk(clk),
        .reset(reset),
        .tick(w_tick_1ms),
        .digits(w_digits),
        .dot(w_dot),
        .blank(w_blank),
        .anim(w_anim),
        .anim_step(w_anim_step),
        .an(an),
        .seg(seg)
    );

    // ---------------------------------------------------------------- 부저
    wire w_snd_playing;

    sound_player #(.INPUT_FREQ(INPUT_FREQ)) u_sound_player (
        .clk(clk),
        .reset(reset),
        .tick_1ms(w_tick_1ms),
        .snd_click(w_snd_click),
        .snd_beep(w_snd_beep),
        .snd_error(w_snd_error),
        .snd_open(w_snd_open),
        .snd_close(w_snd_close),
        .snd_done(w_snd_done),
        .buzzer(buzzer),
        .playing(w_snd_playing)
    );

    // ---------------------------------------------------------------- 서보 (문)
    wire w_servo_moving;

    servo_ctrl #(.INPUT_FREQ(INPUT_FREQ)) u_servo_ctrl (
        .clk(clk),
        .reset(reset),
        .door_open(w_door_open),
        .servo_pwm(servo_pwm),
        .moving(w_servo_moving)
    );

    // ---------------------------------------------------------------- 턴테이블 모터
    wire w_cooking = (w_state == 2'd1);   // COOK

    motor_pwm u_motor_pwm (
        .clk(clk),
        .reset(reset),
        .run(w_cooking),
        .level(w_power_level),
        .pwm_out(motor_pwm),
        .in1_in2(in1_in2)
    );

    // ---------------------------------------------------------------- LED
    assign led[0]  = w_door_open;            // 문 열림
    assign led[1]  = (w_state == 2'd1);      // COOK
    assign led[2]  = (w_state == 2'd2);      // PAUSE
    assign led[3]  = (w_state == 2'd3);      // DONE
    assign led[4]  = w_edit_min;             // 1: 분 단위 설정
    assign led[5]  = w_snd_playing;          // 부저 재생 중
    assign led[6]  = w_servo_moving;         // 문 움직이는 중
    assign led[7]  = motor_pwm;              // 모터 PWM (밝기로 세기 확인)
    assign led[8]  = w_door_open | w_cooking;  // 내부 조명 (문 열림 / 조리 중)
    assign led[10:9] = 2'b00;
    // 세기 막대 : 1 ~ 5 개 켜짐
    assign led[11] = (w_power_level >= 3'd1);
    assign led[12] = (w_power_level >= 3'd2);
    assign led[13] = (w_power_level >= 3'd3);
    assign led[14] = (w_power_level >= 3'd4);
    assign led[15] = (w_power_level >= 3'd5);

endmodule
