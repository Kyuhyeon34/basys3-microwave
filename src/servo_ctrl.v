`timescale 1ns / 1ps

// [신규] 문 열기/닫기 서보 모터 (SG90) 제어
//   50Hz (20ms 주기) PWM, 펄스 폭 1ms = 0도 / 1.5ms = 90도 / 2ms = 180도
//   문 닫힘 : CLOSE_US,  문 열림 : OPEN_US
//   [아이디어] 펄스 폭을 프레임(20ms)마다 조금씩 바꿔서 MOVE_MS 동안 천천히 열고 닫음
module servo_ctrl #(
    parameter INPUT_FREQ = 100_000_000,
    parameter CLOSE_US   = 1000,      // 1.0ms : 0도  (닫힘)
    parameter OPEN_US    = 1500,      // 1.5ms : 90도 (열림)
    parameter MOVE_MS    = 1000       // 여닫는 시간 1초
)(
    input  clk,
    input  reset,
    input  door_open,
    output servo_pwm,
    output moving                     // 움직이는 중
    );

    localparam PERIOD  = INPUT_FREQ / 50;                     // 20ms
    localparam CLOSE_W = INPUT_FREQ / 1000 * CLOSE_US / 1000; // 클럭 수
    localparam OPEN_W  = INPUT_FREQ / 1000 * OPEN_US  / 1000;
    localparam FRAMES  = MOVE_MS / 20;                        // 움직이는 프레임 수
    localparam STEP    = (OPEN_W - CLOSE_W) / FRAMES;         // 프레임당 변화량
    localparam W       = $clog2(PERIOD + 1);

    reg  [W-1:0] r_cnt;       // 20ms 주기 카운터
    reg  [W-1:0] r_width;     // 현재 펄스 폭
    wire [W-1:0] w_target = door_open ? OPEN_W : CLOSE_W;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_cnt   <= 0;
            r_width <= CLOSE_W;
        end else begin
            if (r_cnt == PERIOD - 1) begin
                r_cnt <= 0;
                // 프레임이 끝날 때마다 목표 쪽으로 STEP 만큼 이동
                if (r_width < w_target)
                    r_width <= (w_target - r_width > STEP) ? r_width + STEP : w_target;
                else if (r_width > w_target)
                    r_width <= (r_width - w_target > STEP) ? r_width - STEP : w_target;
            end else begin
                r_cnt <= r_cnt + 1;
            end
        end
    end

    assign servo_pwm = (r_cnt < r_width);
    assign moving    = (r_width != w_target);
endmodule
