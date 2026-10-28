`timescale 1ns / 1ps

// [신규] 전자레인지 테스트벤치
// 시뮬레이션용으로 INPUT_FREQ를 1/1000로 줄임 -> 실제 1초 = 시뮬레이션 1ms
//   (tick 1ms, 서보 20ms 주기, 부저 음 주파수 모두 같은 비율로 줄어듦)
module tb_microwave();
    reg clk = 0;
    reg reset = 0;
    reg [4:0] btn = 0;        // [0]U +30  [1]L 문  [2]C 시작  [3]R 취소  [4]D 세기
    reg rot_s1 = 0, rot_s2 = 0, rot_key = 0;

    wire [7:0]  seg;
    wire [3:0]  an;
    wire [15:0] led;
    wire buzzer, servo_pwm, motor_pwm;
    wire [1:0] in1_in2;

    localparam SEC = 1_000_000;   // 시뮬레이션 1초 (ns)
    localparam BTN_U = 0, BTN_L = 1, BTN_C = 2, BTN_R = 3, BTN_D = 4;
    localparam IDLE = 2'd0, COOK = 2'd1, PAUSE = 2'd2, DONE = 2'd3;
    localparam S_CLICK = 3'd0, S_BEEP = 3'd1, S_ERROR = 3'd2, S_OPEN = 3'd3, S_CLOSE = 3'd4, S_DONE = 3'd5;

    top_microwave #(
        .INPUT_FREQ(100_000),
        .DEBOUNCE_LIMIT(20'd10),
        .ROT_DEBOUNCE_LIMIT(20'd10)
    ) u_top (
        .clk(clk),
        .reset(reset),
        .btn(btn),
        .rot_s1(rot_s1),
        .rot_s2(rot_s2),
        .rot_key(rot_key),
        .seg(seg),
        .an(an),
        .led(led),
        .buzzer(buzzer),
        .servo_pwm(servo_pwm),
        .motor_pwm(motor_pwm),
        .in1_in2(in1_in2)
    );

    // 내부 신호 확인용
    wire [1:0]  state     = u_top.u_microwave_fsm.curr_state;
    wire [12:0] time_sec  = u_top.u_microwave_fsm.time_sec;
    wire        door_open = u_top.u_microwave_fsm.door_open;
    wire [2:0]  level     = u_top.u_microwave_fsm.power_level;
    wire        edit_min  = u_top.u_microwave_fsm.edit_min;
    wire [2:0]  snd       = u_top.u_sound_player.r_snd;
    wire        playing   = u_top.u_sound_player.r_playing;
    wire [15:0] digits    = u_top.u_display_ctrl.digits;
    wire        anim      = u_top.u_display_ctrl.anim;
    wire        blank     = u_top.u_display_ctrl.blank;
    wire [11:0] servo_w   = u_top.u_servo_ctrl.r_width;   // 100 = 1ms(닫힘), 150 = 1.5ms(열림)

    always #5 clk = ~clk;

    reg r_error = 1'b0;
    reg [12:0] r_saved;
    integer k, high_cnt;

    task press(input integer idx);
    begin
        btn[idx] = 1;
        repeat(30) @(posedge clk);
        btn[idx] = 0;
        repeat(30) @(posedge clk);
    end
    endtask

    task press_key;
    begin
        rot_key = 1;
        repeat(30) @(posedge clk);
        rot_key = 0;
        repeat(30) @(posedge clk);
    end
    endtask

    // 왼쪽(반시계) : 00 -> 10 -> 11 -> 01 -> 00  ({s1, s2}), 중간에 채터링 1번 -> 시간 감소
    task rotate_left;
    begin
        rot_s1 = 1; #20 rot_s1 = 0; #20 rot_s1 = 1;   // 채터링
        repeat(30) @(posedge clk);
        rot_s2 = 1; repeat(30) @(posedge clk);
        rot_s1 = 0; repeat(30) @(posedge clk);
        rot_s2 = 0; repeat(30) @(posedge clk);
    end
    endtask

    // 오른쪽(시계) : 00 -> 01 -> 11 -> 10 -> 00 -> 시간 증가
    task rotate_right;
    begin
        rot_s2 = 1; repeat(30) @(posedge clk);
        rot_s1 = 1; repeat(30) @(posedge clk);
        rot_s2 = 0; repeat(30) @(posedge clk);
        rot_s1 = 0; repeat(30) @(posedge clk);
    end
    endtask

    task check(input cond, input [8*48-1:0] msg);
    begin
        if (cond) $display("ok   t=%0t  %0s", $time, msg);
        else begin
            r_error = 1'b1;
            $display("FAIL t=%0t  %0s  (state=%0d time=%0d door=%b lvl=%0d snd=%0d play=%b)",
                     $time, msg, state, time_sec, door_open, level, snd, playing);
        end
    end
    endtask

    initial begin
        #100 reset = 1;
        #100 reset = 0;
        #1000;

        // 1) 초기 상태
        check(state==IDLE && time_sec==0 && door_open==0 && level==3, "reset -> IDLE 00.00, door closed, P3");
        check(servo_w==100, "servo at 1.0ms (closed)");

        // 2) 시간 0 에서 START -> 에러음
        press(BTN_C);
        check(state==IDLE && snd==S_ERROR && playing, "START at 0 sec -> error beep");

        // 3) 로터리 시간 설정 (초 단위 10초)
        rotate_right; rotate_right; rotate_right;
        check(time_sec==30 && snd==S_CLICK, "rotary right x3 -> 00.30, click");
        check(digits==16'h0030, "FND shows 00.30");
        press_key;
        check(edit_min==1, "key -> minute unit");
        rotate_right;
        check(time_sec==90 && digits==16'h0130, "right in minute unit -> 01.30");
        rotate_left;
        check(time_sec==30, "left in minute unit -> 00.30");
        press_key;
        check(edit_min==0, "key -> second unit");
        rotate_left; rotate_left; rotate_left; rotate_left;
        check(time_sec==0, "left below 0 -> clamp 00.00");
        rotate_right; rotate_right;
        check(time_sec==20, "right x2 -> 00.20");

        // 4) 문 열기 -> 서보 열림, OPEN 표시, 문 열림 소리
        press(BTN_L);
        check(door_open && snd==S_OPEN && playing, "btnL -> door open sound");
        check(digits==16'h0ABC, "FND shows OPEN");
        #(SEC/2);
        check(servo_w > 100 && servo_w < 150, "servo moving slowly");
        #(SEC*7/10);
        check(servo_w==150, "servo at 1.5ms (open, 90 deg)");
        check(digits==16'h0020, "OPEN message gone after 1s");

        // 5) 문 열린 상태 START -> 에러
        press(BTN_C);
        check(state==IDLE && snd==S_ERROR, "START with door open -> error");

        // 6) 문 닫고 시작
        press(BTN_L);
        check(!door_open && snd==S_CLOSE, "btnL -> door close sound");
        press(BTN_C);
        check(state==COOK && in1_in2==2'b10 && led[1], "START -> COOK, motor ON");
        check(anim==1, "COOK: circle animation first");
        #(SEC*13/10);
        check(anim==0 && digits[15:8]==8'h00, "COOK: remaining time shown next");
        #(SEC*12/10);
        check(time_sec==18, "2 sec passed -> 00.18");

        // 7) 모터 PWM duty 확인 (세기 3 = 70%)
        high_cnt = 0;
        @(posedge clk);
        while (u_top.u_motor_pwm.r_pwm_counter != 0) @(posedge clk);
        for (k = 0; k < 5000; k = k + 1) begin
            @(posedge clk);
            if (motor_pwm) high_cnt = high_cnt + 1;
        end
        check(high_cnt==3500, "motor PWM duty 70% at P3");

        // 8) 세기 변경 -> P--4 표시
        press(BTN_D);
        check(level==4 && digits==16'hADD4 && led[14], "btnD -> P--4, LED bar 4");

        // 9) 조리 중 문 열기 -> 일시정지, 모터 정지, 시간 유지
        press(BTN_L);
        r_saved = time_sec;
        check(state==PAUSE && in1_in2==2'b00 && !motor_pwm, "door open in COOK -> PAUSE, motor OFF");
        #(SEC*2);
        check(time_sec==r_saved, "PAUSE: time holds");
        press(BTN_C);
        check(state==PAUSE && snd==S_ERROR, "START with door open in PAUSE -> error");
        press(BTN_L);
        press(BTN_C);
        check(state==COOK, "door close + START -> COOK again");

        // 10) 조리 중 +30초
        r_saved = time_sec;
        press(BTN_U);
        check(time_sec==r_saved+30 && state==COOK, "btnU in COOK -> +30 sec");

        // 11) START 다시 누르면 일시정지, 다시 누르면 재개
        press(BTN_C);
        check(state==PAUSE, "START in COOK -> PAUSE");
        press(BTN_C);
        check(state==COOK, "START in PAUSE -> COOK");

        // 12) 취소
        press(BTN_R);
        check(state==IDLE && time_sec==0 && snd==S_BEEP, "CANCEL -> IDLE 00.00, beep");

        // 13) Quick Start : IDLE 에서 btnU -> 30초 바로 시작
        press(BTN_U);
        check(state==COOK && time_sec==30, "btnU in IDLE -> quick start 00.30");
        press(BTN_R);

        // 14) 종료 : 10초 조리 -> DONE, 0 깜박임 3회 + 멜로디 3초 -> IDLE
        rotate_right;
        press(BTN_C);
        wait (state==DONE);
        check(time_sec==0 && snd==S_DONE && playing, "time out -> DONE, melody");
        #(SEC/4);
        check(digits==16'h0000 && !blank, "DONE: 00.00 ON");
        #(SEC/2);
        check(blank, "DONE: 00.00 OFF (blink)");
        #(SEC/2);
        check(!blank, "DONE: 00.00 ON (2nd)");
        #(SEC*19/10);
        check(state==IDLE, "3 sec later -> IDLE");
        check(!playing, "melody finished");

        // 15) DONE 중 취소 -> 알림 멈춤
        rotate_right;
        press(BTN_C);
        wait (state==DONE);
        #(SEC/2);
        press(BTN_R);
        check(state==IDLE && snd==S_BEEP, "CANCEL in DONE -> IDLE, alarm stops");

        if (r_error == 0) $display("PASS microwave");
        else              $display("FAIL microwave");
        $finish;
    end

endmodule
