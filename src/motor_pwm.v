`timescale 1ns / 1ps

// [참고] 10.pwm_control/pwm_duty_control.v (카운터 < duty 비교로 PWM 생성)
// [수정] 버튼으로 duty 직접 조절 -> 세기 1~5 단계를 duty 표로 변환
//        PWM 주파수 20kHz (100MHz / 5000) : 모터 소음(가청 주파수) 줄임
//        조리 중(run)에만 턴테이블 모터 회전
module motor_pwm #(parameter PWM_PERIOD = 5000) (   // 100MHz / 5000 = 20kHz
    input        clk,
    input        reset,
    input        run,
    input  [2:0] level,       // 1 ~ 5
    output       pwm_out,
    output [1:0] in1_in2      // 방향 : 10 = 정방향, 00 = 정지
    );

    // 세기별 duty : 40 / 55 / 70 / 85 / 100 %
    // (너무 낮은 duty 는 모터가 돌지 않아서 40% 부터 시작)
    reg [12:0] w_duty;
    always @(*) begin
        case (level)
            3'd1:    w_duty = PWM_PERIOD * 40 / 100;
            3'd2:    w_duty = PWM_PERIOD * 55 / 100;
            3'd3:    w_duty = PWM_PERIOD * 70 / 100;
            3'd4:    w_duty = PWM_PERIOD * 85 / 100;
            3'd5:    w_duty = PWM_PERIOD;
            default: w_duty = PWM_PERIOD * 70 / 100;
        endcase
    end

    reg [12:0] r_pwm_counter;
    always @(posedge clk, posedge reset) begin
        if (reset)
            r_pwm_counter <= 0;
        else if (r_pwm_counter >= PWM_PERIOD - 1)
            r_pwm_counter <= 0;
        else
            r_pwm_counter <= r_pwm_counter + 1;
    end

    assign pwm_out = run && (r_pwm_counter < w_duty);
    assign in1_in2 = run ? 2'b10 : 2'b00;
endmodule
