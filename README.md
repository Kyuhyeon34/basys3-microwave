# FSM 기반 전자레인지 제어 시스템 RTL 설계 및 FPGA 구현

Basys3(xc7a35tcpg236-1)에서 로터리 엔코더 시간 설정, 서보 문 개폐, 턴테이블 모터 PWM, 부저 효과음을 하나의 FSM으로 묶어 상용 전자레인지 기능을 구현한 Verilog 프로젝트입니다.

`Verilog HDL` · `Vivado 2020.2` · `Basys3` · `FSM` · `PWM` · `Rotary Encoder`

## 기능 (요구사항 대응)
| # | 요구사항 | 구현 |
|---|---|---|
| 1 | 분.초 설정 (로터리 SW) | 로터리 오른쪽 = 시간 +, 왼쪽 = 시간 -, 로터리 key = 초 단위(10초) / 분 단위(1분) 전환, 최대 99:59 |
| 2-1 | 문 열고 닫을 때 소리 | 열림 : 도 미 솔 도# (상승), 닫힘 : 도# 솔 미 도 (하강) |
| 2-2 | 버튼마다 BEEP | 버튼 2kHz 80ms, 로터리 1칸 4kHz 10ms 클릭음, 시작 불가 시 1kHz 두 번 (에러음) |
| 2-3 | 종료 알림 | FND `00.00` 0.5초 ON/OFF 3회 + 도미솔도' 멜로디 3회 (깜박임과 맞춤) |
| 3 | 동작 표시 | 조리 중 circle 애니메이션 1.2초 ↔ 남은 시간 1.2초 번갈아 표시 |
| 4 | 취소 | btnR : 조리 / 일시정지 / 종료 알림 취소, 대기 중이면 시간 지움 |
| 5 | 문 열기/닫기 | 서보 모터 50Hz PWM, 닫힘 1.0ms(0도) / 열림 1.5ms(90도) |
| 6 | 모터 속도 (PWM) | 턴테이블 DC 모터 20kHz PWM, 세기 1~5 (duty 40/55/70/85/100%) |
| 7 | 추가 아이디어 | 아래 참고 |

### 추가 아이디어
- **Quick Start** : btnU 한 번 = +30초, 문이 닫혀 있으면 바로 시작 (조리 중에도 +30초)
- **조리 중 문 열면 자동 일시정지**, 문 닫고 START 하면 이어서 조리
- **문 열린 상태 / 시간 0 에서 START** → 에러음, 시작 안 함
- **서보 천천히 열고 닫기** : 20ms 프레임마다 펄스 폭을 조금씩 바꿔 1초 동안 부드럽게 이동
- **FND 메시지** : 문 열 때 `OPEN`, 세기 바꿀 때 `P--3` 1초 표시
- **일시정지 중 시간 깜박임**, LED 세기 막대, 내부 조명 LED (문 열림 / 조리 중)

## 입출력
| 입력 | 핀 | 기능 |
|---|---|---|
| btnU | T18 | +30초 / Quick Start |
| btnL | W19 | 문 열기 / 닫기 |
| btnC | U18 | 시작 / 일시정지 |
| btnR | T17 | 취소 |
| btnD | U17 | 모터 세기 1→2→3→4→5→1 |
| sw15 | R2 | reset |
| 로터리 S1 / S2 / KEY | JC2 / JC3 / JC4 | 시간 설정 / 단위 전환 (12.rotary_sw 와 같은 핀) |

| 출력 | 핀 | |
|---|---|---|
| buzzer | JC1 (K17) | 11.PWM_buzzer 와 같은 핀 |
| servo_pwm | JB1 (A14) | SG90 주황(PWM) 선. 서보 전원 5V 는 외부, GND 는 보드와 공통 |
| motor_pwm, in1_in2 | JA1, JA2, JA3 | 12.dc_motor_control 과 같은 핀 |

| LED | 의미 |
|---|---|
| 0 | 문 열림 |
| 1 / 2 / 3 | COOK / PAUSE / DONE |
| 4 | 분 단위 설정 중 |
| 5 | 부저 재생 중 |
| 6 | 서보 움직이는 중 |
| 7 | 모터 PWM |
| 8 | 내부 조명 |
| 11~15 | 세기 막대 (1~5개) |

## FSM
```
            START(문 닫힘, 시간>0) / btnU(문 닫힘)
   ┌──────┐ ─────────────────────────────────▶ ┌──────┐
   │ IDLE │                                    │ COOK │──── 남은 시간 0 ───▶ ┌──────┐
   └──────┘ ◀──────────── CANCEL ───────────── └──────┘                      │ DONE │
     ▲  ▲                                    문 열림 │ ▲ START(문 닫힘)        └──────┘
     │  │                                     START │ │ / btnU                    │
     │  │                                           ▼ │                           │
     │  │           CANCEL                     ┌───────┐                          │
     │  └───────────────────────────────────── │ PAUSE │                          │
     │                                         └───────┘                          │
     └──────────────── 3초 경과 / CANCEL / START / 문 ────────────────────────────┘
```

## 구조
```
                 ┌───────────┐  cw/ccw  ┌───────────────┐ state,time ┌──────────────┐  digits  ┌────────────────┐
 rot_s1/s2 ─────▶│ debouncer │─▶ rotary_encoder ─────▶│               │───────────▶│ display_ctrl │─────────▶│ fnd_controller │─▶ seg/an
 btn[4:0],key ──▶│  (x8)     │────────────────────────▶│ microwave_fsm │            └──────────────┘          └────────────────┘
                 └───────────┘                         │               │ snd_*  ┌──────────────┐
 tick_generator (1ms) ───────────────────────────────▶│               │───────▶│ sound_player │─▶ buzzer
                                                       │               │ door   ┌──────────────┐
                                                       │               │───────▶│  servo_ctrl  │─▶ servo_pwm
                                                       │               │ COOK,  ┌──────────────┐
                                                       │               │ level ▶│  motor_pwm   │─▶ motor_pwm, in1_in2
                                                       └───────────────┘        └──────────────┘
```

```
src/
  top_microwave.v       최상위
  btn_debounce10ms.v    2단 FF 동기화 + 디바운스              [12번 그대로]
  tick_generator.v      1kHz tick                            [12번 그대로]
  rotary_encoder.v      로터리 전이 테이블 → cw/ccw 펄스      [12번 rotary.v 참고, 양방향 누적으로 수정]
  microwave_fsm.v       IDLE / COOK / PAUSE / DONE + 시간, 문, 세기, 효과음 트리거  [신규]
  display_ctrl.v        상태별 FND 표시 (시간, 애니메이션, 깜박임, 메시지)          [신규]
  fnd_controller.v      자리 스캔, 문자(P E n -), dot, blank, circle 애니메이션     [11번 수정]
  sound_player.v        효과음 표(ROM) 재생                   [11번 PWM_buzzer 참고]
  servo_ctrl.v          서보 50Hz PWM, 천천히 이동             [신규]
  motor_pwm.v           턴테이블 모터 PWM 세기 1~5             [10번 pwm_duty_control 참고]
  tb_microwave.v        테스트벤치 (실제 1초 = 시뮬레이션 1ms)
  basys3_microwave.xdc
```

## 실행
- 프로젝트 새로 만들기 + 비트스트림 : `vivado -mode batch -source create_project.tcl`
- 프로젝트 열기 : `13.microwave.xpr`
- 보드에 바로 올리기 : `bitstream/top_microwave.bit`

## 테스트벤치 결과
40개 check 모두 ok → `PASS microwave`
(초기 상태, 에러음, 로터리 초/분 설정과 0 아래 제한, 문 열기 + 서보 천천히 이동, OPEN 표시,
 조리 시작 / 애니메이션 / 1초 감소, PWM duty 70%, 세기 변경 P--4, 조리 중 문 열림 → 일시정지,
 +30초, 취소, Quick Start, 종료 깜박임 3회 + 3초 후 IDLE, 종료 알림 중 취소)

## 합성 / 구현 결과
LUT 725, FF 381, WNS +1.730 ns, WHS +0.178 ns, 합성 Warning 0 (`reports/`)

## 하드웨어 주의
- 로터리가 한 칸에 2번만 전이되는 모델이면 `rotary_encoder` 의 `STEPS_PER_DETENT` 를 2로 바꾼다.
- 서보는 FPGA 3.3V 로 전원을 주지 말 것 (외부 5V, GND 공통). PWM 신호선만 JB1 에 연결.
- 서보 각도가 안 맞으면 `servo_ctrl` 의 `CLOSE_US` / `OPEN_US` 를 조정 (SG90 은 0.5~2.5ms 범위인 제품도 있음).
