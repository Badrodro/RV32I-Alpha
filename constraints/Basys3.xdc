## RV32I-Alpha pin constraints for the Digilent Basys 3 (xc7a35tcpg236-1)
## clk     -> 100 MHz oscillator
## reset   -> centre push button (BTNC)
## trap    -> LED 15, lights up when the program reaches ebreak/ecall
## testOUT -> write-back bus on the four Pmod headers (JA = bits 7:0, JB = 15:8, JC = 23:16, JXADC = 31:24)

## Clock
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Reset (BTNC)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports reset]

## Trap (LD15)
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports trap]

## testOUT[7:0] on Pmod JA
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports {testOUT[0]}]
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[1]}]
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[2]}]
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[3]}]
set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33 } [get_ports {testOUT[4]}]
set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[5]}]
set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[6]}]
set_property -dict { PACKAGE_PIN G3   IOSTANDARD LVCMOS33 } [get_ports {testOUT[7]}]

## testOUT[15:8] on Pmod JB
set_property -dict { PACKAGE_PIN A14  IOSTANDARD LVCMOS33 } [get_ports {testOUT[8]}]
set_property -dict { PACKAGE_PIN A16  IOSTANDARD LVCMOS33 } [get_ports {testOUT[9]}]
set_property -dict { PACKAGE_PIN B15  IOSTANDARD LVCMOS33 } [get_ports {testOUT[10]}]
set_property -dict { PACKAGE_PIN B16  IOSTANDARD LVCMOS33 } [get_ports {testOUT[11]}]
set_property -dict { PACKAGE_PIN A15  IOSTANDARD LVCMOS33 } [get_ports {testOUT[12]}]
set_property -dict { PACKAGE_PIN A17  IOSTANDARD LVCMOS33 } [get_ports {testOUT[13]}]
set_property -dict { PACKAGE_PIN C15  IOSTANDARD LVCMOS33 } [get_ports {testOUT[14]}]
set_property -dict { PACKAGE_PIN C16  IOSTANDARD LVCMOS33 } [get_ports {testOUT[15]}]

## testOUT[23:16] on Pmod JC
set_property -dict { PACKAGE_PIN K17  IOSTANDARD LVCMOS33 } [get_ports {testOUT[16]}]
set_property -dict { PACKAGE_PIN M18  IOSTANDARD LVCMOS33 } [get_ports {testOUT[17]}]
set_property -dict { PACKAGE_PIN N17  IOSTANDARD LVCMOS33 } [get_ports {testOUT[18]}]
set_property -dict { PACKAGE_PIN P18  IOSTANDARD LVCMOS33 } [get_ports {testOUT[19]}]
set_property -dict { PACKAGE_PIN L17  IOSTANDARD LVCMOS33 } [get_ports {testOUT[20]}]
set_property -dict { PACKAGE_PIN M19  IOSTANDARD LVCMOS33 } [get_ports {testOUT[21]}]
set_property -dict { PACKAGE_PIN P17  IOSTANDARD LVCMOS33 } [get_ports {testOUT[22]}]
set_property -dict { PACKAGE_PIN R18  IOSTANDARD LVCMOS33 } [get_ports {testOUT[23]}]

## testOUT[31:24] on Pmod JXADC (used as digital I/O)
set_property -dict { PACKAGE_PIN J3   IOSTANDARD LVCMOS33 } [get_ports {testOUT[24]}]
set_property -dict { PACKAGE_PIN L3   IOSTANDARD LVCMOS33 } [get_ports {testOUT[25]}]
set_property -dict { PACKAGE_PIN M2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[26]}]
set_property -dict { PACKAGE_PIN N2   IOSTANDARD LVCMOS33 } [get_ports {testOUT[27]}]
set_property -dict { PACKAGE_PIN K3   IOSTANDARD LVCMOS33 } [get_ports {testOUT[28]}]
set_property -dict { PACKAGE_PIN M3   IOSTANDARD LVCMOS33 } [get_ports {testOUT[29]}]
set_property -dict { PACKAGE_PIN M1   IOSTANDARD LVCMOS33 } [get_ports {testOUT[30]}]
set_property -dict { PACKAGE_PIN N1   IOSTANDARD LVCMOS33 } [get_ports {testOUT[31]}]

## Bitstream configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
