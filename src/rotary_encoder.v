`timescale 1ns / 1ps

// [참고] 12.rotary_sw/rotary.v 의 {이전상태, 현재상태} 전이 테이블을 그대로 사용
// [수정] r_step(0~3) 대신 +1/-1 누적값 r_acc 사용
//        -> 반시계도 정상 동작, 돌리다 되돌아와도 잘못된 펄스가 나가지 않음
//
//   CW  : 00 -> 10 -> 11 -> 01 -> 00   ({s1, s2})
//   CCW : 00 -> 01 -> 11 -> 10 -> 00
//   STEPS_PER_DETENT 번 전이가 쌓이면 cw / ccw 1클럭 펄스 출력
module rotary_encoder #(parameter STEPS_PER_DETENT = 4) (
    input  clk,
    input  reset,
    input  s1,       // 디바운싱된 A
    input  s2,       // 디바운싱된 B
    output reg cw,   // 시계 방향 1칸 (1클럭 펄스)
    output reg ccw   // 반시계 방향 1칸 (1클럭 펄스)
    );

    reg [1:0] r_prev_state, r_curr_state;
    reg signed [3:0] r_acc;          // 전이 누적값 (-4 ~ +4)
    reg signed [3:0] w_acc_next;

    wire [3:0] w_trans = {r_prev_state, r_curr_state};

    wire w_cw_step  = (w_trans == 4'b0010) || (w_trans == 4'b1011) ||
                      (w_trans == 4'b1101) || (w_trans == 4'b0100);
    wire w_ccw_step = (w_trans == 4'b0001) || (w_trans == 4'b0111) ||
                      (w_trans == 4'b1110) || (w_trans == 4'b1000);

    always @(*) begin
        if (w_cw_step)       w_acc_next = r_acc + 4'sd1;
        else if (w_ccw_step) w_acc_next = r_acc - 4'sd1;
        else                 w_acc_next = r_acc;
    end

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_prev_state <= 2'b00;
            r_curr_state <= 2'b00;
            r_acc        <= 0;
            cw           <= 0;
            ccw          <= 0;
        end else begin
            r_prev_state <= r_curr_state;
            r_curr_state <= {s1, s2};
            cw  <= 0;
            ccw <= 0;
            if (w_acc_next == STEPS_PER_DETENT) begin
                cw    <= 1;
                r_acc <= 0;
            end else if (w_acc_next == -STEPS_PER_DETENT) begin
                ccw   <= 1;
                r_acc <= 0;
            end else begin
                r_acc <= w_acc_next;
            end
        end
    end
endmodule
