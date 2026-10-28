`timescale 1ns / 1ps

// [원본] 12.rotary_sw/btn_debounce10ms.v 의 debouncer (그대로 재사용)
// 버튼 채터링 제거 : 입력이 DEBOUNCE_LIMIT 클럭 동안 같은 값이면 인정
//   버튼   : 10ms (999_999)
//   로터리 : 2ms  (199_999)
module debouncer #(parameter DEBOUNCE_LIMIT = 20'd999_999) (
    input      clk,
    input      reset,
    input      noisy_btn,  // raw noisy button input
    output reg clean_btn
);
    reg [19:0] r_count;
    reg r_btn_state=0;

    // ---- 2단 D-FF 동기화기 : 비동기 입력을 클럭 도메인에 동기화 (메타스테빌리티 방지)
    reg r_FF1, r_FF2;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_FF1 <= 0;
            r_FF2 <= 0;
        end else begin
            r_FF1 <= noisy_btn;
            r_FF2 <= r_FF1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_count <= 0;
            r_btn_state <= 0;
            clean_btn <= 0;
        end else if (r_FF2 == r_btn_state) begin  // 상태가 이전과 동일 (안정됨)
            r_count <= 0;
        end else begin
            if (r_count < DEBOUNCE_LIMIT)          // 바뀌었지만 아직 안정되지 않음
                r_count <= r_count + 1;
            else begin                             // 충분히 오래 유지됨
                r_btn_state <= r_FF2;
                clean_btn <= r_FF2;
                r_count <= 0;
            end
        end
    end
endmodule
