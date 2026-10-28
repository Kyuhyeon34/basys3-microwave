## Basys3 - 전자레인지 (top_microwave)

## Clock 100MHz
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## reset : sw15
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports reset]

## Buttons
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]   ;# btnU : +30초
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports {btn[1]}]   ;# btnL : 문
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports {btn[2]}]   ;# btnC : 시작/일시정지
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports {btn[3]}]   ;# btnR : 취소
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports {btn[4]}]   ;# btnD : 모터 세기

## LEDs
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {led[10]}]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {led[13]}]
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

## 7 segment
set_property -dict { PACKAGE_PIN W7   IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN W6   IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN V8   IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN U5   IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]
set_property -dict { PACKAGE_PIN V7   IOSTANDARD LVCMOS33 } [get_ports {seg[7]}]
set_property -dict { PACKAGE_PIN U2   IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN W4   IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## Pmod JA : DC 모터 드라이버 (12.dc_motor_control 과 같은 핀)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports motor_pwm]     ;# JA1
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports {in1_in2[0]}]  ;# JA2
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports {in1_in2[1]}]  ;# JA3

## Pmod JB : 서보 모터 PWM
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports servo_pwm]     ;# JB1

## Pmod JC : 부저 + 로터리 (11.PWM_buzzer, 12.rotary_sw 와 같은 핀)
set_property -dict { PACKAGE_PIN K17  IOSTANDARD LVCMOS33 } [get_ports buzzer]        ;# JC1
set_property -dict { PACKAGE_PIN M18  IOSTANDARD LVCMOS33 } [get_ports rot_s1]        ;# JC2
set_property -dict { PACKAGE_PIN N17  IOSTANDARD LVCMOS33 } [get_ports rot_s2]        ;# JC3
set_property -dict { PACKAGE_PIN P18  IOSTANDARD LVCMOS33 } [get_ports rot_key]       ;# JC4

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
