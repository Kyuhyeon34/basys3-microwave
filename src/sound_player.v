`timescale 1ns / 1ps

// [참고] 11.PWM_buzzer/play_poweron_opendoor.v (반주기 카운터로 음 만들기, 단계별 재생)
// [수정] 효과음을 표(ROM)로 정리 -> {반주기, 길이(ms), 마지막} 을 단계(step)마다 읽어서 재생
//        새 트리거가 오면 재생 중이던 소리를 끊고 새 소리 재생
//
//   CLICK : 로터리 1칸     4kHz 10ms
//   BEEP  : 버튼           2kHz 80ms
//   ERROR : 시작 불가      1kHz 80ms, 쉼 60ms, 1kHz 80ms
//   OPEN  : 문 열림        도 미 솔 도# (상승, 각 70ms)
//   CLOSE : 문 닫힘        도# 솔 미 도 (하강, 각 70ms)
//   DONE  : 조리 종료      (도 미 솔 도' 각 125ms + 쉼 500ms) x 3회 = 3초  -> FND 0 깜박임과 맞춤
module sound_player #(parameter INPUT_FREQ = 100_000_000) (
    input clk,
    input reset,
    input tick_1ms,
    input snd_click,
    input snd_beep,
    input snd_error,
    input snd_open,
    input snd_close,
    input snd_done,
    output buzzer,
    output playing
    );

    // 반주기 카운트 = INPUT_FREQ / 주파수 / 2  (duty 50%)
    localparam [17:0] HP_C4  = INPUT_FREQ / 2 / 262;    // 도
    localparam [17:0] HP_E4  = INPUT_FREQ / 2 / 330;    // 미
    localparam [17:0] HP_G4  = INPUT_FREQ / 2 / 392;    // 솔
    localparam [17:0] HP_CS5 = INPUT_FREQ / 2 / 554;    // 도#
    localparam [17:0] HP_C5  = INPUT_FREQ / 2 / 523;    // 높은 도
    localparam [17:0] HP_E5  = INPUT_FREQ / 2 / 659;
    localparam [17:0] HP_G5  = INPUT_FREQ / 2 / 784;
    localparam [17:0] HP_C6  = INPUT_FREQ / 2 / 1047;
    localparam [17:0] HP_1K  = INPUT_FREQ / 2 / 1000;
    localparam [17:0] HP_2K  = INPUT_FREQ / 2 / 2000;
    localparam [17:0] HP_4K  = INPUT_FREQ / 2 / 4000;
    localparam [17:0] REST   = 18'd0;                   // 쉼표

    localparam [2:0] S_CLICK = 3'd0, S_BEEP = 3'd1, S_ERROR = 3'd2,
                     S_OPEN  = 3'd3, S_CLOSE = 3'd4, S_DONE = 3'd5;

    reg [2:0]  r_snd;          // 재생 중인 소리
    reg [3:0]  r_step;         // 단계 0~15
    reg [9:0]  r_dur_cnt;      // 단계 길이 카운터 (ms)
    reg [17:0] r_tone_cnt;     // 반주기 카운터
    reg        r_buzzer;
    reg        r_playing;

    // ---- 효과음 표 (조합 논리)
    reg [17:0] w_half;
    reg [9:0]  w_dur;
    reg        w_last;

    always @(*) begin
        w_half = REST; w_dur = 10'd1; w_last = 1'b1;
        case ({r_snd, r_step})
            {S_CLICK, 4'd0}:  begin w_half = HP_4K;  w_dur = 10'd10;  w_last = 1; end

            {S_BEEP,  4'd0}:  begin w_half = HP_2K;  w_dur = 10'd80;  w_last = 1; end

            {S_ERROR, 4'd0}:  begin w_half = HP_1K;  w_dur = 10'd80;  w_last = 0; end
            {S_ERROR, 4'd1}:  begin w_half = REST;   w_dur = 10'd60;  w_last = 0; end
            {S_ERROR, 4'd2}:  begin w_half = HP_1K;  w_dur = 10'd80;  w_last = 1; end

            {S_OPEN,  4'd0}:  begin w_half = HP_C4;  w_dur = 10'd70;  w_last = 0; end
            {S_OPEN,  4'd1}:  begin w_half = HP_E4;  w_dur = 10'd70;  w_last = 0; end
            {S_OPEN,  4'd2}:  begin w_half = HP_G4;  w_dur = 10'd70;  w_last = 0; end
            {S_OPEN,  4'd3}:  begin w_half = HP_CS5; w_dur = 10'd70;  w_last = 1; end

            {S_CLOSE, 4'd0}:  begin w_half = HP_CS5; w_dur = 10'd70;  w_last = 0; end
            {S_CLOSE, 4'd1}:  begin w_half = HP_G4;  w_dur = 10'd70;  w_last = 0; end
            {S_CLOSE, 4'd2}:  begin w_half = HP_E4;  w_dur = 10'd70;  w_last = 0; end
            {S_CLOSE, 4'd3}:  begin w_half = HP_C4;  w_dur = 10'd70;  w_last = 1; end

            // 종료 멜로디 : 1초 단위 x 3회
            {S_DONE,  4'd0}, {S_DONE, 4'd5}, {S_DONE, 4'd10}:
                              begin w_half = HP_C5;  w_dur = 10'd125; w_last = 0; end
            {S_DONE,  4'd1}, {S_DONE, 4'd6}, {S_DONE, 4'd11}:
                              begin w_half = HP_E5;  w_dur = 10'd125; w_last = 0; end
            {S_DONE,  4'd2}, {S_DONE, 4'd7}, {S_DONE, 4'd12}:
                              begin w_half = HP_G5;  w_dur = 10'd125; w_last = 0; end
            {S_DONE,  4'd3}, {S_DONE, 4'd8}, {S_DONE, 4'd13}:
                              begin w_half = HP_C6;  w_dur = 10'd125; w_last = 0; end
            {S_DONE,  4'd4}, {S_DONE, 4'd9}:
                              begin w_half = REST;   w_dur = 10'd500; w_last = 0; end
            {S_DONE,  4'd14}: begin w_half = REST;   w_dur = 10'd500; w_last = 1; end

            default:          begin w_half = REST;   w_dur = 10'd1;   w_last = 1; end
        endcase
    end

    // ---- 트리거 우선순위 : DONE > OPEN > CLOSE > ERROR > BEEP > CLICK
    wire w_trig = snd_done | snd_open | snd_close | snd_error | snd_beep | snd_click;
    reg [2:0] w_new_snd;
    always @(*) begin
        if      (snd_done)  w_new_snd = S_DONE;
        else if (snd_open)  w_new_snd = S_OPEN;
        else if (snd_close) w_new_snd = S_CLOSE;
        else if (snd_error) w_new_snd = S_ERROR;
        else if (snd_beep)  w_new_snd = S_BEEP;
        else                w_new_snd = S_CLICK;
    end

    // ---- 재생
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_snd      <= S_CLICK;
            r_step     <= 0;
            r_dur_cnt  <= 0;
            r_tone_cnt <= 0;
            r_buzzer   <= 0;
            r_playing  <= 0;
        end else if (w_trig) begin                     // 새 소리 시작
            r_snd      <= w_new_snd;
            r_step     <= 0;
            r_dur_cnt  <= 0;
            r_tone_cnt <= 0;
            r_buzzer   <= 0;
            r_playing  <= 1;
        end else if (r_playing) begin
            // 음 만들기 : 반주기마다 토글
            if (w_half == REST) begin
                r_tone_cnt <= 0;
                r_buzzer   <= 0;
            end else if (r_tone_cnt >= w_half - 1) begin
                r_tone_cnt <= 0;
                r_buzzer   <= ~r_buzzer;
            end else begin
                r_tone_cnt <= r_tone_cnt + 1;
            end
            // 단계 길이 : ms 단위
            if (tick_1ms) begin
                if (r_dur_cnt >= w_dur - 1) begin
                    r_dur_cnt  <= 0;
                    r_tone_cnt <= 0;
                    r_buzzer   <= 0;
                    if (w_last) r_playing <= 0;        // 마지막 단계 -> 정지
                    else        r_step    <= r_step + 1;
                end else begin
                    r_dur_cnt <= r_dur_cnt + 1;
                end
            end
        end else begin
            r_buzzer <= 0;
        end
    end

    assign buzzer  = r_buzzer;
    assign playing = r_playing;
endmodule
