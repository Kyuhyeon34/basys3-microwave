`timescale 1ns / 1ps

// [원본] 11.stopwatch/fnd_controller.v
// [수정] in_data(0~9999) 대신 4자리 문자 코드를 직접 받음 (P, E, n, - 표시용)
//        blank(전체 끄기) 추가 , circle 애니메이션 / dot 은 원본 그대로
//
//   문자 코드 : 0~9 숫자, 10 'P', 11 'E', 12 'N', 13 '-', 15 꺼짐
module fnd_controller(
    input clk,
    input reset,
    input tick,              // 1ms : 자리 전환
    input [15:0] digits,     // {d1000, d100, d10, d1}
    input dot,               // 가운데 dot (digit 2)
    input blank,             // [추가] 전체 끄기
    input anim,              // circle 애니메이션 표시
    input [3:0] anim_step,   // 애니메이션 위치 0~11
    output [3:0] an,
    output [7:0] seg
    );

    wire [1:0] w_sel;

    fnd_digit_select u_fnd_digit_select(
        .clk(clk),
        .reset(reset),
        .tick(tick),
        .sel(w_sel)
    );

    fnd_digit_display u_fnd_digit_display(
        .sel(w_sel),
        .digits(digits),
        .dot(dot),
        .blank(blank),
        .anim(anim),
        .anim_step(anim_step),
        .an(an),
        .seg(seg)
    );
endmodule

// tick(1ms)마다 표시할 자리를 0 → 1 → 2 → 3 순서로 바꾼다
module fnd_digit_select(
    input clk,
    input reset,
    input tick,
    output reg [1:0] sel
);
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            sel <= 0;
        end else begin
            if (tick)
                sel <= sel + 1;
        end
    end
endmodule

// sel에 해당하는 자리를 켜고(an), 그 자리의 문자를 seg로 내보낸다
//   seg 비트 : [0]a [1]b [2]c [3]d [4]e [5]f [6]g [7]dp  (0 = 켜짐)
module fnd_digit_display(
    input [1:0] sel,
    input [15:0] digits,
    input dot,
    input blank,
    input anim,
    input [3:0] anim_step,
    output reg [3:0] an,
    output reg [7:0] seg
);
    reg [3:0] r_code;        // 현재 자리 문자 코드
    reg [7:0] r_num_seg;     // 문자 패턴
    reg [1:0] r_anim_digit;  // 애니메이션이 켜질 자리
    reg [7:0] r_anim_seg;    // 애니메이션이 켜질 세그먼트

    always @(*) begin
        case (sel)
            2'b00: begin r_code = digits[3:0];   an = 4'b1110; end
            2'b01: begin r_code = digits[7:4];   an = 4'b1101; end
            2'b10: begin r_code = digits[11:8];  an = 4'b1011; end
            2'b11: begin r_code = digits[15:12]; an = 4'b0111; end
            default: begin r_code = 4'd15;       an = 4'b1111; end
        endcase
    end

    always @(*) begin
        case (r_code)
            4'd0:  r_num_seg = 8'b11000000;   // 0 (O)
            4'd1:  r_num_seg = 8'b11111001;   // 1
            4'd2:  r_num_seg = 8'b10100100;   // 2
            4'd3:  r_num_seg = 8'b10110000;   // 3
            4'd4:  r_num_seg = 8'b10011001;   // 4
            4'd5:  r_num_seg = 8'b10010010;   // 5
            4'd6:  r_num_seg = 8'b10000010;   // 6
            4'd7:  r_num_seg = 8'b11111000;   // 7
            4'd8:  r_num_seg = 8'b10000000;   // 8
            4'd9:  r_num_seg = 8'b10010000;   // 9
            4'd10: r_num_seg = 8'b10001100;   // P  (a b e f g)
            4'd11: r_num_seg = 8'b10000110;   // E  (a d e f g)
            4'd12: r_num_seg = 8'b11001000;   // N  (a b c e f) : 위 가로획을 쓰는 큰 n
            4'd13: r_num_seg = 8'b10111111;   // -  (g)
            default: r_num_seg = 8'b11111111; // 꺼짐
        endcase
    end

    // circle 애니메이션 : 4자리 바깥 테두리 12칸을 시계 방향으로 회전 (원본 그대로)
    always @(*) begin
        case (anim_step)
            4'd0:  begin r_anim_digit = 2'd3; r_anim_seg = 8'b11111110; end  // a
            4'd1:  begin r_anim_digit = 2'd2; r_anim_seg = 8'b11111110; end  // a
            4'd2:  begin r_anim_digit = 2'd1; r_anim_seg = 8'b11111110; end  // a
            4'd3:  begin r_anim_digit = 2'd0; r_anim_seg = 8'b11111110; end  // a
            4'd4:  begin r_anim_digit = 2'd0; r_anim_seg = 8'b11111101; end  // b
            4'd5:  begin r_anim_digit = 2'd0; r_anim_seg = 8'b11111011; end  // c
            4'd6:  begin r_anim_digit = 2'd0; r_anim_seg = 8'b11110111; end  // d
            4'd7:  begin r_anim_digit = 2'd1; r_anim_seg = 8'b11110111; end  // d
            4'd8:  begin r_anim_digit = 2'd2; r_anim_seg = 8'b11110111; end  // d
            4'd9:  begin r_anim_digit = 2'd3; r_anim_seg = 8'b11110111; end  // d
            4'd10: begin r_anim_digit = 2'd3; r_anim_seg = 8'b11101111; end  // e
            4'd11: begin r_anim_digit = 2'd3; r_anim_seg = 8'b11011111; end  // f
            default: begin r_anim_digit = 2'd0; r_anim_seg = 8'b11111111; end
        endcase
    end

    // 최종 출력 : blank / 애니메이션 / 문자 + dot
    always @(*) begin
        if (blank)
            seg = 8'b11111111;
        else if (anim)
            seg = (sel == r_anim_digit) ? r_anim_seg : 8'b11111111;
        else if (sel == 2'b10 && dot)
            seg = r_num_seg & 8'b01111111;   // digit 2의 dp 켜기 (MM.SS)
        else
            seg = r_num_seg;
    end
endmodule
