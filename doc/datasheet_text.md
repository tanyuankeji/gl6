=== Page 1 ===
TAS6424E-Q1 具有负载突降保护和 I2C 诊断功能的 45W、2MHz 数字输入 4 通道
汽车用 D 类音频放大器
1 特性
•
符合面向汽车应用的 AEC-Q100 标准
– 温度等级 1：–40°C 至 +125°C TA
•
高级负载诊断
– 直流诊断功能，无需输入时钟即可执行
– 交流诊断功能，可通过阻抗和相位响应实现高频
扬声器检测
•
可轻松满足 CISPR25-L5 EMC 规范
•
音频输入
– 4 通道 I2S 或 4/8 通道 TDM 输入
– 输入采样率：44.1kHz、48kHz、96kHz
– 输入格式：16 位至 32 位 I2S 和 TDM
– 支持高分辨率音频系统
•
音频输出
– 四通道桥接式负载 (BTL)
– 双通道并行 BTL (PBTL)
– 最高可达 2.1MHz 的输出开关频率
– 在 2Ω 负载、14.4V BTL 条件下，输出功率为 
45W，THD 为 10%
– 在 4Ω 负载、25V BTL 条件下，输出功率为 
75W，THD 为 10%
– 在 2Ω 负载、25V PBTL 条件下，输出功率为 
150W，THD 为 10%
•
在 4Ω 负载、14.4V BTL 条件下的音频性能
– 输出功率为 1W 时，THD+N < 0.009%
– 30µVRMS 输出噪声
– -97dB 串扰
•
负载诊断功能
– 开路负载、短路负载、电池短路、接地短路
– 线路输出检测高达 6kΩ
•
保护
– 输出电流限制和短路保护
– 40V 负载突降
– 可承受接地开路和电源开路
– 直流失调电压
– 过热、欠压和过压
•
常规运行
– 4.5V 至 26.4V 的电源电压
– I2C 控制，具有 4 个地址选项
– 锁存或非锁存削波检测
– 增强的 EMI 管理
2 应用
•
汽车音响主机
•
汽车外部放大器
3 说明
TAS6424E-Q1 器件是一款采用 2.1MHz PWM 开关频
率的四通道数字输入 D 类音频放大器，以非常小的 
PCB 尺寸实现成本优化的解决方案，可针对启停事件
在低至 4.5V 的电压下全面运行，并可在高达 40kHz 的
音频带宽下提供出色的音质。
输出开关频率既可以设置为高于调幅 (AM) 频带，以消
除 AM 频带干扰并降低输出滤波需求及成本；也可以
设置为低于 AM 频带，以优化器件效率。
该器件具有内置负载诊断功能，用于检测和诊断误接的
输出，以及检测交流耦合的高频扬声器，以帮助缩短制
造过程中的测试时间。
器件增加了 EMI 管理特性（包括展频、输出相位偏移
和优化的压摆率），以帮助应对系统级 EMI 挑战。
TAS6424E-Q1 D 类音频放大器专为汽车音响主机和外
部放大器模块而设计。有关引脚兼容的单通道、双通道
及四通道器件，请参阅器件选项表。
器件信息
器件型号
封装(1)
封装尺寸（标称值）
TAS6424E-Q1
HSSOP (56)
18.41mm × 7.49mm
(1)
如需了解所有可用封装，请参阅数据表末尾的可订购产品附
录。
25-W 4-channel
5.9 cm2
27 mm
22 mm 
PCB 区域
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
本文档旨在为方便起见，提供有关 TI 产品中文版本的信息，以确认产品的概要。有关适用的官方英文版本的最新信息，请访问 
www.ti.com，其内容始终优先。TI 不保证翻译的准确性和有效性。在实际设计之前，请务必参考最新版本的英文版本。
English Data Sheet: SLOSE73

=== Page 2 ===
Table of Contents
1 特性................................................................................... 1
2 应用................................................................................... 1
3 说明................................................................................... 1
4 Revision History.............................................................. 2
5 Device Options................................................................ 3
6 Pin Configuration and Functions...................................4
7 Specifications.................................................................. 6
7.1 Absolute Maximum Ratings........................................ 6
7.2 Recommended Operating Conditions.........................6
7.3 ESD Ratings............................................................... 6
7.4 Thermal Information....................................................7
7.5 Electrical Characteristics.............................................8
7.6 Typical Characteristics: Bridge-Tied Load (BTL).......12
7.7 Typical Characteristics: Bridge-Tied Load (BTL, 
384 kHz)......................................................................15
7.8 Typical Characteristics: Parallel Bridge-Tied 
(PBTL).........................................................................17
7.9 Typical Characteristics: Parallel Bridge-Tied 
Load (PBTL, 384 kHz).................................................19
8 Parameter Measurement Information..........................21
9 Detailed Description......................................................22
9.1 Overview...................................................................22
9.2 Functional Block Diagram.........................................22
9.3 Feature Description...................................................23
9.4 Device Functional Modes..........................................37
9.5 Programming............................................................ 38
9.6 Register Maps...........................................................41
10 Application and Implementation................................64
10.1 Application Information........................................... 64
10.2 Typical Application.................................................. 66
11 Power Supply Recommendations..............................70
12 Layout...........................................................................71
12.1 Layout Guidelines................................................... 71
12.2 Layout Example...................................................... 72
12.3 Thermal Considerations..........................................72
13 Device and Documentation Support..........................74
13.1 Documentation Support.......................................... 74
13.2 接收文档更新通知................................................... 74
13.3 支持资源..................................................................74
13.4 Trademarks.............................................................74
13.5 Electrostatic Discharge Caution..............................74
13.6 术语表..................................................................... 74
14 Mechanical, Packaging, and Orderable 
Information.................................................................... 74
4 Revision History
注：以前版本的页码可能与当前版本的页码不同
Changes from Revision * (June 2021) to Revision A (November 2021)
Page
•
将文件从预告信息 更改为量产数据 ....................................................................................................................1
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
2
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 3 ===
5 Device Options
Part Number
Channel 
Count
Power-Supply 
Voltage Range
Channel 
Current 
Limit (Typ)
Non-Latching 
Clip Detect 
WARN Pin(1)
Output Power per channel / 10% THD
4 Ω / BTL
14.4 V
4 Ω / BTL
Max Voltage
2 Ω / BTL
14.4 V
2 Ω / PBTL
Max Voltage
TAS6424-Q1
4
4.5 V to 26.4 V
6.5 A
N
27 W
75 W at 25 V
45 W
150 W at 25 V
TAS6424M-Q1
4
4.5 V to 18 V
6.5 A
N
27 W
45 W at 18 V
45 W
80 W at 18 V
TAS6424L-Q1
4
4.5 V to 18 V
4.8 A
N
27 W
45 W at 18 V
27 W
80 W at 18 V
TAS6421-Q1
1
4.5 V to 26.4 V
6.5 A
Y
27 W
75 W at 25 V
45 W
N/A
TAS6424MS-Q1
4
4.5 V to 18 V
6.5 A
Y
27 W
45 W at 18 V
45 W
80 W at 18 V
TAS6424E-Q1
4
4.5 V to 26.4 V
7.2 A
Y
27 W
75 W at 25 V
45 W
150 W at 25 V
TAS6422E-Q1
2
4.5 V to 26.4 V
6.5 A
Y
27 W
75 W at 25 V
45 W
150 W at 25 V
(1)
Register configurable function. N = Latched clip detect only. Y = Supports both latched and non-latched clip detect.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
3
Product Folder Links: TAS6424E-Q1

=== Page 4 ===
6 Pin Configuration and Functions
1
GND
56
 PVDD
2
PVDD
55
 PVDD
3
VBAT
54
 BST_4P
4
AREF
53
 OUT_4P
5
VREG
52
 GND
6
VCOM
51
 OUT_4M
7
AVSS
50
 BST_4M
8
AVDD
49
 GND
9
GVDD
48
 BST_3P
10
GVDD
47
 OUT_3P
11
GND
46
 GND
12
MCLK
45
 OUT_3M
13
SCLK
44
 BST_3M
14
FSYNC
43
 PVDD
15
SDIN1
42
 PVDD
16
SDIN2
41
 BST_2P
17
GND
40
 OUT_2P
18
GND
39
 GND
19
VDD
38
 OUT_2M
20
SCL
37
 BST_2M
21
SDA
36
 GND
22
I2C_ADDR0
35
 BST_1P
23
I2C_ADDR1
34
 OUT_1P
24
STANDBY
33
 GND
25
MUTE
32
 OUT_1M
26
FAULT
31
 BST_1M
27
WARN
30
 PVDD
28
GND
29
 PVDD
Not to scale
Thermal
Pad
图 6-1. DKQ Package, 56-Pin HSSOP With Exposed Thermal Pad, Top View
表 6-1. Pin Functions
PIN
TYPE(1)
DESCRIPTION
NAME
NO.
AREF
4
PWR
VREG and VCOM bypass capacitor return
AVDD
8
PWR
Voltage regulator bypass. Connect 1 µF capacitor from AVDD to AVSS
AVSS
7
PWR
AVDD bypass capacitor return
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
4
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 5 ===
表 6-1. Pin Functions (continued)
PIN
TYPE(1)
DESCRIPTION
NAME
NO.
BST_1M
31
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_1P
35
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_2M
37
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_2P
41
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_3M
44
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_3P
48
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_4M
50
PWR
Bootstrap capacitor connection pins for high-side gate driver
BST_4P
54
PWR
Bootstrap capacitor connection pins for high-side gate driver
FAULT
26
DO
Reports a fault (active low, open drain), 100-kΩ internal pull-up resistor
FSYNC
14
DI
Audio frame clock input
GND
1, 11, 17, 18, 
28, 33, 36, 39, 
46, 49, 52
GND
Ground
GVDD
9
PWR
Gate drive voltage regulator derived from VBAT input pin. Connect 2.2 µF capacitor to GND
10
Gate drive voltage regulator derived from VBAT input pin. Connect 2.2 µF capacitor to GND
I2C_ADDR0
22
DI
I2C address pins. Refer to 图 9-8
I2C_ADDR1
23
MCLK
12
DI
Audio master clock input
MUTE
25
DI
Mutes the device outputs (active low) while keeping output FETs switching at 50%, 100-kΩ 
internal pull-down resistor
OUT_1M
32
NO
Negative output for the channel
OUT_1P
34
PO
Positive output for the channel
OUT_2M
38
NO
Negative output for the channel
OUT_2P
40
PO
Positive output for the channel
OUT_3M
45
NO
Negative output for the channel
OUT_3P
47
PO
Positive output for the channel
OUT_4M
51
NO
Negative output for the channel
OUT_4P
53
PO
Positive output for the channel
PVDD
2, 29, 30, 42, 
43, 55, 56
PWR
PVDD voltage input (can be connected to battery). Bulk capacitor and bypass capacitor 
required
SCL
20
DI
I2C clock input
SCLK
13
DI
Audio bit and serial clock input
SDA
21
DI/O
I2C data input and output
SDIN1
15
DI
TDM data input and audio I2S data input for channels 1 and 2
SDIN2
16
DI
Audio I2S data input for channels 3 and 4
STANDBY
24
DI
Enables low power standby state (active Low), 100-kΩ internal pull-down resistor
VBAT
3
PWR
Battery voltage input
VCOM
6
PWR
Bias voltage
VDD
19
PWR
3.3-V external supply voltage
VREG
5
PWR
Voltage regulator bypass
WARN
27
DO
Clip and overtemperature warning (active low, open drain), 100-kΩ internal pull-up resistor
Thermal Pad
—
GND
Provides both electrical and thermal connection for the device. Heatsink must be connected to 
GND.
(1)
GND = ground, PWR = power, PO = positive output, NO = negative output, DI = digital input, DO = digital output, DI/O = digital input 
and output, NC = no connection
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
5
Product Folder Links: TAS6424E-Q1

=== Page 6 ===
7 Specifications
7.1 Absolute Maximum Ratings
over operating free-air temperature range (unless otherwise noted)(1)
MIN
MAX
UNIT
PVDD, VBAT
DC supply voltage relative to GND
-0.3
30
V
VMAX
Transient supply 
voltage: PVDD, 
VBAT
t ≤ 400 ms exposure
-1
40
V
VRAMP
Supply-voltage ramp rate: PVDD, VBAT
75
V/ms
VDD
DC supply voltage relative to GND
-0.3
3.5
V
IMAX
Maximum current per pin (PVDD, VBAT, OUT_xP, OUT_xM, GND)
±8
A
IMAX_PULSED
Pulsed supply 
current per PVDD 
pin (one shot)
t < 100 ms
±12
A
VLOGIC
Input voltage for logic pins (SCL, SDA, SDIN1, SDIN2, MCLK, 
BCLK, LRCLK, MUTE,/STANDBY, I2C_ADDRx)
-0.3
VDD + 0.5
A
VGND
Maximum voltage between GND pins
-0.3
0.3
V
TJ
Maximum operating junction temperature
-55
150
°C
Tstg
Storage temperature
-55
150
°C
(1)
Stresses beyond those listed under Absolute Maximum Ratings may cause permanent damage to the device. These are stress ratings 
only, which do not imply functional operation of the device at these or any other conditions beyond those indicated under 
Recommended Operating Conditions. Exposure to absolute-maximum-rated conditions for extended periods may affect device 
reliability.
7.2 Recommended Operating Conditions
MIN
TYP
MAX
UNIT
PVDD
Output FET Supply Voltage Range
Relative to GND
4.5
26.4
V
VBAT
Battery Supply Voltage Input
Relative to GND
4.5
14.4
18
VDD
DC Logic supply
Relative to GND
3.0
3.3
3.5
TA
Ambient temperature
–40
125
°C
TJ
Junction temperature
An adequate thermal design is 
required
–40
150
RL
Minimum speaker load impedance
BTL Mode
2
4
Ω
PBTL Mode
1
2
RPU_I2C
I2C pullup resistance on SDA and SCL pins
1
4.7
10
kΩ
CBypass
External capacitance on bypass pins
Pin 2, 3, 5, 6, 8, 19
1
µF
CGVDD
External capacitance on GVDD pins
Pin 9, 10
2.2
µF
COUT
External capacitance to GND on OUT pins
Limit set by DC-diagnostic timing
1
3.3
µF
LO
Output filter inductance
Minimum inductance at ISD current
levels
1
µH
7.3 ESD Ratings
VALUE
UNIT
V(ESD)
Electrostatic discharge
Human-body model (HBM), per AEC Q100-002(1)
±3000
V
Charged-device model (CDM), per AEC 
Q100-011
All pins
±500
Corner pins (1, 22, 23 and 44)
±750
(1)
AEC Q100-002 indicates that HBM stressing shall be in accordancewith the ANSI/ESDA/JEDEC JS-001 specification.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
6
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 7 ===
7.4 Thermal Information
THERMAL METRIC(1)
TAS6424E-Q1(2)
DKQ(HSSOP)
56 PINS
RθJA 
Junction-to-ambient thermal resistance
37.3
RθJC(top)
Junction-to-case (top) thermal resistance
0.4
RθJB
Junction-to-board thermal resistance
15.2
ΨJT
Junction-to-top characterization parameter
0.2
ΨJB
Junction-to-board characterization parameter
14.7
RθJC(bot)
Junction-to-case (bottom) thermal resistance
-
(1)
For more information about traditional and new thermal metrics, see the Semiconductor and IC Package Thermal Metrics application 
report, SPRA953.
(2)
JEDEC standard 4 layer PCB.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
7
Product Folder Links: TAS6424E-Q1

=== Page 8 ===
7.5 Electrical Characteristics
Test conditions (unless otherwise noted): TC = 25°C, PVDD = VBAT = 14.4 V, VDD = 3.3 V, RL = 4 Ω, POUT = 1 W/ch, f = 
1kHz, fSW = 2.11 MHz, AES17 Filter, default I2C settings, LC filter: 3.3 uH - DFEG7030D-3R3M.   See the Typical Application 
section for additional hardware information.
PARAMETER
TEST CONDITIONS
MIN
TYP
MAX
UNIT
OPERATING CURRENT
IPVDD_IDLE
PVDD idle current
All channels playing, no audio input
45
90
mA
IVBAT_IDLE
VBAT idle current
All channels playing, no audio input
90
100
mA
IPVDD_STBY
PVDD standby current
STANDBYActive, VDD = 0 V
0.5
1
µA
IVBAT_STBY
VBAT standby current
STANDBYActive, VDD = 0 V
4
6
µA
IVDD
VDD supply current
All channels playing, –60-dB signal
15
18
mA
OUTPUT POWER
PO_BTL
Output power per channel, BTL
4 Ω, PVDD = 14.4 V, THD+N = 1%, TC = 
75°C
20
22
W
4 Ω, PVDD = 14.4 V, THD+N = 10%, TC = 
75°C
25
27
2 Ω, PVDD = 14.4 V, THD+N = 1%, TC = 
75°C
38
40
2 Ω, PVDD = 14.4 V, THD+N = 10%, TC = 
75°C
42
47
4 Ω, PVDD = 25 V, THD+N = 1%, TC = 
75°C
50
57
4 Ω, PVDD = 25 V, THD+N = 10%, TC = 
75°C
70
75
PO_PBTL
Output power per channel in 
parallel mode, PBTL
2 Ω, PVDD = 14.4 V, THD+N = 1%, TC = 
75°C
35
42
W
2 Ω, PVDD = 14.4 V, THD+N = 10%, TC = 
75°C
45
53
2 Ω, PVDD = 25 V, THD+N = 1%, TC = 
75°C
98
120
2 Ω, PVDD = 25 V, THD+N = 10%, TC = 
75°C
138
150
EFFP
Power efficiency
4 channels operating, 25-W output 
power/ch 4 Ω load, PVDD = 14.4 V, TC = 
25°C
86%
AUDIO PERFORMANCE
Vn
Output noise voltage
Zero input, A-weighting, gain level 1, PVDD 
= 14.4 V
30
µV
Zero input, A-weighting, gain level 2, PVDD 
= 14.4 V
45
Zero input, A-weighting, gain level 3, PVDD 
= 25 V
54
Zero input, A-weighting, gain level 4, PVDD 
= 25 V
70
GAIN
Peak Output Voltage/dBFS
gain level 1, Register 0x01, bit 1-0 = 00
7.5
V/FS
gain level 2, Register 0x01, bit 1-0 = 01
15
gain level 3, Register 0x01, bit 1-0 = 10
21
gain level 4, Register 0x01, bit 1-0 = 11
29
Crosstalk
Channel crosstalk
PVDD = 14.4 Vdc + 1 VRMS, f = 1 kHz
-97
dB
PSRR
Power-supply rejection ratio
PVDD = 14.4 Vdc + 1 VRMS, f = 1 kHz
-80
dB
THD+N
Total harmonic distortion + noise
0.009%
GVAR
Gain Variation
All gain levels
-0.5
0
0.5
dB
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
8
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 9 ===
Test conditions (unless otherwise noted): TC = 25°C, PVDD = VBAT = 14.4 V, VDD = 3.3 V, RL = 4 Ω, POUT = 1 W/ch, f = 
1kHz, fSW = 2.11 MHz, AES17 Filter, default I2C settings, LC filter: 3.3 uH - DFEG7030D-3R3M.   See the Typical Application 
section for additional hardware information.
PARAMETER
TEST CONDITIONS
MIN
TYP
MAX
UNIT
GCH
Channel-to-channel gain 
variation
-0.5
0
0.5
dB
LINE OUTPUT PERFROMANCE
Vn_LINEOUT
LINE output noise voltage
Zero input, A-weighting, channel set to 
LINE MODE
30
µV
VO_LINEOUT
LINE output voltage
0dB input, channel set to LINE MODE
5.5
VRMS
THD+N
Line output total harmonic 
distortion + noise
VO = 2 VRMS , channel set to LINE MODE
0.005%
DIGITAL INPUT PINS
VIH
Input logic level high
70
%VDD
VIL
Input logic level low
30
%VDD
IIH
Input logic current, high
VI = VDD
15
µA
IIL
Input logic current, low
VI = 0
-15
µA
PWM OUTPUT STAGE
FSW_SSΔ
PWM Spread-Spectrum 
Frequency Variation
8%
RDS(on)
FET drain-to-source resistance
Not including bond wire and package 
resistance
90
mΩ
OVER VOLTAGE (OV) PROTECTION
VPVDD_OV
PVDD overvoltage shutdown
27.0
27.8
28.8
V
VPVDD_OV_HYS
PVDD overvoltage shutdown 
hysteresis
0.8
V
VVBAT_OV
VBAT overvoltage shutdown
20
21.5
23
V
VVBAT_OV_HYS
VBAT overvoltage shutdown 
hysteresis
0.4
V
UNDER VOLTAGE (UV) PROTECTION
VBATUV
VBAT undervoltage shutdown
4
4.5
V
VBATUV_HYS
VBAT undervoltage shutdown 
hysteresis
0.2
V
PVDDUV
PVDD undervoltage shutdown
4
4.5
V
PVDDUV_HYS
PVDD undervoltage shutdown 
hysteresis
0.2
V
BYPASS VOLTAGES
VGVDD
Gate drive bypass pin voltage
7
V
VAVDD
Analog bypass pin voltage
6
V
VVCOM
Common bypass pin voltage
2.5
V
VVREG
Regulator bypass pin voltage
5.5
V
POWER-ON RESET(POR)
VPOR
VDD voltage for POR
1.7
2.7
V
VPOR_HY
VDD POR recovery hysteresis 
voltage
0.5
V
OVER TEMPERATURE (OT) PROTECTION
OTW(i)
Channel overtemperature 
warning
150
°C
OTSD(i)
Channel overtemperature 
shutdown
175
°C
OTW
Global junction overtemperature 
warning
130
°C
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
9
Product Folder Links: TAS6424E-Q1

=== Page 10 ===
Test conditions (unless otherwise noted): TC = 25°C, PVDD = VBAT = 14.4 V, VDD = 3.3 V, RL = 4 Ω, POUT = 1 W/ch, f = 
1kHz, fSW = 2.11 MHz, AES17 Filter, default I2C settings, LC filter: 3.3 uH - DFEG7030D-3R3M.   See the Typical Application 
section for additional hardware information.
PARAMETER
TEST CONDITIONS
MIN
TYP
MAX
UNIT
OTSD
Global junction overtemperature 
shutdown
160
°C
OTHYS
Overtemperature hysteresis
15
°C
LOAD OVER CURRENT PROTECTION
ILIM
Overcurrent cycle-by-cycle limit
OC Level 1
4.0
4.8
A
OC Level 2
6.5
7.2
A
ISD
Overcurrent shutdown
OC Level 1, Any short to supply, ground, or 
other channels
7
A
OC Level 2, Any short to supply, ground, or 
other channels
9
A
MUTE MODE
GMUTE
Output attenuation
100
dB
CLICK AND POP
VCP
Output click and pop voltage
ITU-R 2k filter, High-Z/MUTE to Play, Play 
to Mute/High-Z
7
mV
DC OFFSET
VOFFSET
Output offset voltage
2
5
mV
DC DETECT
DCFAULT
Output DC fault protection
2
2.5
V
DIGITAL OUTPUT PINS
VOH
Output voltage for logic level 
high
I = ±2 mA
90
%VDD
VOL
Output voltage for logic level low I = ±2 mA
10
%VDD
tDELAY_CLIPDET
Signal delay when output 
clipping detected
20
µs
LOAD DIAGNOSTICS
S2P
Maximum resistance to detect a 
short from OUT pin(s) to PVDD
500
Ω
S2G
Maximum resistance to detect a 
short from OUT pin(s) to ground
200
Ω
SL
Shorted load detection tolerance Other channels in Hi-Z
±0.5
Ω
OL
Open load
Other channels in Hi-Z
40
70
Ω
TDC_DIAG
DC diagnostic time
All 4 Channels
230
ms
LO
Line output
6
kΩ
TLINE_DIAG
Line output diagnostic time
40
ms
ACIMP
AC impedance accuracy
Offset
±0.5
Ω
Gain linearity, ƒ = 19 kHz, RL = 2 Ω to 16 
Ω
0.25
Ω
TAC_DIAG
AC diagnostic time
All 4 Channels
520
ms
I2C_ADDR PINS
tI2C_ADDR
Time delay needed for I2C 
address set-up
300
µs
I2C CONTROL PORT
tBUS
Bus free time between start and 
stop conditions
1.3
µs
tHOLD1
Hold time, SCL to SDA
0
ns
tHOLD2
Hold time, start condition to SCL
0.6
µs
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
10
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 11 ===
Test conditions (unless otherwise noted): TC = 25°C, PVDD = VBAT = 14.4 V, VDD = 3.3 V, RL = 4 Ω, POUT = 1 W/ch, f = 
1kHz, fSW = 2.11 MHz, AES17 Filter, default I2C settings, LC filter: 3.3 uH - DFEG7030D-3R3M.   See the Typical Application 
section for additional hardware information.
PARAMETER
TEST CONDITIONS
MIN
TYP
MAX
UNIT
tSTART
I2C startup time after VDD 
power on reset
12
ms
tRISE
Rise time, SCL and SDA
300
ns
tFALL
Fall time, SCL and SDA
300
ns
tSU1
Setup, SDA to SCL
100
ns
tSU2
Setup, SCL to start condition
0.6
µs
tSU3
Setup, SCL to stop condition
0.6
µs
tW(H)
Required pulse duration SCL 
high
0.6
µs
tW(L)
Required pulse duration SCL 
low
1.3
µs
SERIAL AUDIO PORT
MCLKDC, 
SCLKDC
Allowable input clock duty cycle
0.45
0.5
0.55
fMCLK
Supported MCLK frequencies
128, 256, or 512
128
512
xFS
fMCLK_Max
Maximum frequency
25
MHz
tSCY
SCLK pulse cycle time
40
ns
tSCL
SCLK pulse-with LOW
16
ns
tSCH
SCLK pulse-with HIGH
16
ns
tRISE/FALL
Rise and fall time
<5
ns
tSF
Required FSYNC to SCLK rising 
edge
8
ns
tFS
FSYNC rising edge to SCLK 
edge
8
ns
tDS
DATA set-up time
8
ns
tDH
DATA hold time
8
ns
th
Required SDIN hold time after 
SCLK rising edge
15
ns
tsu
Required SDIN setup time 
before SCLK rising edge
15
ns
ci
Input capacitance, pins MCLK, 
SCLK, FSYNC, SDIN1, SDIN2
10
pf
TLA
Latency from input to output 
measured in FSYNC sample 
count
FSYNC = 44.1 kHz or 48 kHz
30
FSYNC = 96 kHz
12
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
11
Product Folder Links: TAS6424E-Q1

=== Page 12 ===
7.6 Typical Characteristics: Bridge-Tied Load (BTL)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 2.1 MHz, Output Configuration: 
BTL, AES17 filter, default I2C settings, LC filter: 3.3 μH - DFEG7030D-3R3M. See 图 10-2 (unless otherwise noted).
Output Power(W)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
10m
100m
1
10
50
2 : Load
4 : Load
PVDD = 14.4 V
BTL
图 7-1. THD+N vs Power - 14.4V
Output Power(W)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
10m
100m
1
10
50 100
2 : Load
4 : Load
PVDD = 25 V
BTL
图 7-2. THD+N vs Power - 24V
Frequency (Hz)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
20
100
1k
10k
20k
2 : Load
4 : Load
PVDD = 14.4 V
PO = 1 W
BTL
图 7-3. THD+N vs Frequency - 14.4 V
Frequency (Hz)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
20
100
1k
10k
20k
2 : Load
4 : Load
PVDD = 25 V
PO = 1 W
BTL
图 7-4. THD+N vs Frequency - 24 V
Supply Voltage (V)
Output Power (W)
5
7.5
10
12.5
15
17.5
20
22.5
25
27.5
0
5
10
15
20
25
30
35
40
45
50
55
60
65
70
2 1% THD+N
2 10% THD+N
4 1% THD+N
4 10% THD+N
TC = 75 °C
BTL
图 7-5. Output Power vs Supply Voltage
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0
20
40
60
80
100
120
PVDD (Device Only)
PVDD + VBAT (Device Only)
PVDD + VBAT (Device + LC)
4 Ω
TC = 75 °C
BTL
图 7-6. Efficiency vs Output Power - 14.4 V - 4 Ω
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
12
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 13 ===
7.6 Typical Characteristics: Bridge-Tied Load (BTL) (continued)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 2.1 MHz, Output Configuration: 
BTL, AES17 filter, default I2C settings, LC filter: 3.3 μH - DFEG7030D-3R3M. See 图 10-2 (unless otherwise noted).
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0.1
0.5
1
5
10
50 100 200
0.01
PVDD (Device Only)
PVDD + VBAT (Device Only)
PVDD + VBAT (Device + LC)
4 Ω
TC = 75 °C
BTL
图 7-7. Efficiency vs Ouptut Power - 14.4 V - 4 Ω (Zoomed)
Output Power (W)
Power Dissipation (W)
0
10
20
30
40
50
60
70
80
90
100
110
0
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
PVDD (Device only)
PVDD+VBAT (Device only)
PVDD+VBAT (Device + LC)
4 Ω
TC = 75 °C
BTL
图 7-8. Power Dissipation vs Output Power - 14.4 V - 4 Ω
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0
20
40
60
80
100
120
140
160
180
200
PVDD (Device Only)
PVDD + VBAT (Device Only)
PVDD + VBAT (Device + LC)
2 Ω
TC = 75 °C
BTL
图 7-9. Efficiency vs Output Power - 14.4 V - 2 Ω
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0.1
0.5
1
5
10
50 100 200
0.01
PVDD (Device Only)
PVDD + VBAT (Device Only)
PVDD + VBAT (Device + LC)
2 Ω
TC = 75 °C
BTL
图 7-10. Efficiency vs Output Power - 14.4 V - 2 Ω (Zoomed)
Output Power (W)
Power Dissipation (W)
0
20
40
60
80
100
120
140
160
180
200
0
5
10
15
20
25
30
35
40
45
50
0
20
40
60
80
100
120
140
160
180
PVDD (Device only)
PVDD+VBAT (Device only)
PVDD+VBAT (Device + LC)
2 Ω
TC = 75 °C
BTL
图 7-11. Power Dissipation vs Output Power - 14.4 V - 2 Ω
Supply Voltage (V)
Idle Current (mA)
4
6
8
10
12
14
16
18
20
22
24
26
0
10
20
30
40
50
60
70
80
90
100
BTL
图 7-12. PVDD Idle Current vs Supply Voltage
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
13
Product Folder Links: TAS6424E-Q1

=== Page 14 ===
7.6 Typical Characteristics: Bridge-Tied Load (BTL) (continued)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 2.1 MHz, Output Configuration: 
BTL, AES17 filter, default I2C settings, LC filter: 3.3 μH - DFEG7030D-3R3M. See 图 10-2 (unless otherwise noted).
Supply Voltage (V)
Idle Current (mA)
4
6
8
10
12
14
16
18
20
22
24
26
0
10
20
30
40
50
60
70
80
90
100
110
120
130
140
BTL
图 7-13. VBAT Idle Current vs Supply Voltage
Supply Voltage (V)
Noise (PVRMS)
4
6
8
10
12
14
16
18
20
22
24
26
0
10
20
30
40
50
60
70
80
90
100
110
120
130
140
Gain Level 1
Gain Level 2
Gain Level 3
Gain Level 4
BTL
图 7-14. Noise vs Supply Voltage
Frequency(Hz)
Crosstalk (dB)
-120
-100
-80
-60
-40
-20
0
20
100
1k
10k
20k
CH 1 to CH 2
CH 1 to CH 3
CH 1 to CH 4
BTL
图 7-15. Crosstalk vs Frequency
Frequency (Hz)
PSRR (dB)
-120
-110
-100
-90
-80
-70
-60
-50
-40
-30
-20
-10
0
20
100
1k
10k
20k
PVDD
PO = 1 W
PVDD = 14.4 V + 1 VRMS
BTL
图 7-16. PSRR vs Frequency - PVDD Only
Frequency (Hz)
PSRR (dB)
-120
-110
-100
-90
-80
-70
-60
-50
-40
-30
-20
-10
0
20
100
1k
10k
20k
VBAT
PO = 1 W
VBAT = 14.4 V + 1 VRMS
BTL
图 7-17. PSRR vs Frequency - VBAT Only
Frequency (Hz)
PSRR (dB)
-120
-110
-100
-90
-80
-70
-60
-50
-40
-30
-20
-10
0
20
100
1k
10k
20k
PVDD+VBAT
PO = 1 W
PVDD = VBAT = 14.4 V + 1 VRMS
BTL
图 7-18. PSRR vs Frequency - PVDD + VBAT
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
14
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 15 ===
7.7 Typical Characteristics: Bridge-Tied Load (BTL, 384 kHz)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 384 kHz, Output Configuration: 
BTL, AES17 filter, default I2C settings, LC Filter: 10 μH - 7G14C-100M. See 图 10-2 (unless otherwise noted).
Output Power(W)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
10m
100m
1
10
50
2 : Load
4 : Load
BTL
图 7-19. THD+N vs Power - 384 kHz
Frequency (Hz)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
20
100
1k
10k
20k
2 : Load
4 : Load
PO = 1 W
BTL
图 7-20. THD+N vs Frequency - 384 kHz
Supply Voltage (V)
Output Power (W)
5
7.5
10
12.5
15
17.5
20
22.5
25
27.5
0
5
10
15
20
25
30
35
40
45
50
55
60
65
70
75
2 1% THD+N
2 10% THD+N
4 1% THD+N
4 10% THD+N
TC = 75 °C
BTL
图 7-21. Output Power vs Supply Voltage - 384 kHz
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0
20
40
60
80
100
120
PVDD
PVDD + VBAT
4 Ω
TC = 75 °C
BTL
图 7-22. Efficiency vs Output Power - 4 Ω - 384 kHz
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0.1
0.5
1
5
10
50 100 200
0.01
PVDD
PVDD + VBAT
4 Ω
TC = 75 °C
BTL
图 7-23. Efficiency vs Output Power - 4 Ω - 384 kHz (Zoomed)
Output Power (W)
Power Dissipation (W)
0
10
20
30
40
50
60
70
80
90
100 110 120
0
1
2
3
4
5
6
7
8
9
10
11
12
PVDD (Device only)
PVDD+VBAT (Device only)
PVDD+VBAT (Device + LC)
4 Ω
TC = 75 °C
BTL
图 7-24. Power Dissipation vs Output Power - 4 Ω - 384 kHz
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
15
Product Folder Links: TAS6424E-Q1

=== Page 16 ===
7.7 Typical Characteristics: Bridge-Tied Load (BTL, 384 kHz) (continued)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 384 kHz, Output Configuration: 
BTL, AES17 filter, default I2C settings, LC Filter: 10 μH - 7G14C-100M. See 图 10-2 (unless otherwise noted).
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0
20
40
60
80
100
120
140
160
180
200
PVDD
PVDD + VBAT
2 Ω
TC = 75 °C
BTL
图 7-25. Efficiency vs Output Power - 2 Ω - 384 kHz
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0.1
0.5
1
5
10
50 100 200
0.01
PVDD
PVDD + VBAT
2 Ω
TC = 75 °C
BTL
图 7-26. Efficiency vs Output Power - 2 Ω - 384 kHz (Zoomed)
Output Power (W)
Power Dissipation (W)
0
20
40
60
80
100
120
140
160
180
200
0
4
8
12
16
20
24
28
32
36
40
PVDD (Device only)
PVDD+VBAT (Device only)
PVDD+VBAT (Device + LC)
2 Ω
TC = 75 °C
BTL
图 7-27. Power Dissipation vs Output Power - 2 Ω - 384 kHz
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
16
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 17 ===
7.8 Typical Characteristics: Parallel Bridge-Tied (PBTL)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 2 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 2.1 MHz, Output Configuration: 
PBTL, AES17 filter, default I2C settings, LC filter: 3.3 μH - DFEG7030D-3R3M. See 图 10-3 (unless otherwise noted)
Output Power(W)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
10m
100m
1
10
50
2 : Load
PVDD = 14.4 V
PBTL
图 7-28. THD+N vs Power - PBTL - 14.4V
Output Power(W)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
10m
100m
1
10
50 100
2 : Load
PVDD = 24 V
PBTL
图 7-29. THD+N vs Power - PBTL - 24 V
Frequency (Hz)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
20
100
1k
10k
20k
2 : Load
PVDD = 14.4 V
PO = 1 W
PBTL
图 7-30. THD+N vs Frequency - PBTL - 14.4 V
Frequency (Hz)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
20
100
1k
10k
20k
2 : Load
PVDD = 24 V
PO = 1 W
PBTL
图 7-31. THD+N vs Frequency - PBTL - 24 V
Supply Voltage (V)
Output Power (W)
4
6
8
10
12
14
16
18
20
22
24
0
20
40
60
80
100
120
140
160
2 : 1% THD+N
2 : 10% THD+N
TC = 75 °C
PBTL
图 7-32. Output Power vs Supply Voltage - PBTL
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0
20
40
60
80
100
120
PVDD (Device Only)
PVDD + VBAT (Device Only)
PVDD + VBAT (Device + LC)
2 Ω
TC = 75 °C
PBTL
图 7-33. Efficiency vs Output Power - PBTL - 2 Ω
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
17
Product Folder Links: TAS6424E-Q1

=== Page 18 ===
7.8 Typical Characteristics: Parallel Bridge-Tied (PBTL) (continued)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 2 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 2.1 MHz, Output Configuration: 
PBTL, AES17 filter, default I2C settings, LC filter: 3.3 μH - DFEG7030D-3R3M. See 图 10-3 (unless otherwise noted)
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0.1
0.5
1
5
10
50 100200
0.01
PVDD (Device Only)
PVDD + VBAT (Device Only)
PVDD + VBAT (Device + LC)
2 Ω
TC = 75 °C
PBTL
图 7-34. Efficiency vs Output power - PBTL - 2 Ω (Zoomed)
Output Power (W)
Power Dissipation (W)
0
10
20
30
40
50
60
70
80
90
100
110
0
1
2
3
4
5
6
7
8
9
10
11
12
13
14
PVDD (Device only)
PVDD+VBAT (Device only)
PVDD+VBAT (Device + LC)
2 Ω
TC = 75 °C
PBTL
图 7-35. Power Dissipation vs Output Power - PBTL - 2 Ω
Supply Voltage (V)
Noise (VRMS)
4
6
8
10
12
14
16
18
20
22
24
26
0
10
20
30
40
50
60
70
80
90
100
110
120
130
140
20
Gain Level 1
Gain Level 2
Gain Level 3
Gain Level 4
PBTL
图 7-36. Noise vs Supply Voltage - PBTL
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
18
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 19 ===
7.9 Typical Characteristics: Parallel Bridge-Tied Load (PBTL, 384 kHz)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 384 kHz, Output Configuration: 
PBTL, AES17 filter, default I2C settings, LC Filter: 10 μH - 7G14C-100M. See 图 10-3 for the full configuration (unless 
otherwise noted).
Output Power(W)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
10m
100m
1
10
50
2 : Load
PBTL
图 7-37. THD+N vs Power - PBTL - 384kHz
Frequency (Hz)
THD+N (%)
0.001
0.002
0.005
0.01
0.02
0.05
0.1
0.2
0.5
1
2
5
10
20
100
1k
10k
20k
2 : Load
PO = 1 W
PBTL
图 7-38. THD+N vs Frequency - PBTL - 384 kHz
Supply Voltage (V)
Output Power (W)
4
6
8
10
12
14
16
18
20
22
24
26
0
25
50
75
100
125
150
175
2 1% THD+N
2 10% THD+N
TC = 75 °C
PBTL
图 7-39. Output Power vs Supply Voltage - PBTL - 384 kHz
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0
20
40
60
80
100
120
PVDD
PVDD + VBAT
2 Ω
TC = 75 °C
PBTL
图 7-40. Efficiency vs Output Power - PBTL - 2 Ω - 384 kHz
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
19
Product Folder Links: TAS6424E-Q1

=== Page 20 ===
7.9 Typical Characteristics: Parallel Bridge-Tied Load (PBTL, 384 kHz) (continued)
TA = 25 °C, VVDD = 3.3 V, VBAT = PVDD = 14.4 V, RL = 4 Ω, fIN = 1 kHz, fs = 48 kHz, fSW = 384 kHz, Output Configuration: 
PBTL, AES17 filter, default I2C settings, LC Filter: 10 μH - 7G14C-100M. See 图 10-3 for the full configuration (unless 
otherwise noted).
Output Power (W)
Efficiency (%)
0
10
20
30
40
50
60
70
80
90
100
0.1
0.5
1
5
10
50 100200
0.01
PVDD
PVDD + VBAT
2 Ω
TC = 75 °C
PBTL
图 7-41. Efficiency vs Output Power - PBTL - 2 Ω - 384 kHz 
(Zoomed)
Output Power (W)
Power Dissipation (W)
0
10
20
30
40
50
60
70
80
90
100
110
0
1
2
3
4
5
6
7
8
9
10
11
12
PVDD (Device only)
PVDD+VBAT (Device only)
PVDD+VBAT (Device + LC)
2 Ω
TC = 75 °C
PBTL
图 7-42. Power Dissipation vs Output Power - PBTL - 2 Ω - 
384kHz
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
20
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 21 ===
8 Parameter Measurement Information
The parameters for the TAS6424E-Q1 device were measured using the circuit in 图 10-2.
For measurements with 2.1 MHz switching frequency the 3.3 µH inductor from the TAS6424E-Q1 EVM is used.
For measurements with 384 kHz switching frequency a 10 µH inductor was used.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
21
Product Folder Links: TAS6424E-Q1

=== Page 22 ===
9 Detailed Description
9.1 Overview
The TAS6424E-Q1 is a four-channel digital-input Class-D audio amplifier specifically tailored for use in the 
automotive industry. The device is designed for vehicle battery operation or boosted voltage systems. This ultra-
efficient Class-D technology allows for reduced power consumption, reduced PCB area, and reduced heat. The 
device realizes an audio sound-system design with smaller size and lower weight than traditional Class-AB 
solutions.
The core design blocks are as follows:
•
Serial audio port
•
Clock management
•
High-pass filter and volume control
•
Pulse width modulator (PWM) with output stage feedback
•
Gate drive
•
Power FETs
•
Diagnostics
•
Protection
•
Power supply
•
I2C serial communication bus
9.2 Functional Block Diagram
VDD
VCOM
VBAT
GVDD
PVDD
OUT_1P
OUT_1M
OUT_2P
OUT_2M
OUT_3P
OUT_3M
OUT_4P
OUT_4M
VREG
I2C_ADDR1
I2C_ADDR0
SDA
SCL
I2C Control
SDIN1
SDIN2
SCLK
FSYNC
MCLK
Serial
Audio
Port
PLL and Clock 
Management
STANDBY
WARN
FAULT
Digital Core
Reference 
Regulators
Gate Drive 
Regulator
Channel 1 
Powerstage
Channel 2 
Powerstage
Channel 3 
Powerstage
Channel 4 
Powerstage
Volume Control
-100 to +24 dB
0.5 dB steps
Gate 
Drives
Digital to PWM
Clip 
Detection
Closed Loop Class D Amplifier
Overcurrent Limit
Protection
Overcurrent
Overtemperature
Overvoltage and Undervoltage
DC Detection
Short to GND
DC Load Diagnostics
Short to Power
Open Load
Shorted Load
AC Load Diagnostics
MUTE
Copyright © 2016, Texas Instruments Incorporated
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
22
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 23 ===
9.3 Feature Description
9.3.1 Serial Audio Port
The serial audio port (SAP) receives audio in either I2S, left justified, right justified, or TDM formats.
Settings for the serial audio port are programmed in the SAP Control Register (address = 0x03) [default = 0x04].
图 9-1 shows the digital audio data connections for I2S and TDM8 mode for a eight channel system.
MCLK
SCLK
FSYNC
SDIN1
SDIN2
Device A
MCLK
SCLK
FSYNC
SDIN1
SDIN2
Device B
MCLK
SCLK
FSYNC
DATA1
DATA2
SOC
DATA3
DATA4
i2S
MCLK
SCLK
FSYNC
SDIN1
SDIN2
Device A
MCLK
SCLK
FSYNC
SDIN1
SDIN2
Device B
MCLK
FSYNC
DATA
SOC
TDM8
SCLK
图 9-1. Digital-Audio Data Connection
9.3.1.1 I2S Mode
I2S timing uses the FSYNC pin to define when the data being transmitted is for the left channel and when the 
data is for the right channel. The FSYNC pin is low for the left channel and high for the right channel. The bit 
clock, SCLK, runs at 32 × fS or 64 × fS and is used to clock in the data. A delay of one bit clock occurs from the 
time the FSYNC signal changes state to the first bit of data on the data lines. The data is presented in 2s-
complement form (MSB-first). The data is valid on the rising edge of the bit clock and is used to clock in the data.
9.3.1.2 Left-Justified Timing
Left-justified (LJ) timing also uses the FSYNC pin to define when the data being transmitted is for the left 
channel and when the data is for the right channel. The FSYNC pin is high for the left channel and low for the 
right channel. A bit clock running at 32 × fS or 64 × fS is used to clock in the data. The first bit of data appears on 
the data lines at the same time FSYNC toggles. The data is written MSB-first and is valid on the rising edge of 
the bit clock. Digital words can be 16-bits or 24-bits wide and pad any unused trailing data-bit positions in the 
left-right (L/R) frame with zeros.
9.3.1.3 Right-Justified Timing
Right-justified (RJ) timing also uses the FSYNC pin to define when the data being transmitted is for the left 
channel and when the data is for the right channel. The FSYNC pin is high for the left channel and low for the 
right channel. A bit clock running at 32 × fS or 64 × fS is used to clock in the data. The first bit of data appears on 
the data 8-bit clock periods (for 24-bit data) after the FSYNC pin toggles. In RJ mode the LSB of data is always 
clocked by the last bit clock before the FSYNC pin transitions. The data is written MSB-first and is valid on the 
rising edge of bit clock. The device pads the unused leading data-bit positions in the L/R frame with zeros.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
23
Product Folder Links: TAS6424E-Q1

=== Page 24 ===
9.3.1.4 TDM Mode
TDM mode supports 4 or 8 channels of audio data. The TDM mode is automatically selected when the TDM 
clocks are present. The device can be configured through I2C to use different stereo pairs in the TDM data 
stream. The TDM mode supports 16-bit, 24-bit, and 32-bit input data lengths.
In TDM mode, SCLK must be 128 x fs or 256 x fs, depending on the TDM slot size. In TDM mode SCLK and 
MCLK can be connected together. If SCLK and MCLK are connected together or the frequency of SCLK and 
MCLK is equal, FSYNC should be minimum 2 MCLK pulses long.
In TDM mode, the SDIN1 pin (pin 15) is used for digital audio data. TI recommends to connect the unused 
SDIN2 pin (pin 16) to ground. 表 9-1 lists register settings for the TDM channel selection.
表 9-1. TDM Channel Selection
REGISTER SETTING
TDM8 CHANNEL SLOT
0x03
BIT 5
0x03
BIT 3
1
2
3
4
5
6
7
8
0
0
CH1
CH2
CH3
CH4
—
—
—
—
1
0
—
—
—
—
CH1
CH2
CH3
CH4
0
1
CH3
CH4
CH1
CH2
—
—
—
—
1
1
—
—
—
—
CH3
CH4
CH1
CH2
If PBTL mode is programmed for channel 1/2 or channel 3/4 the datasource can be set according to TDM 
Channel Selection in PBTL Mode.
表 9-2. TDM Channel Selection in PBTL Mode
REGISTER SETTING
TDM8 CHANNEL SLOT
0x03
BIT 5
0x03
BIT 3
0x21
BIT 6
1
2
3
4
5
6
7
8
0
0
0
PBTL 
CH1/2
—
PBTL 
CH3/4
—
—
—
—
—
1
0
0
—
—
—
—
PBTL 
CH1/2
—
PBTL 
CH3/4
—
0
0
1
—
PBTL 
CH1/2
—
PBTL 
CH3/4
—
—
—
—
1
0
1
—
—
—
—
—
PBTL 
CH1/2
—
PBTL 
CH3/4
0
1
0
PBTL 
CH3/4
—
PBTL 
CH1/2
—
—
—
—
—
1
1
0
—
—
—
—
PBTL 
CH3/4
—
PBTL 
CH1/2
—
0
1
1
—
PBTL 
CH3/4
—
PBTL 
CH1/2
—
—
—
—
1
1
1
—
—
—
—
—
PBTL 
CH3/4
—
PBTL 
CH1/2
9.3.1.5 Supported Clock Rates
The device supports MCLK rates of 128 × fS, 256 × fS, or 512 × fS.
The device supports SCLK rates of 32 × fS or 64 × fS in I2S, LJ or RJ modes or 128 × fS, or 256 × fS in TDM 
mode.
The device supports FSYNC rates of 44.1 kHz, 48 kHz, or 96 kHz.
The maximum clock frequency is 25 MHz. Therefore, for a 96 kHz FSYNC rate, the maximum MCLK rate is 256 
× fS.
Duty cycle of 50% is required for 128x FSYNC, for 256x and 512x 50% duty cycle is not required.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
24
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 25 ===
9.3.1.6 Audio-Clock Error Handling
When any kind of clock error, MCLK-FSYNC or SCLK-FSYNC ratio, or clock halt is detected, the device puts all 
channels into the Hi-Z state. When all audio clocks are within the expected range, the device automatically 
returns to the state it was in. See the 节 7.5 table for timing requirements.
0.5 × DVDD
0.5 × DVDD
0.5 × DVDD
FSYNC
(Input)
SCLK
(Input)
DATA
(Input)
tSCH
tSCL
tSF
tSCY
tDS
tDH
tFS
图 9-2. Serial Audio Timing
15
14
1
0
15
14
1
0
23
22
1
0
23
22
1
0
31
30
1
0
31
30
1
0
MSB
LSB
MSB
LSB
MSB
LSB
MSB
LSB
MSB
MSB
LSB
LSB
SDIN
Audio data word = 32 bit, SCLK = 64 fS
Audio data word = 24 bit, SCLK = 64 fS
SDIN
SDIN
Audio data word = 16 bit, SCLK = 64 fS
SCLK
FSYNC
L-channel
R-channel
1/fS
图 9-3. Left-Justified Audio Data Format
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
25
Product Folder Links: TAS6424E-Q1

=== Page 26 ===
15
14
1
0
15
14
1
0
23
22
1
0
23
22
1
0
31
30
1
0
31
30
1
0
MSB
LSB
MSB
LSB
MSB
LSB
MSB
LSB
MSB
MSB
LSB
LSB
SDIN
Audio data word = 32 bit, SCLK = 64 fS
Audio data word = 24 bit, SCLK = 64 fS
SDIN
SDIN
Audio data word = 16 bit, SCLK = 64 fS
SCLK
FSYNC
L-channel
R-channel
1/fS
图 9-4. I2S Audio Data Format
Audio Data Format: TDM8 mode
23
22
0
1
1/Fs (256 sbclks)
SDIN (I2S mode)
23
22
0
1
32 SCLK
8 blocks of 32 SCLK
23
22
0
1
32 SCLK
23
22
SCLK
FSYNC
图 9-5. TDM8 Audio Data Format
9.3.2 DC Blocking
Direct-current (DC) content in the audio signal can damage speakers. The data path has a high-pass filter to 
remove any DC from the input signal. The corner frequency is selectable from 4 Hz, 8 Hz, or 15 Hz to 30 Hz with 
bits 0 through 3 in Miscellaneous Control 4 Register (address = 0x26). The default value of –3 dB is 
approximately 4 Hz for 44.1 kHz or 48 kHz and approximately 8 Hz for 96 kHz sampling rates.
9.3.3 Volume Control and Gain
Each channel has an independent digital-volume control with a range from –100 dB to +24 dB with 0.5-dB 
steps. The volume control is set through I2C. The gain-ramp rate is programmable through I2C to take one step 
every 1, 2, 4, or 8 FSYNC cycles.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
26
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 27 ===
The peak output-voltage swing is also configurable in the gain control register through I2C. The four gain settings 
are 7.5 V, 15 V, 21 V, and 29 V. TI recommends selecting the lowest possible for the expected PVDD operation 
to optimize output noise and dynamic range performance.
9.3.4 High-Frequency Pulse-Width Modulator (PWM)
The PWM converts the PCM input data into a switched signal of varying duty cycle. The PWM modulator is an 
advanced design with high bandwidth, low noise, low distortion, and excellent stability. The output switching rate 
is synchronous to the serial audio-clock input and is programmed through I2C to be between 8× and 48× the 
input-sample rate. The option to switch at high frequency allows the use of smaller and lower cost external 
filtering components. 表 9-3 lists the switch frequency options for bits 4 through 6 in the Miscellaneous Control 2 
Register (address 0x02).
表 9-3. Output Switch Frequency Option
INPUT SAMPLE RATE
BIT 6:4 SETTINGS
000
001
010 to 100
101
110
111
44.1 kHz
352.8 kHz
441 kHz
RESERVED
1.68 MHz
1.94 MHz
2.12 MHz
48 kHz
384 kHz
480 kHz
RESERVED
1.82 MHz
2.11 MHz
Not supported
96 kHz
384 kHz
480 kHz
RESERVED
1.82 MHz
2.11 MHz
Not supported
9.3.5 EMI Management Features
The EMI features are provided to help manage conducted and radiated emissions. Board layout and power 
supply design will provide the biggest impact on EMI performance, but these features can be used to adjust 
device operation for fine tuning EMI performance.
9.3.5.1 Spread-Spectrum
Spread-spectrum modulation is a PWM modulation technique that reduces the peaks seen in EMI 
measurements by varying the output PWM frequency. The minimum and maximum spread-spectrum 
frequencies are adjustable using the spread-spectrum registers discuss below.
To enable spread-spectrum follow the procedure below:
1.
The TAS6424E-Q1 must be correctly powered and in Hi-Z mode.
2.
While in Hi-Z mode, configure and enable spread-spectrum using I2C.
3.
The spread-spectrum settings are retained while PVDD and VBAT are applied, but must be enabled again if 
PVDD or VBAT are removed or invalid.
The spread spectrum algorithm uses a triangle waveform to vary the frequency around the fundamental. See the 
figure below.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
27
Product Folder Links: TAS6424E-Q1

=== Page 28 ===
Fcenter
Fmin
Fmax
Frequency
Time
FSS
图 9-6. Spread-Spectrum Algorithm Diagram
The spread-specrtum registers are calculated using the relationships below. Note that it's recommended to start 
with SS_PRE_DIV = 0x1F for most use cases.
•
SS_PRE_DIV = (256 * FS / Fcemter) - 2) / 2
•
SS_AMP = 64 * (Fcenter - Fmin) / Fcenter
•
SS_STEP = 16 * 4 * SS_AMP * FSS / Fcenter
where
•
FS - audio sampling frequency
•
Fmax - maximum spread-spectrum frequency
•
Fmin - minimum spread-spectrum frequency
•
Fcenter - spread-spectrum center frequency
•
FSS - spread-spectrum triangle waveform frequency
•
FPWM_min - minimum PWM output frequency with spread-spectrum enabled
•
FPWM_max - maximum PWM output frequency with spread-spectrum enabled
The following sample code enables spread-spectrum for 48 kHz audio sample rate, 32-bit audio depth, TDM-8 
and 2.1 MHz.
w D6 28 EA
w D6 77 82    // Enable SS, SS_AMPL = 2
w D6 78 1F    // SS_PRE_DIV = 31, Fcenter = 192 kHz
w D6 79 3F    // SS_STEP = 63
The follow equations calculate the output PWM frequency variation with the settings listed previously.
•
Fmin = 256 * FS / ((SS_PRE_DIV * 2 + 2) + SS_AMPL = 256 * 48 kHz / ((31 * 2 + 2) + 2) = 186.18 kHz
•
Fmax = 256 * FS / ((SS_PRE_DIV * 2 + 2) + SS_AMPL = 256 * 48 kHz / ((31 * 2 + 2) - 2) = 198.19 kHz
•
FPWM_min = Fmin * 11 = 186.18 kHz * 11 = 2.048 MHz
•
FPWM_max = Fmax * 11 = 198.19 kHz * 11 = 2.189 MHz
9.3.5.2 Channel-to-Channel Output Phase Control
The TAS6424E-Q1 has configurable output PWM phase control to manage conducted and radiated emissions. 
This feature allows the channel output PWM phase offset, relative to other channels, to be changed between 
210, 225 and 240 degrees.
The phase options available can be found in Miscellaneous Control 2 Register (address = 0x02) [default = 0x62].
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
28
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 29 ===
Note
Miscellaneous Control 5 Register (address = 0x28) [default = 0x0A], Bit 5 MUST be set to '1' prior to 
exiting STANDBY mode of the device. This specifies the device operates in a supported phase 
offset mode. By default, bit 5 is set to '0', which is not a supported output phase offset mode.
9.3.6 Gate Drive
The gate driver accepts the low-voltage PWM signal and level shifts it to drive a high-current, full-bridge, power-
FET stage. The device uses proprietary techniques to optimize EMI and audio performance.
The gate-driver power-supply voltage, GVDD, is internally generated and a decoupling capacitor is connected at 
pin 9 and pin 10.
The full H-bridge output stages use only NMOS transistors. Therefore, bootstrap capacitors are required for the 
proper operation of the high side NMOS transistors. A 1-µF ceramic capacitor of quality X7R or better, rated for 
at least 16 V, must be connected from each output to the corresponding bootstrap input (see the application 
circuit diagram in 图 10-2 ). The bootstrap capacitors connected between the BST pins and corresponding output 
function as a floating power supply for the high-side N-channel power MOSFET gate drive circuitry. During each 
high-side switching cycle, the bootstrap capacitors hold the gate-to-source voltage high keeping the high-side 
MOSFETs turned on.
9.3.7 Power FETs
The BTL output for each channel comprises four N-channel 90-mΩ FETs for high efficiency and maximum power 
transfer to the load. These FETs are designed to handle the fast switching frequency and large voltage 
transients during load dump.
9.3.8 Load Diagnostics
The device incorporates both DC load diagnostics and AC load diagnostics, which are used to determine the 
status of the load. The DC diagnostics are turned on by default, but if a fast startup without diagnostics is 
required, the DC diagnostics can be bypassed through I2C. The DC diagnostics runs when any channel is 
directed to leave the Hi-Z state and enter the MUTE or PLAY state. The DC diagnostics can also be enabled 
manually to run on any or all channels . DC Diagnostics can be started from any operating condition, but if the 
channel is in PLAY state, then the time to complete the diagnostic is longer because the device must ramp down 
the audio signal of that channel before transitioning to the Hi-Z state. The DC diagnostics are available as soon 
as the device supplies are within the recommended operating range. The DC diagnostics do not rely on the 
audio input clocks to be available to function. DC Diagnostic results are reported for each channel separately 
through the I2C registers.
9.3.8.1 DC Load Diagnostics
The DC load diagnostics are used to verify the load is properly connected. The DC diagnostics consists of four 
tests: short-to-power (S2P), short-to-ground (S2G), open-load (OL), and shorted-load (SL). The S2P and S2G 
tests trigger if the impedance to GND or a power rail is below that specified in the Specifications section. The 
diagnostic detects a short to vehicle battery, even when the supply is boosted. The SL test has an I2C-
configurable threshold depending on the expected load to be connected. Because the speakers connected to 
each channel might be different, each channel can be assigned a unique threshold value. The OL test reports if 
the select channel has a load impedance greater than the limits in the Specifications section.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
29
Product Folder Links: TAS6424E-Q1

=== Page 30 ===
Open Load
Open Load Detected
Open Load (OL) 
Detection Threshold
Normal or Open Load 
May Be Detected
Shorted Load
Shorted Load Detected
Shorted Load (SL) 
Detection Threshold
Normal or Shorted Load 
May Be Detected
Normal Load
Play Mode
OL Maximum
OL Minimum
SL Maximum
SL Minimum
图 9-7. DC Load Diagnostic Reporting Thresholds
9.3.8.2 Line Output Diagnostics
The device also includes an optional test to detect a line-output load. A line-output load is a high-impedance load 
that is above the open-load (OL) threshold such that the DC-load diagnostics report an OL condition. After an OL 
condition is detected on a channel, if the line output detection bit is also set, the channel checks if a line-output 
load is present as well. This test is not pop free, so if an external amplifier is connected it should be muted.
9.3.8.3 AC Load Diagnostics
The AC load diagnostic is used to determine the proper connection of a capacitively-coupled speaker or tweeter 
when used with a passive crossover. The AC load diagnostic is controlled through I2C. The AC diagnostics 
requires an external input signal and reports the approximate load impedance and phase. The selected signal 
frequency should create current flow through the desired speaker for proper detection. If multiple channels must 
be tested, the diagnostics should be run in series. The AC load-diagnostic test procedure is as follows.
9.3.8.3.1 Impedance Magnitude Measurement
For load-impedance detection, use the following test procedure:
1.
Set the channels to be tested into the Hi-Z state.
2.
Set the AC_DIAGS_LOOPBACK bit (bit 7 in register 0x16) to '0'.
3.
Apply a full-scale input signal from the DSP for the tested channels with the desired frequency 
(recommended 10 kHz to 20 kHz).
Note
The device ramps the signal up and down automatically to prevent pops and clicks.
4.
Set the device into the AC diagnostic mode (set bit 3 through bit 0 as needed in register 0x15 to '1' for CH1 
to CH4. For PBTL mode, test channel 1 for PBTL12 and channel 3 for PBTL34)
5.
Read back the AC impedance (register 0x17 through register register 0x1A).
When the test is complete the channel reporting register indicates the status change from the AC diagnostic 
mode to the Hi-Z state. The detected impedance is stored in the appropriate I2C register.
The hexadecimal register value must be converted to decimal and used to calculate the impedance magnitude 
using 方程式 1.
_
2.371
 
 (
)
(
)( 
)
Impedance
CHx
mV
Channelx Impedance
Ohms
Gain I mA
u
 
(1)
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
30
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 31 ===
9.3.8.3.2 Impedance Phase Reference Measurement
The first stage to determine the AC phase is to use the built-in loopback mode to determine the reference value 
for the phase measurement. This reference nullifies any phase offset in the device and measure only the phase 
of the load. This is measured for channels 1and 3 only. Channel 2 uses the results of channel 1 for the 
calculations. Channel 4 uses the results of channel 3 for the calculations. Measure channel 1 and channel 3 
sequentially, they cannot be measured at the same time.
For loopback delay detection, use the following test procedure for either BTL mode or PBTL mode:
•
BTL mode
1.
Set the AC_DIAGS_LOOPBACK bit (bit 7 in register 0x16) to '1' to enable AC loopback mode.
2.
Apply a 0-dBFS 19 kHz signal and enable AC load diagnostics. CH1 and CH2 reuse the AC sensing loop 
of CH1 (set bit 3 in register 0x15 to '1'). CH3, CH4 reuse the AC sensing loop of CH3 (set bit 1 in register 
0x15 to '1').
3.
Read back the 16-bit hexadecimal, AC_LDG_PHASE1 value. Register 0x1B holds the MSB and register 
0x1C holds the LSB.
4.
For channel 1/2 set bit 3 in register 0x15 to '0'. For channel 3/4 set bit 1 in register 0x15 to '0'.
•
PBTL mode STANDBY
1.
Set the AC_DIAGS_LOOPBACK bit (bit 7 in register 0x16) to '1' to enable AC loopback mode.
2.
Set the PBTL CH12 and PBTL CH34 bits (see register 0x00) to '0' without toggling pin to enter BTL mode 
only for load diagnostics.
3.
Apply a 0 dBFS 19 kHz signal and enable AC load diagnostics. For PBTL12, enable the AC sensing loop 
of CH1 (set bit 3 in register 0x15 to '1'). For PBTL34, enable the AC sensing loop of CH3 (set bit 1 in 
register 0x15 to '1').
4.
Read back the AC_LDG_PHASE1 value. Register 0x1B holds the MSB and register 0x1C holds the LSB.
5.
Set the PBTL CH12 and PBTL CH34 bits (see register 0x00) to '1' to go back to PBTL mode for load 
diagnostics.
6.
For PBTL12 set bit 3 in register 0x15 to '0'. For PBTL34 set bit 1 in register 0x15 to '0'.
When the test is complete, the channel reporting register indicates the status change from the AC diagnostic 
mode to the Hi-Z state. The detected impedance is stored in the appropriate I2C register.
9.3.8.3.3 Impedance Phase Measurement
After performing the phase reference measurements, measure the phase of the speaker load. This is performed 
in the same manner as the reference measurements, except the loopback is disabled in bit 7 register 0x16. 
Previously, the phase reference is measured on channel 1and channel 3. In this test stage all four channels are 
measured. Measure the channels sequentially as they cannot be measured at the same time.
For loopback delay detection, use the following test procedure for either BTL mode or PBTL mode:
•
BTL mode
1.
Set the AC_DIAGS_LOOPBACK bit (bit 7 in register 0x16) to '0' to disable AC loopback mode.
2.
Apply a 0-dBFS 19 kHz signal and enable AC load diagnostics. CH1 and CH2 reuse the AC sensing loop 
of CH1 (set bit 3 in register 0x15 to '1'). CH3, CH4 reuse the AC sensing loop of CH3 (set bit 1 in register 
0x15 to '1').
3.
Read back the 16-bit hexadecimal, AC_LDG_PHASE1 value. Register 0x1B holds the MSB and register 
0x1C holds the LSB.
4.
Read back the hexadecimal stimulus value, STI. Register 0x1D holds the MSB and register 0x1E holds 
the LSB.
5.
For channel 1/2 set bit 3 in register 0x15 to '0'. For channel 3/4 set bit 1 in register 0x15 to '0'.
When the test is complete, the channel reporting register indicates the status change from the AC 
diagnostic mode to the Hi-Z state. The detected impedance is stored in the appropriate I2C register.
•
PBTL mode
1.
Set the AC_DIAGS_LOOPBACK bit (bit 7 in register 0x16) to '0' to disable AC loopback mode.
2.
Set the PBTL CH12 and PBTL CH34 bits (see register 0x00) to '0' without toggling STANDBY pin to enter 
BTL mode only for load diagnostics.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
31
Product Folder Links: TAS6424E-Q1

=== Page 32 ===
3.
Apply a 0 dBFS 19 kHz signal and enable AC load diagnostics. For PBTL12, enable the AC sensing loop 
of CH1 (set bit 3 in register 0x15 to '1'). For PBTL34, enable the AC sensing loop of CH3 (set bit 1 in 
register 0x15 to 1).
4.
Read back the AC_LDG_PHASE1 value. Register 0x1B holds the MSB and register 0x1C holds the LSB.
5.
Read back the hexadecimal stimulus value, STI. Register 0x1D holds the MSB and register 0x1E holds 
the LSB.
6.
Set the PBTL CH12 and PBTL CH34 bits (see register 0x00) to '1' to go back to PBTL mode for load 
diagnostics.
7.
For PBTL12 set bit 3 in register 0x15 to '0'. For PBTL34 set bit 1 in register 0x15 to '0'.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
32
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 33 ===
The AC phase in degrees is calculated with the 方程式 2.
2D=OA_%*T = 360(2D=OA_%*T:.$-; F 2D=OA_%*T(.&/)
56+_%*T(.&/)
) 
(2)
Where:
•
Phase_CHx(LBK) is the reference phase measurement. LBK stands for loopback mode
•
Phase_CHx(LDM) is the phase measure of the load. LDM stands for load mode
•
STI_CHx(LDM) is the stimulus value
表 9-4. AC Impedance Code to Magnitude
SETTING
GAIN AT 19 kHz
I(A)
MEASUREMENT RANGE 
(Ω)
MAPPING FROM CODE 
TO MAGNITUDE (Ω/
Code)
Gain = 4, I = 10 mA 
(recommended)
4.28
0.01
12
0.05832
Gain = 4, I = 19 mA
4.28
0.019
6
0.0307
Gain = 1, I = 10 mA 
(recommended)
1
0.01
48
0.2496
Gain = 1, I = 19 mA
1
0.019
24
0.1314
9.3.9 Protection and Monitoring
9.3.9.1 Overcurrent Limit (ILIMIT)
The overcurrent limit terminates each PWM pulse to limit the output current flow when the current limit (ILIMIT) is 
exceeded. Power is limited, but operation continues without disruption and prevents undesired shutdown for 
transient music events. ILIMIT is not reported as a fault condition to either registers or the FAULT pin but as 
warning condition to the WARN pin and ILIMIT Status Register (address = 0x25). Each channel is independently 
monitored and limited. The two programable levels can be set by bit 4 in the Miscellaneous Control 1 register 
(address 0x01).
9.3.9.2 Overcurrent Shutdown (ISD)
If the output load current reaches ISD, such as an output short to GND, then a peak current limit occurs, which 
shuts down the channel. The time to shutdown the channel varies depending on the severity of the short 
condition. The affected channel is placed into the Hi-Z state, the fault is reported to the register, and the FAULT 
pin is asserted. The device remains in this state until the CLEAR FAULT bit is set in Miscellaneous Control 3 
Register, 0x21 bit 7. After clearing this bit and if the diagnostics are enabled, the device automatically starts 
diagnostics on the channel and, if no load failure is found, the device restarts. If a load fault is found the device 
continues to rerun the diagnostics once per second. Because this hiccup mode uses the diagnostics, no high 
current is created. If the diagnostics are disabled, the device sets the state for that channel to Hi-Z and requires 
the MCU to take the appropriate action, setting the CLEAR FAULT bit after the fault got removed, in order to 
return to Play state.
Two programable levels can be set by bit 4 in the Miscellaneous Control 1 register (address 0x01).
9.3.9.3 DC Detect
This circuit detects a DC offset continuously during normal operation at the output of the amplifier. If the DC 
offset exceeds the threshold, that channel is placed in the Hi-Z state, the fault is reported to the I2C register, and 
the FAULT pin is asserted. A register bit can be used to mask reporting to the FAULT pin if required.
9.3.9.4 Clip Detect
The clip detect is reported on the WARN pin if 100% duty-cycle PWM is reached for a minimum number of PWM 
cycles set by the Clip Window Register (address = 0x23). The default is 20 PWM cycles. The Clip Detect is 
latched and can be cleared by I2C. Masking the clip reporting to the pin is possible through I2C. If desired, the 
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
33
Product Folder Links: TAS6424E-Q1

=== Page 34 ===
Clip Detect can be configured to be non-latching through I2C. In non-latching mode, Clip Detect is reported when 
the PWM duty cycle reaches 100%, and deasserted once the PWM duty cycle falls below 100%.
9.3.9.5 Global Overtemperature Warning (OTW), Overtemperature Shutdown (OTSD)
Four overtemperature warning levels are available in the device (see the Register Maps section for thresholds). 
When the junction temperature exceeds the warning level, the WARN pin is asserted, unless the mask bit in Pin 
Control Register (address = 0x14) has been set to disable reporting. The device functions until the OTSD value 
is reached at which point all channels are placed in the Hi-Z state, and the FAULT pin is asserted. By default, the 
device remains shut down after the temperature drops to normal levels. This configuration can be changed in bit 
3 of the Miscellaneous Control 3 Register (address = 0x21) to auto-recovery: When the junction temperature 
returns to normal levels, the device automatically recovers and places the channel into the state indicated by the 
state control register. Note that even in auto-recovery configuration the FAULT pin remains asserted until the 
CLEAR FAULT bit (bit 7) is set in register 0x21.
9.3.9.6 Channel Overtemperature Warning [OTW(i)] and Shutdown [OTSD(i)]
In addition to the global OTW, each output channel also has an individual overtemperature warning and 
shutdown. If any channel exceeds the OTW(i) threshold, the warning register bit in Warnings Register (address = 
0x13) is set as the WARN pin is asserted, unless the mask bit has been set to disable reporting. If the channel 
temperature exceeds the OTSD(i) threshold then the channel goes to the Hi-Z state and either remains there or 
auto-recovers to the state indicated by the state control register when the temperature drops below the OTW(i) 
threshold, depending on the setting of bit 3 of the Miscellaneous Control 3 Register (address = 0x21).
9.3.9.7 Undervoltage (UV) and Power-On-Reset (POR)
The UV protection detects low voltages on the PVDD and VBAT pins. In the event of an UV condition, the FAULT 
pin is asserted, and the I2C register is updated. A POR on the VDD pin causes the I2C to goes to the high-
impedance (Hi-Z) state, and all registers are reset to default values. At power-on or after a POR event, the POR 
warning bit and WARN pin are asserted.
9.3.9.8 Overvoltage (OV) and Load Dump
The OV protection detects high voltages on the PVDD pin. If the PVDD pin reaches the OV threshold, the FAULT 
pin is asserted and the I2C register is updated. The device can withstand 40 V load dump voltage spikes.
9.3.10 Power Supply
The device has three power supply inputs, VDD, PVDD, and VBAT, which are described as follows:
•
VDD:
This pin is a 3.3 V supply pin that provides power to the low voltage circuitry.
•
VBAT:
This pin is a higher voltage supply that can be connected to the vehicle battery or the regulated voltage rail in 
a boosted system within the recommended limits. For best performance, this rail should be 10 V or higher. 
See the 节 7.5 table for the maximum supply voltage. This supply rail is used for higher voltage analog 
circuits but not the output FETs.
•
PVDD:
This pin is a high-voltage supply that can either be connected to the vehicle battery or to another voltage rail 
in a boosted system. The PVDD pin supplies the power to the output FETs and can be within the 
recommended operating limits, even if that is below the VBAT supply, to allow for dynamic voltage systems.
Several on-chip regulators are included for generating the voltages necessary for the internal circuitry. The 
external pins are provided only for bypass capacitors to filter the supply and should not be used to power other 
circuits.
The device can withstand fortuitous open ground and power conditions within the absolute maximum ratings for 
the device. Fortuitous open ground usually occurs when a speaker wire is shorted to ground, allowing for a 
second ground path through the body diode in the output FETs.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
34
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 35 ===
9.3.10.1 Vehicle-Battery Power-Supply Sequence
9.3.10.1.1 Power-Up Sequence
In a typical system, the VBAT and PVDD supplies are both connected to the vehicle battery and power up at the 
same time. The VDD supply should be applied after the VBAT and PVDD supplies are within the recommended 
operating range.
9.3.10.1.2 Power-Down Sequence
To power-down the device, first set the STANDBY pin low for at least 15ms before removing PVDD, VBAT or 
VDD. After 15ms, the power supplies can be removed.
9.3.10.2 Boosted Power-Supply Sequence
In this case, the VBAT and PVDD inputs are not connected to the same supply.
When powering up, apply the VBAT supply first, the VDD supply second, and the PVDD supply last.
When powering down, first set the STANDBY pin low for at least 15ms before removing PVDD, VBAT or VDD. 
After 15ms, the power supplies can be removed.
9.3.11 Hardware Control Pins
The device has four pins for control and device status: FAULT, MUTE, WARN, and STANDBY.
9.3.11.1 FAULT
The FAULT pin reports faults and is active low under any of the following conditions:
•
Any channel faults (overcurrent or DC detection)
•
Overtemperature shutdown
•
Overvoltage or undervoltage conditions on the VBAT or PVDD pins
•
Clock errors
For all listed faults, the FAULT pin remains asserted after the fault condition is rectified. Deassert the FAULT pin 
by writing the CLEAR FAULT bit (bit 7) in register 0x21.
The register reports for all fault reports remain asserted until they are cleared by writing the CLEAR FAULT bit 
(bit 7) in register 0x21.
Register bits are available to mask fault categories from reporting to the FAULT pin. These bits only mask the 
setting of the pin and do not affect the register reporting or protection of the device. By default all faults are 
reported to the pin. See the Register Maps section for a description of the mask settings.
This pin is an open-drain output with an internal 100 kΩ pullup resistor to VDD.
9.3.11.2 WARN
This active-low output pin reports audio clipping, overtemperature warnings,overcurrent limit warnings and POR 
events.
Clipping is reported if any channel is at the maximum modulation for 20 consecutive PWM clocks (default value) 
which results in a 10-µs delay to report the onset of clipping. Changing the number of required consecutive PWM 
clocks in the Clip Window Register (address = 0x23) impacts the report delay time. The Clip Detect Warning bit 
is sticky in latching mode and can be cleared by the CLEAR FAULT bit (bit 7) in register 0x21.
An overtemperature warning (OTW) is reported if the general temperature or any of the channel temperature 
warnings are set. The warning temperature can be set through bits 5 and 6 in Miscellaneous Control 1 Register 
(address = 0x01).
Register bits are available to mask either clipping, OTW or ILIMIT reporting to the pin. These bits only mask the 
setting of the pin and do not affect the register reporting. By default both clipping, ILIMIT and OTW are reported.
The WARN pin is latched and can be cleared by writing the CLEAR FAULT bit (bit 7) in register 0x21.
This pin is an open-drain output with an internal 100 kΩ pull-up resistor to VDD.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
35
Product Folder Links: TAS6424E-Q1

=== Page 36 ===
9.3.11.3 MUTE
This active-low input pin is used for hardware control of the mute and unmute function for all channels.
This pin has a 100 kΩ internal pull-down resistor.
9.3.11.4 STANDBY
When this active-low input pin is asserted, the device goes into shutdown and current draw is limited. This pin 
can be used to shut down the device rapidly. The outputs are ramped down in less than 5 ms if the device is not 
already in the Hi-Z state.
This pin has a 100 kΩ internal pull-down resistor.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
36
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 37 ===
9.4 Device Functional Modes
9.4.1 Operating Modes and Faults
The operating modes and faults are listed in the following tables.
表 9-5. Operating Modes
STATE NAME
OUTPUT FETS
OSCILLATOR
I2C
STANDBY
Hi-Z
Stopped
Active
Hi-Z
Hi-Z
Active
Active
MUTE
Switching at 50%
Active
Active
PLAY
Switching with audio
Active
Active
表 9-6. Global Faults and Actions
FAULT/
EVENT
FAULT/EVENT
CATEGORY
MONITORING
MODES
REPORTING
METHOD
ACTION
RESULT
POR
Voltage fault
All
I2C + WARN pin
Standby
VBAT UV
Hi-Z, mute, normal
I2C + FAULT pin
Hi-Z
PVDD UV
VBAT or PVDD OV
OTW
Thermal warning
Hi-Z, mute, normal
I2C + WARN pin
None
OTSD
Thermal shutdown
Hi-Z, mute, normal
I2C + FAULT pin
Hi-Z
表 9-7. Channel Faults and Actions
FAULT/
EVENT
FAULT/EVENT
CATEGORY
MONITORING
MODES
REPORTING
METHOD
ACTION
TYPE
Clipping
Warning
Mute and play
I2C + WARN or FAULT pin
None
Overcurrent limiting
Protection
I2C + WARN pin
Current limit
Overcurrent fault
Output channel fault
I2C + FAULT pin
Hi-Z
DC detect
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
37
Product Folder Links: TAS6424E-Q1

=== Page 38 ===
9.5 Programming
9.5.1 I2C Serial Communication Bus
The device communicates with the system processor through the Inter-Integrated Circuit (I2C) serial 
communication bus as an I2C secondary-only device. The processor can poll the device through I2C to 
determine the operating status, configure settings, or run diagnostics. For a complete list and description of all 
I2C controls, see the Register Maps section.
The device includes two I2C address pins, so up to four devices can be used together in a system with no 
additional bus switching hardware. The I2C ADDRx pins set the secondary address of the device as listed in 表 
9-8.
表 9-8. I2C Addresses
DESCRIPTION
I2C ADDR1
I2C ADDR0
I2C Write
I2C Read
Device 0
0
0
0xD4
0xD5
Device 1
0
1
0xD6
0xD7
Device 2
1
0
0xD8
0xD9
Device 3
1
1
0xDA
0xDB
9.5.2 I2C Bus Protocol
The device has a bidirectional serial-control interface that is compatible with the I2C bus protocol and supports 
100 kbps and 400 kbps data transfer rates for random and sequential write and read operations. The TAS6424E-
Q1 is a secondary-only device that does not support a multiprimary bus environment or wait-state insertion. The 
control interface is used to program the registers of the device and to read device status.
The I2C bus uses two signals, SDA (data) and SCL (clock), to communicate between integrated circuits in a 
system. Data is transferred on the bus serially, one bit at a time. The address and data are transferred in byte (8-
bit) format with the most-significant bit (MSB) transferred first. In addition, each byte transferred on the bus is 
acknowledged by the receiving device with an acknowledge bit. Each transfer operation begins with the primary 
device driving a start condition on the bus, and ends with the primary device driving a stop condition on the bus. 
The bus uses transitions on the data terminal (SDA) while the clock is HIGH to indicate a start and stop 
conditions. A HIGH-to-LOW transition on SDA indicates a start, and a LOW-to-HIGH transition indicates a stop. 
Normal data bit transitions must occur within the low time of the clock period. The primary generates the 7-bit 
secondary address and the read/write (R/W) bit to open communication with another device and then wait for an 
acknowledge condition. The device holds SDA LOW during the acknowledge-clock period to indicate an 
acknowledgment. When this occurs, the primary transmits the next byte of the sequence. Each device is 
addressed by a unique 7-bit secondary address plus a R/W bit (1 byte). All compatible devices share the same 
signals via a bidirectional bus using a wired-AND connection. An external pullup resistor must be used for the 
SDA and SCL signals to set the HIGH level for the bus. The number of bytes that can be transmitted between 
start and stop conditions is unlimited. When the last word transfers, the primary generates a stop condition to 
release the bus.
SDA
SCL
Start
Stop
7-Bit Target Address
R/
W
A
A
A
A
8-Bit Register Address (N)
8-Bit Register Data for 
Address (N)
7
6
5
4
3
2
1
0
7
6
5
4
3
2
1
0
7
6
5
4
3
2
1
0
7
6
5
4
3
2
1
0
8-Bit Register Data for 
Address (N)
图 9-8. Typical I2C Sequence
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
38
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 39 ===
SCL
SDA
tw(H)
tw(L)
tsu1
th1
tr
tf
图 9-9. SCL and SDA Timing
Use the I2C ADDRx pins to program the device secondary address. Read and write data can be transmitted 
using single-byte or multiple-byte data transfers.
9.5.3 Random Write
As shown in 图 9-10, a single-byte data-write transfer begins with the primary device transmitting a start 
condition followed by the I2C device address and the R/W bit. The R/W bit determines the direction of the data 
transfer. For a write data transfer, the R/W bit is a 0. After receiving the correct I2C device address and the R/W 
bit, the device responds with an acknowledge bit. Next, the primary transmits the address byte or bytes 
corresponding to the internal memory address being accessed. After receiving the address byte, the device 
again responds with an acknowledge bit. Next, the primary device transmits the data byte to be written to the 
memory address being accessed. After receiving the data byte, the device again responds with an acknowledge 
bit. Finally, the primary device transmits a stop condition to complete the single-byte data-write transfer.
Acknowledge
Acknowledge
Acknowledge
Start 
Condition
I2C Device Address 
and R/W Bit
Subaddress 
Data Byte
Stop 
Condition
ACK
A1
A0
ACK
A3
A2
A4
A5
A1
A3
A2
A6
A5
A4
A0
R/W ACK
A7
A6
D7
D6
D5
D4
D3
D2
D1
D0
图 9-10. Random Write Transfer
9.5.4 Sequential Write
A sequential data-write transfer is identical to a single-byte data-write transfer except that multiple data bytes are 
transmitted by the primary to the device as shown in 图 9-11. After receiving each data byte, the device responds 
with an acknowledge bit and the I2C subaddress is automatically incremented by one.
Acknowledge
Acknowledge
Acknowledge
Acknowledge
Acknowledge
Start 
Condition
I2C Device Address 
and R/W Bit
Subaddress 
First Data Byte
Other Data Byte
Last Data Byte
Stop 
Condition
ACK
D0
D0
ACK D7
D0
ACK D7
D7
ACK
A1
A7
R/W ACK
A1
A6
A5
A0
A6
A5
A4
A3
A0
图 9-11. Sequential Write Transfer
9.5.5 Random Read
As shown in 图 9-12, a single-byte data-read transfer begins with the primary device transmitting a start 
condition followed by the I2C device address and the R/W bit. For the data-read transfer, both a write followed by 
a read occur. Initially, a write occurs to transfer the address byte or bytes of the internal memory address to be 
read. As a result, the R/W bit is a 0. After receiving the address and the R/W bit, the device responds with an 
acknowledge bit. In addition, after sending the internal memory address byte or bytes, the primary device 
transmits another start condition followed by the address and the R/W bit again. This time the R/W bit is a 1, 
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
39
Product Folder Links: TAS6424E-Q1

=== Page 40 ===
indicating a read transfer. After receiving the address and the R/W bit, the device again responds with an 
acknowledge bit. Next, the device transmits the data byte from the memory address being read. After receiving 
the data byte, the primary device transmits a not-acknowledge followed by a stop condition to complete the 
single-byte data-read transfer.
Not 
Acknowledge
Acknowledge
Acknowledge
Acknowledge
Start 
Condition
I2C Device Address 
and R/W Bit
Subaddress 
I2C Device Address 
and R/W Bit
Data Byte
Stop 
Condition
ACK
D0
ACK
D7
A1
A0
R/W
A5
A0
A6
A7
A1
A0
R/W
A5
A6
ACK
Repeat Start 
Condition
A6
ACK
A5
A4
D6
D6
图 9-12. Random Read Transfer
9.5.6 Sequential Read
A sequential data-read transfer is identical to a single-byte data-read transfer except that multiple data bytes are 
transmitted by the device to the primary device as shown in 图 9-13. Except for the last data byte, the primary 
device responds with an acknowledge bit after receiving each data byte and automatically increments the I2C 
subaddress by one. After receiving the last data byte, the primary device transmits a not-acknowledge bit 
followed by a stop condition to complete the transfer.
Not 
Acknowledge
Acknowledge
Acknowledge
Acknowledge
Acknowledge
Repeat Start 
Condition
Acknowledge
Start 
Condition
I2C Device Address 
and R/W Bit
Subaddress 
I2C Device Address 
and R/W Bit
First Data Byte
Other Data Byte
Last Data Byte
Stop 
Condition
ACK
D0
D0
ACK D7
D0
ACK D7
R/W
D7
A6
ACK
A0
A0
ACK
A5
R/W ACK
A7
A0
A6
A6
图 9-13. Sequential Read Transfer
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
40
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 41 ===
9.6 Register Maps
表 9-9. I2C Address Register Definitions
Address
Type
Register Description
Section
0x00
R/W
Mode Control
Go
0x01
R/W
Miscellaneous Control 1
Go
0x02
R/W
Miscellaneous Control 2
Go
0x03
R/W
SAP Control (Serial Audio-Port Control)
Go
0x04
R/W
Channel State Control
Go
0x05
R/W
Channel 1 Volume Control
Go
0x06
R/W
Channel 2 Volume Control
Go
0x07
R/W
Channel 3 Volume Control
Go
0x08
R/W
Channel 4 Volume Control
Go
0x09
R/W
DC Diagnostic Control 1
Go
0x0A
R/W
DC Diagnostic Control 2
Go
0x0B
R/W
DC Diagnostic Control 3
Go
0x0C
R
DC Load Diagnostic Report 1 (Channels 1 and 2)
Go
0x0D
R
DC Load Diagnostic Report 2 (Channels 3 and 4)
Go
0x0E
R
DC Load Diagnostic Report 3 (Line Output)
Go
0x0F
R
Channel State Reporting
Go
0x10
R
Channel Faults (Overcurrent, DC Detection)
Go
0x11
R
Global Faults 1
Go
0x12
R
Global Faults 2
Go
0x13
R
Warnings
Go
0x14
R/W
Pin Control
Go
0x15
R/W
AC Load Diagnostic Control 1
Go
0x16
R/W
AC Load Diagnostic Control 2
Go
0x17
R
AC Load Diagnostic Report Channel 1
Go
0x18
R
AC Load Diagnostic Report Channel 2
Go
0x19
R
AC Load Diagnostic Report Channel 3
Go
0x1A
R
AC Load Diagnostic Report Channel 4
Go
0x1B
R
AC Load Diagnostic Phase Report High
Go
0x1C
R
AC Load Diagnostic Phase Report Low
Go
0x1D
R
AC Load Diagnostic STI Report High
Go
0x1E
R
AC Load Diagnostic STI Report Low
Go
0x1F
R
RESERVED
0x20
R
RESERVED
0x21
R/W
Miscellaneous Control 3
Go
0x22
R/W
Clip Control
Go
0x23
R/W
Clip Window
Go
0x24
R/W
Clip Warning
Go
0x25
R/W
ILIMIT Status
Go
0x26
R/W
Miscellaneous Control 4
Go
0x27
R
RESERVED
0x28
R/W
Miscellaneous Control 5
Go
0x77
R/W
Spread Spectrum Control 1
Go
0x78
R/W
Spread Spectrum Control 2
Go
0x79
R/W
Spread Spectrum Control 3
Go
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
41
Product Folder Links: TAS6424E-Q1

=== Page 42 ===
9.6.1 Mode Control Register (address = 0x00) [default = 0x00]
The Mode Control register is shown in 图 9-14 and described in 表 9-10.
图 9-14. Mode Control Register
7
6
5
4
3
2
1
0
RESET
RESERVED
PBTL CH34
PBTL CH12
CH1 LO MODE
CH2 LO MODE
CH3 LO MODE
CH4 LO MODE
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
表 9-10. Mode Control Field Descriptions
Bit
Field
Type
Reset
Description
7
RESET
R/W
0
0: Normal operation
1: Resets the device. Self-clearing, reads back 0.
6
RESERVED
R/W
0
RESERVED
5
PBTL CH34
R/W
0
0: Channels 3 and 4 are in BTL mode
1: Channels 3 and 4 are in parallel BTL mode
4
PBTL CH12
R/W
0
0: Channels 1 and 2 are in BTL mode
1: Channels 1 and 2 are in parallel BTL mode
3
CH1 LO MODE
R/W
0
0: Channel 1 is in normal/speaker mode
1: Channel 1 is in line output mode
2
CH2 LO MODE
R/W
0
0: Channel 2 is in normal/speaker mode
1: Channel 2 is in line output mode
1
CH3 LO MODE
R/W
0
1: Channel 3 is in line output mode
0
CH4 LO MODE
R/W
0
1: Channel 4 is in line output mode
9.6.2 Miscellaneous Control 1 Register (address = 0x01) [default = 0x32]
The Miscellaneous Control 1 register is shown in 图 9-15 and described in 表 9-11.
图 9-15. Miscellaneous Control 1 Register
7
6
5
4
3
2
1
0
HPF BYPASS
OTW CONTROL
OC CONTROL
VOLUME RATE
GAIN
R/W-0
R/W-01
R/W-1
R/W-00
R/W-10
表 9-11. Misc Control 1 Field Descriptions
Bit
Field
Type
Reset
Description
7
HPF BYPASS
R/W
0
0: High pass filter eneabled
1: High pass filter disabled
6–5
OTW CONTROL
R/W
01
00: Global overtemperature warning set to 140°C
01: Global overtemperature warning set to 130C
10: Global overtemperature warning set to 120°C
11: Global overtemperature warning set to 110°C
4
OC CONTROL
R/W
1
0: Overcurrent is level 1
1: Overcurrent is level 2
3–2
VOLUME RATE
R/W
00
00: Volume update rate is 1 step / FSYNC
01: Volume update rate is 1 step / 2 FSYNCs
10: Volume update rate is 1 step / 4 FSYNCs
11: Volume update rate is 1 step / 8 FSYNCs
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
42
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 43 ===
表 9-11. Misc Control 1 Field Descriptions (continued)
Bit
Field
Type
Reset
Description
1–0
GAIN
R/W
10
00: Gain level 1 = 7.5 V peak output voltage
01: Gain Level 2 = 15 V peak output voltage
10: Gain Level 3 = 21 V peak output voltage
11: Gain Level 4 = 29 V peak output voltage
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
43
Product Folder Links: TAS6424E-Q1

=== Page 44 ===
9.6.3 Miscellaneous Control 2 Register (address = 0x02) [default = 0x62]
The Miscellaneous Control 2 register is shown in 图 9-16 and described in 表 9-12.
图 9-16. Miscellaneous Control 2 Register
7
6
5
4
3
2
1
0
RESERVED
PWM FREQUENCY
RESERVED
SDM_OSR
OUTPUT PHASE
R/W-0
R/W-110
R/W-0
R/W-0
R/W-10
表 9-12. Misc Control 2 Field Descriptions
Bit
Field
Type
Reset
Description
7
RESERVED
R/W
0
RESERVED
6–4
PWM FREQUENCY
R/W
110
000: 8 × fS (352.8 kHz / 384 kHz)
001: 10 × fS (441 kHz / 480 kHz)
010: RESERVED
011: RESERVED
100: RESERVED
101: 38 × fS (1.68 MHz / 1.82 MHz)
110: 44 × fS (1.94 MHz / 2.11 MHz)
111: 48 × fS (2.12 MHz / not supported)
3
RESERVED
R/W
0
RESERVED
2
SDM_OSR
R/W
0
0: 64x OSR
1: 128x OSR
1–0
OUTPUT PHASE
R/W
10
The channel-to-channel PWM output phase, PHASE_SEL[2:0], 
is selected with the two LSB bits in this register and the MSB bit 
from Miscellaneous Control 5 Register (address = 0x28) [default 
= 0x0A], Bit 5.
WARNING: The MSB in Miscellaneous Control 5 Register, 
Bit 5 must be set to '1' before the device exits STANDBY. 
The default value MSB of '0' is not supported by this device.
0xx: RESERVED
010: RESERVED (default, must be changed)
100: RESERVED
101: CH1- 0, CH2- 210, CH3- 60, CH4- 270
110: CH1- 0, CH2- 225, CH3- 90, CH4- 315
111: CH1- 0, CH2- 240, CH3- 120, CH4- 360
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
44
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 45 ===
9.6.4 SAP Control (Serial Audio-Port Control) Register (address = 0x03) [default = 0x04]
The SAP Control (serial audio-port control) register is shown in 图 9-17 and described in 表 9-13.
图 9-17. SAP Control Register
7
6
5
4
3
2
1
0
INPUT SAMPLING RATE
8 Ch TDM 
SLOT SELECT
TDM SLOT 
SIZE
TDM SLOT 
SELECT 2
INPUT FORMAT
R/W-00
R/W-0
R/W-0
R/W-0
R/W-100
表 9-13. SAP Control Field Descriptions
Bit
Field
Type
Reset
Description
7–6
INPUT SAMPLING RATE
R/W
00
00: 44.1 kHz
01: 48 kHz
10: 96 kHz
11: RESERVED
5
8 Ch TDM SLOT SELECT
R/W
0
0: First four TDM slots
1: Last four TDM slots
4
TDM SLOT SIZE
R/W
0
0: TDM slot size is 24-bit or 32-bit
1: TDM slot size is 16-bit
3
TDM SLOT SELECT 2
R/W
0
See TDM Mode for details.
0: Normal
1: Swapped
2–0
INPUT FORMAT
R/W
100
000: 24-bit right justified
001: 20-bit right justified
010: 18-bit right justified
011: 16-bit right justified
100: I2S (16-bit or 24-bit)
101: Left justified (16-bit or 24-bit)
110: DSP mode (16-bit or 24-bit)
111: RESERVED
9.6.5 Channel State Control Register (address = 0x04) [default = 0x55]
The Channel State Control register is shown in 图 9-18 and described in 表 9-14.
图 9-18. Channel State Control Register
7
6
5
4
3
2
1
0
CH1 STATE CONTROL
CH2 STATE CONTROL
CH3 STATE CONTROL
CH4 STATE CONTROL
R/W-01
R/W-01
R/W-01
R/W-01
表 9-14. Channel State Control Field Descriptions
Bit
Field
Type
Reset
Description
7–6
CH1 STATE CONTROL
R/W
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
5–4
CH2 STATE CONTROL
R/W
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
45
Product Folder Links: TAS6424E-Q1

=== Page 46 ===
表 9-14. Channel State Control Field Descriptions (continued)
Bit
Field
Type
Reset
Description
3–2
CH3 STATE CONTROL
R/W
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
1–0
CH4 STATE CONTROL
R/W
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
46
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 47 ===
9.6.6 Channel 1 Through 4 Volume Control Registers (address = 0x05–0x08) [default = 0xCF]
The Channel 1 Through 4 Volume Control registers are shown in 图 9-19 and described in 表 9-15.
图 9-19. Channel x Volume Control Register
7
6
5
4
3
2
1
0
CH x VOLUME
R/W-CF
表 9-15. Ch x Volume Control Field Descriptions
Bit
Field
Type
Reset
Description
7–0
CH x VOLUME
R/W
0xCF
8-Bit Volume Control for each channel, register address for Ch1 
is 0x05, Ch2 is 0x06, Ch3 is 0x07 and Ch4 is 0x08, 0.5 dB/step:
0xFF: 24 dB
0xCF: 0 dB
0x07: –100 dB
< 0x07: MUTE
9.6.7 DC Load Diagnostic Control 1 Register (address = 0x09) [default = 0x00]
The DC Diagnostic Control 1 register is shown in 图 9-20 and described in 表 9-16.
图 9-20. DC Load Diagnostic Control 1 Register
7
6
5
4
3
2
1
0
DC LDG 
ABORT
2x_RAMP
2x_SETTLE
RESERVED
LDG LO 
ENABLE
LDG BYPASS
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
表 9-16. DC Load Diagnostics Control 1 Field Descriptions
Bit
Field
Type
Reset
Description
7
DC LDG ABORT
R/W
0
0: Default state, clear after abort
1: Aborts the load diagnostics in progress
6
2x_RAMP
R/W
0
0: Normal ramp time
1: Double ramp time
5
2x_SETTLE
R/W
0
0: Normal Settle time
1: Double settling time
4–2
RESERVED
R/W
000
RESERVED
1
LDG LO ENABLE
R/W
0
0: Line output diagnostics are disabled
1: Line output diagnostics are enabled
0
LDG BYPASS
R/W
0
0: Automatic diagnostics when leaving Hi-Z and after 
channel fault
1: Diagnostics are not run automatically
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
47
Product Folder Links: TAS6424E-Q1

=== Page 48 ===
9.6.8 DC Load Diagnostic Control 2 Register (address = 0x0A) [default = 0x11]
The DC Diagnostic Control 2 register is shown in 图 9-21 and described in 表 9-17.
图 9-21. DC Load Diagnostic Control 2 Register
7
6
5
4
3
2
1
0
CH1 DC LDG SL
CH2 DC LDG SL
R/W-0001
R/W-0001
表 9-17. DC Load Diagnostics Control 2 Field Descriptions
Bit
Field
Type
Reset
Description
7–4
CH1 DC LDG SL
R/W
0001
DC load diagnostics shorted-load threshold
0000: 0.5 Ω
0001: 1 Ω
0010: 1.5 Ω
...
1001: 5 Ω
3–0
CH2 DC LDG SL
R/W
0001
DC load diagnostics shorted-load threshold
0000: 0.5 Ω
0001: 1 Ω
0010: 1.5 Ω
...
1001: 5 Ω
9.6.9 DC Load Diagnostic Control 3 Register (address = 0x0B) [default = 0x11]
The DC Diagnostic Control 3 register is shown in 图 9-22 and described in 表 9-18.
图 9-22. DC Load Diagnostic Control 3 Register
7
6
5
4
3
2
1
0
CH3 DC LDG SL
CH4 DC LDG SL
R/W-0001
R/W-0001
表 9-18. DC Load Diagnostics Control 3 Field Descriptions
Bit
Field
Type
Reset
Description
7–4
CH3 DC LDG SL
R/W
0001
DC load diagnostics shorted-load threshold
0000: 0.5 Ω
0001: 1 Ω
0010: 1.5 Ω
...
1001: 5 Ω
3–0
CH4 DC LDG SL
R/W
0001
DC load diagnostics shorted-load threshold
0000: 0.5 Ω
0001: 1 Ω
0010: 1.5 Ω
...
1001: 5 Ω
9.6.10 DC Load Diagnostic Report 1 Register (address = 0x0C) [default = 0x00]
DC Load Diagnostic Report 1 register is shown in 图 9-23 and described in 表 9-19.
图 9-23. DC Load Diagnostic Report 1 Register
7
6
5
4
3
2
1
0
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
48
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 49 ===
图 9-23. DC Load Diagnostic Report 1 Register (continued)
CH1 S2G
CH1 S2P
CH1 OL
CH1 SL
CH2 S2G
CH2 S2P
CH2 OL
CH2 SL
R-0
R-0
R-0
R-0
R-0
R-0
R-0
R-0
表 9-19. DC Load Diagnostics Report 1 Field Descriptions
Bit
Field
Type
Reset
Description
7
CH1 S2G
R
0
0: No short-to-GND detected
1: Short-To-GND Detected
6
CH1 S2P
R
0
0: No short-to-power detected
1: Short-to-power detected
5
CH1 OL
R
0
0: No open load detected
1: Open load detected
4
CH1 SL
R
0
0: No shorted load detected
1: Shorted load detected
3
CH2 S2G
R
0
0: No short-to-GND detected
1: Short-to-GND detected
2
CH2 S2P
R
0
0: No short-to-power detected
1: Short-to-power detected
1
CH2 OL
R
0
0: No open load detected
1: Open load detected
0
CH2 SL
R
0
0: No shorted load detected
1: Shorted load detected
9.6.11 DC Load Diagnostic Report 2 Register (address = 0x0D) [default = 0x00]
The DC Load Diagnostic Report 2 register is shown in 图 9-24 and described in 表 9-20.
图 9-24. DC Load Diagnostic Report 2 Register
7
6
5
4
3
2
1
0
CH3 S2G
CH3 S2P
CH3 OL
CH3 SL
CH4 S2G
CH4 S2P
CH4 OL
CH4 SL
R-0
R-0
R-0
R-0
R-0
R-0
R-0
R-0
表 9-20. DC Load Diagnostics Report 2 Field Descriptions
Bit
Field
Type
Reset
Description
7
CH3 S2G
R
0
0: No short-to-GND detected
1: Short-to-GND detected
6
CH3 S2P
R
0
0: No short-to-power detected
1: Short-to-power detected
5
CH3 OL
R
0
0: No open load detected
1: Open load detected
4
CH3 SL
R
0
0: No shorted load detected
1: Shorted load detected
3
CH4 S2G
R
0
0: No short-to-GND detected
1: Short-to-GND detected
2
CH4 S2P
R
0
0: No short-to-power detected
1: Short-to-power detected
1
CH4 OL
R
0
0: No open load detected
1: Open load detected
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
49
Product Folder Links: TAS6424E-Q1

=== Page 50 ===
表 9-20. DC Load Diagnostics Report 2 Field Descriptions (continued)
Bit
Field
Type
Reset
Description
0
CH4 SL
R
0
0: No shorted load detected
1: Shorted load detected
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
50
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 51 ===
9.6.12 DC Load Diagnostics Report 3 Line Output Register (address = 0x0E) [default = 0x00]
The DC Load Diagnostic Report, Line Output, register is shown in 图 9-25 and described in 表 9-21.
图 9-25. DC Load Diagnostics Report 3 Line Output Register
7
6
5
4
3
2
1
0
RESERVED
CH1 LO LDG
CH2 LO LDG
CH3 LO LDG
CH4 LO LDG
R-0000
R-0
R-0
R-0
R-0
表 9-21. DC Load Diagnostics Report 3 Line Output Field Descriptions
Bit
Field
Type
Reset
Description
7–4
RESERVED
R
0000
RESERVED
3
CH1 LO LDG
R
0
0: No line output detected on channel 1
1: Line output detected on channel 1
2
CH2 LO LDG
R
0
0: No line output detected on channel 2
1: Line output detected on channel 2
1
CH3 LO LDG
R
0
0: No line output detected on channel 3
1: Line output detected on channel 3
0
CH4 LO LDG
R
0
0: No line output detected on channel 4
1: Line output detected on channel 4
9.6.13 Channel State Reporting Register (address = 0x0F) [default = 0x55]
The Channel State Reporting register is shown in 图 9-26 and described in 表 9-22.
图 9-26. Channel State-Reporting Register
7
6
5
4
3
2
1
0
CH1 STATE REPORT
CH2 STATE REPORT
CH3 STATE REPORT
CH4 STATE REPORT
R-01
R-01
R-01
R-01
表 9-22. State-Reporting Field Descriptions
Bit
Field
Type
Reset
Description
7–6
CH1 STATE REPORT
R
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
5–4
CH2 STATE REPORT
R
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
3–2
CH3 STATE REPORT
R
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
1–0
CH4 STATE REPORT
R
01
00: PLAY
01: Hi-Z
10: MUTE
11: DC load diagnostics
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
51
Product Folder Links: TAS6424E-Q1

=== Page 52 ===
9.6.14 Channel Faults (Overcurrent, DC Detection) Register (address = 0x10) [default = 0x00]
The Channel Faults (overcurrent, DC detection) register is shown in 图 9-27 and described in 表 9-23.
图 9-27. Channel Faults Register
7
6
5
4
3
2
1
0
CH1 OC
CH2 OC
CH3 OC
CH4 OC
CH1 DC
CH2 DC
CH3 DC
CH4 DC
R-0
R-0
R-0
R-0
R-0
R-0
R-0
R-0
表 9-23. Channel Faults Field Descriptions
Bit
Field
Type
Reset
Description
7
CH1 OC
R
0
0: No overcurrent fault detected
1: Overcurrent fault detected
6
CH2 OC
R
0
0: No overcurrent fault detected
1: Overcurrent fault detected
5
CH3 OC
R
0
0: No overcurrent fault detected
1: Overcurrent fault detected
4
CH4 OC
R
0
0: No overcurrent fault detected
1: Overcurrent fault detected
3
CH1 DC
R
0
0: No DC fault detected
1: DC fault detected
2
CH2 DC
R
0
0: No DC fault detected
1: DC fault detected
1
CH3 DC
R
0
0: No DC fault detected
1: DC fault detected
0
CH4 DC
R
0
0: No DC fault detected
1: DC fault detected
9.6.15 Global Faults 1 Register (address = 0x11) [default = 0x00]
The Global Faults 1 register is shown in 图 9-28 and described in 表 9-24.
图 9-28. Global Faults 1 Register
7
6
5
4
3
2
1
0
RESERVED
INVALID 
CLOCK
PVDD OV
VBAT OV
PVDD UV
VBAT UV
R-0
R-0
R-0
R-0
R-0
表 9-24. Global Faults 1 Field Descriptions
Bit
Field
Type
Reset
Description
7–5
RESERVED
R
0
RESERVED
4
INVALID CLOCK
R
0
0: No clock fault detected
1: Clock fault detected
3
PVDD OV
R
0
0: No PVDD overvoltage fault detected
1: PVDD overvoltage fault detected
2
VBAT OV
R
0
0: No VBAT overvoltage fault detected
1: VBAT overvoltage fault detected
1
PVDD UV
R
0
0: No PVDD undervoltage fault detected
1: PVDD undervoltage fault detected
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
52
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 53 ===
表 9-24. Global Faults 1 Field Descriptions (continued)
Bit
Field
Type
Reset
Description
0
VBAT UV
R
0
0: No VBAT undervoltage fault detected
1: VBAT undervoltage fault detected
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
53
Product Folder Links: TAS6424E-Q1

=== Page 54 ===
9.6.16 Global Faults 2 Register (address = 0x12) [default = 0x00]
The Global Faults 2 register is shown in 图 9-29 and described in 表 9-25.
图 9-29. Global Faults 2 Register
7
6
5
4
3
2
1
0
RESERVED
OTSD
CH1 OTSD
CH2 OTSD
CH3 OTSD
CH4 OTSD
R-000
R-0
R-0
R-0
R-0
R-0
表 9-25. Global Faults 2 Field Descriptions
Bit
Field
Type
Reset
Description
7–5
RESERVED
R
000
RESERVED
4
OTSD
R
0
0: No global overtemperature shutdown
1: Global overtemperature shutdown
3
CH1 OTSD
R
0
0: No overtemperature shutdown on Ch1
1: Overtemperature shutdown on Ch1
2
CH2 OTSD
R
0
0: No overtemperature shutdown on Ch2
1: Overtemperature shutdown on Ch2
1
CH3 OTSD
R
0
0: No overtemperature shutdown on Ch3
1: Overtemperature shutdown on Ch3
0
CH4 OTSD
R
0
0: No overtemperature shutdown on Ch4
1: Overtemperature shutdown on Ch4
9.6.17 Warnings Register (address = 0x13) [default = 0x20]
The Warnings register is shown in 图 9-30 and described in 表 9-26.
图 9-30. Warnings Register
7
6
5
4
3
2
1
0
RESERVED
VDD POR
OTW
OTW CH1
OTW CH2
OTW CH3
OTW CH4
R-0
R-0
R-0
R-0
R-0
R-0
表 9-26. Warnings Field Descriptions
Bit
Field
Type
Reset
Description
7-6
RESERVED
R
0
RESERVED
5
VDD POR
R
0
0: No VDD POR has occurred
1 VDD POR occurred
4
OTW
R
0
0: No global overtemperature warning
1: Global overtemperature warning
3
OTW CH1
R
0
0: No overtemperature warning on channel 1
1: Overtemperature warning on channel 1
2
OTW CH2
R
0
0: No overtemperature warning on channel 2
1: Overtemperature warning on channel 2
1
OTW CH3
R
0
0: No overtemperature warning on channel 3
1: Overtemperature warning on channel 3
0
OTW CH4
R
0
0: No overtemperature warning on channel 4
1: Overtemperature warning on channel 4
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
54
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 55 ===
9.6.18 Pin Control Register (address = 0x14) [default = 0x00]
The Pin Control register is shown in 图 9-31 and described in 表 9-27.
图 9-31. Pin Control Register
7
6
5
4
3
2
1
0
MASK OC
MASK OTSD
MASK UV
MASK OV
MASK DC
RESERVED
MASK CLIP
MASK OTW
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
表 9-27. Pin Control Field Descriptions
Bit
Field
Type
Reset
Description
7
MASK OC
R/W
0
0: Report overcurrent faults on the FAULT pin
1: Do not report overcurrent faults on the FAULT Pin
6
MASK OTSD
R/W
0
0: Report overtemperature faults on the FAULT pin
1: Do not report overtemperature faults on the FAULT pin
5
MASK UV
R/W
0
0: Report undervoltage faults on the FAULT pin
1: Do not report undervoltage faults on the FAULT pin
4
MASK OV
R/W
0
0: Report overvoltage faults on the FAULT pin
1: Do not report overvoltage faults on the FAULT pin
3
MASK DC
R/W
0
0: Report DC faults on the FAULT pin
1: Do not report DC faults on the FAULT pin
2
RESERVED
R/W
0
RESERVED
1
MASK CLIP
R/W
0
0: Report clipping on the WARN pin
1: Do not report clipping on the WARN pin 0: Report clipping 
on the configured pin ( WARN or FAULT)
0
MASK OTW
R/W
0
0: Report overtemperature warnings on the WARN pin
1: Do not report overtemperature warnings on the WARN pin
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
55
Product Folder Links: TAS6424E-Q1

=== Page 56 ===
9.6.19 AC Load Diagnostic Control 1 Register (address = 0x15) [default = 0x00]
The AC Load Diagnostic Control 1 register is shown in 图 9-32 and described in 表 9-28.
图 9-32. AC Load Diagnostic Control 1 Register
7
6
5
4
3
2
1
0
CH1 GAIN
CH2 GAIN
CH3 GAIN
CH4 GAIN
CH1 ENABLE
CH2 ENABLE
CH3 ENABLE
CH4 ENABLE
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
表 9-28. AC Load Diagnostic Control 1 Field Descriptions
Bit
Field
Type
Reset
Description
7
CH1, PBTL12: GAIN
R/W
0
0: Gain 1
1: Gain 4
6
CH2 GAIN
R/W
0
0: Gain 1
1: Gain 4
5
CH3, CH4, PBTL34: GAIN
R/W
0
0: Gain 1
1: Gain 4
4
CH4 GAIN
R/W
0
0: Gain 1
1: Gain 4
3
CH1 ENABLE
R/W
0
0: AC diagnostics disabled
1: Enable AC diagnostics
2
CH2 ENABLE
R/W
0
0: AC diagnostics disabled
1: Enable AC diagnostics
1
CH3 ENABLE
R/W
0
0: AC diagnostics disabled
1: Enable AC diagnostics
0
CH4 ENABLE
R/W
0
0: AC diagnostics disabled
1: Enable AC diagnostics
9.6.20 AC Load Diagnostic Control 2 Register (address = 0x16) [default = 0x00]
The AC Load Diagnostic Control 2 register is shown in 图 9-33 and described in 表 9-29.
图 9-33. AC Load Diagnostic Control 2 Register
7
6
5
4
3
2
1
0
AC_DIAGS_LO
OPBACK
RESERVED
AC TIMING
AC CURRENT
RESERVED
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
表 9-29. AC Load Diagnostic Control 2 Field Descriptions
Bit
Field
Type
Reset
Description
7
AC_DIAGS_LOOPBACK
R/W
0
0: Disable AC Diag loopback
1: Enable AC Diag loopback
6-5
RESERVED
R/W
00
RESERVED
4
AC TIMING
R/W
0
0: 32 Cycles
1: 64 Cycles
3-2
AC CURRENT
R/W
00
00: 10mA
01: 19 mA
10: RESERVED
11: RESERVED
1-0
RESERVED
R/W
00
RESERVED
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
56
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 57 ===
9.6.21 AC Load Diagnostic Impedance Report Ch1 through Ch4 Registers (address = 0x17–0x1A) 
[default = 0x00]
The AC Load Diagnostic Report Ch1 through Ch4 registers are shown in 图 9-34 and described in 表 9-30.
图 9-34. AC Load Diagnostic Impedance Report Chx Register
7
6
5
4
3
2
1
0
CHx IMPEDANCE
R-00000000
表 9-30. Chx AC LDG Impedance Report Field Descriptions
Bit
Field
Type
Reset
Description
7–0
CH x IMPEDANCE
R
00000000
8-bit AC-load diagnostic report for each channel with a step size 
of 0.2496 Ω/bit (control by register 0x15 and register 0x16)
0x00: 0 Ω
0x01: 0.2496 Ω
...
0xFF: 63.65 Ω
9.6.22 AC Load Diagnostic Phase Report High Register (address = 0x1B) [default = 0x00]
The AC Load Diagnostic Phase High value registers are shown in 图 9-35 and described in 表 9-31.
图 9-35. AC Load Diagnostic (LDG) Phase High Report Register
7
6
5
4
3
2
1
0
AC Phase High
R-00000000
表 9-31. AC LDG Phase High Report Field Descriptions
Bit
Field
Type
Reset
Description
7–0
AC Phase High
R
00000000
Bit 15:8
9.6.23 AC Load Diagnostic Phase Report Low Register (address = 0x1C) [default = 0x00]
The AC Load Diagnostic Phase Low value registers are shown in 图 9-36 and described in 表 9-32.
图 9-36. AC Load Diagnostic (LDG) Phase Low Report Register
7
6
5
4
3
2
1
0
AC Phase Low
R-00000000
表 9-32. AC LDG Phase Low Report Field Descriptions
Bit
Field
Type
Reset
Description
7–0
AC Phase Low
R
00000000
Bit 7:0
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
57
Product Folder Links: TAS6424E-Q1

=== Page 58 ===
9.6.24 AC Load Diagnostic STI Report High Register (address = 0x1D) [default = 0x00]
The AC Load Diagnostic STI High value registers are shown in 图 9-37 and described in 表 9-33.
图 9-37. AC Load Diagnostic (LDG) STI High Report Register
7
6
5
4
3
2
1
0
AC STI High
R-00000000
表 9-33. AC LDG STI High Report Field Descriptions
Bit
Field
Type
Reset
Description
7–0
AC STI High
R
00000000
Bit 15:8
9.6.25 AC Load Diagnostic STI Report Low Register (address = 0x1E) [default = 0x00]
The AC Load Diagnostic STI Low value registers are shown in 图 9-38 and described in 表 9-34.
图 9-38. AC Load Diagnostic (LDG) STI Low Report Register
7
6
5
4
3
2
1
0
AC STI Low
R-00000000
表 9-34. Chx AC LDG STI Low Report Field Descriptions
Bit
Field
Type
Reset
Description
7–0
AC STI Low
R
00000000
Bit 7:0
9.6.26 Miscellaneous Control 3 Register (address = 0x21) [default = 0x00]
The Miscellaneous Control 3 register is shown in 图 9-39 and described in 表 9-35.
图 9-39. Miscellaneous Control 3 Register
7
6
5
4
3
2
1
0
CLEAR FAULT
PBTL_CH_SEL
MASK ILIMIT 
WARNING
RESERVED
OTSD AUTO 
RECOVERY
RESERVED
R/W-0
R/W-0
R/W-0
R/W-0
R/W-0
表 9-35. Misc Control 3 Field Descriptions
Bit
Field
Type
Reset
Description
7
CLEAR FAULT
R/W
0
0: Normal operation
1: Clear fault
6
PBTL_CH_SEL
R/W
0
0: PBTL normal signal source
1: PBTL flip signal source
5
RESERVED
R/W
0
RESERVED
4
RESERVED
R/W
0
RESERVED
3
OTSD AUTO RECOVERY
R/W
0
0: OTSD is latched
1: OTSD is autorecovery
2–0
RESERVED
0
RESERVED
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
58
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 59 ===
9.6.27 Clip Control Register (address = 0x22) [default = 0x01]
The Clip Detect register is shown in 图 9-40 and described in 表 9-36. To ensure the Clip Detect Warning is 
operating according to the expectation, the related bit values in the 节 9.6.28 and 节 9.6.29 must be set 
accordingly.
图 9-40. Clip Control Register
7
6
5
4
3
2
1
0
RESERVED
CLIP_PIN
CLIP_LATCH
CLIPDET_EN
R-00000
R/W-0
R/W-0
R/W-1
表 9-36. Clip Control Field Descriptions
Bit
Field
Type
Reset
Description
7-3
RESERVED
R
00000
RESERVED
2
CLIP_PIN
R/W
0
0: CH1-4 Clip Detect report to WARN pin
1: CH1-2 Clip Detect report to WARN pin, CH3-4 Clip Detect 
report to FAULT pin
1
CLIP_LATCH
R/W
0
0: Pin latching
1: Pin non-latching
0
CLIPDET_EN
R/W
1
0: Clip Detect disable
1: Clip Detect Enable
9.6.28 Clip Window Register (address = 0x23) [default = 0x14]
The Clip Window register is shown in 图 9-41 and described in 表 9-37. The register value represents the 
minimum number of 100% duty-cycle PWM cycles in hexadecimal notation before Clip Detect is reported.
图 9-41. Clip Window Register
7
6
5
4
3
2
1
0
CLIP_WINDOW_SEL[7:1]
R/W-00010100
表 9-37. Clip Window Field Descriptions
Bit
Field
Type
Reset
Description
7-0
CLIP_WINDOW_SEL[7:1]
R/W
00010100
00010100: 20-100% duty-cycle PWM cycles before Clip 
Detect is triggered
9.6.29 Clip Warning Register (address = 0x24) [default = 0x00]
The Clip Window register is shown in 图 9-42 and described in 表 9-38.
图 9-42. Clip Warning Register
7
6
5
4
3
2
1
0
RESERVED
CH4_CLIP
CH3_CLIP
CH2_CLIP
CH1_CLIP
R-0
R-0
R-0
R-0
表 9-38. Clip Warning Field Descriptions
Bit
Field
Type
Reset
Description
7-4
RESERVED
0
RESERVED
3
CH4_CLIP
R
0
0: No Clip Detect
1: Clip Detect
2
CH3_CLIP
R
0
0: No Clip Detect
1: Clip Detect
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
59
Product Folder Links: TAS6424E-Q1

=== Page 60 ===
表 9-38. Clip Warning Field Descriptions (continued)
Bit
Field
Type
Reset
Description
1
CH2_CLIP
R
0
0: No Clip Detect
1: Clip Detect
0
CH1_CLIP
R
0
0: No Clip Detect
1: Clip Detect
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
60
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 61 ===
9.6.30 ILIMIT Status Register (address = 0x25) [default = 0x00]
The ILIMIT Status register is shown in 图 9-43 and described in 表 9-39.
图 9-43. ILIMIT Status Register
7
6
5
4
3
2
1
0
RESERVED
CH4_ILIMIT_W
ARN
CH3_ILIMIT_W
ARN
CH2_ILIMIT_W
ARN
CH1_ILIMIT_W
ARN
R-0
R-0
R-0
R-0
表 9-39. ILIMIT Status Field Descriptions
Bit
Field
Type
Reset
Description
7-4
RESERVED
0
RESERVED
3
CH4_ILIMIT_WARN
R
0
0: No ILIMIT
1: ILIMIT Warning
2
CH3_ILIMIT_WARN
R
0
0: No ILIMIT
1: ILIMIT Warning
1
CH2_ILIMIT_WARN
R
0
0: No ILIMIT
1: ILIMIT Warning
0
CH1_ILIMIT_WARN
R
0
0: No ILIMIT
1: ILIMIT Warning
9.6.31 Miscellaneous Control 4 Register (address = 0x26) [default = 0x40]
The Miscellaneous Control 4 register is shown in 图 9-44 and described in 表 9-40.
图 9-44. Miscellaneous Control 4 Register
7
6
5
4
3
2
1
0
RESERVED
BCLK_INV
HPF_CORNER[2:0]
R/W-0100
R/W-0
R/W-000
表 9-40. Misc Control 4 Field Descriptions
Bit
Field
Type
Reset
Description
7-4
RESERVED
R/W
0100
RESERVED
3
BCLK_INV
R/W
0
0: All other MCLK/BCLK frequency / phase use cases
1: Inverted MCLK/BCLK phase relationship when MCLK/BCLK 
run at the same frequency
2-0
HPF_CORNER[2:0]
R/W
000
000: 3.7 Hz
001: 7.4 Hz
010: 15 Hz
011: 30 Hz
100: 59 Hz
101: 118 Hz
110: 235 Hz
111: 463 Hz
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
61
Product Folder Links: TAS6424E-Q1

=== Page 62 ===
9.6.32 Miscellaneous Control 5 Register (address = 0x28) [default = 0x0A]
The Miscellaneous Control 5 register is shown in and described in 表 9-41.
图 9-45. Miscellaneous Control 5 Register
7
6
5
4
3
2
1
0
SS_BW_SEL
SS_DIV2
PHASE_SEL
RESERVED
R/W-0
R/W-0
R/W-0
R/W-01010
表 9-41. Misc Control 5 Field Descriptions
Bit
Field
Type
Reset
Description
7
SS_BW_SEL
R/W
0
Spread Spectrum Bandwidth Selection. Must be set to "1" when 
Spread Spectrum is enabled.
0: Spread Spectrum disabled 
1: Spread Spectrum enabled
6
SS_DIV2
R/W
0
Spread Spectrum Post Divider Control. Must be set to "1" when 
Spread Spectrum is enabled.
0: Spread Spectrum disabled 
1: Spread Spectrum enabled
5
PHASE_SEL
R/W
0
WARNING: This bit must be set to '1' before exiting 
STANDBY. By default, this bit is set to '0', which is an output 
stage phase option not supported by this device.
0: RESERVED (default, must be changed to '1') 
1: Supported Phase Offsets
4-0
RESERVED
R/W
01010
RESERVED
9.6.33 Spread-Spectrum Control 1 Register (address = 0x77) [default = 0x00]
The Miscellaneous Control 5 register is shown in 图 9-46 and described in 表 9-42.
图 9-46. Spread-Spectrum Control Register
7
6
5
4
3
2
1
0
SS_EN
SS_AMPL
R/W-0
R/W-0000000
表 9-42. Spread-Spectrum Control Field Descriptions
Bit
Field
Type
Reset
Description
7
SS_EN
R/W
0
Spread-Spectrum Enable
0: Spread-Spectrum disabled.
1: Spread-Spectrum enabled.
6-0
SS_AMPL
R/W
0000000
Spread-Spectrum frequency variation control. Sets the minimum 
and maximum frequency boundaries used by the spread-
spectrum triangle waveform. See spread-spectrum section to 
calculate frequency variation.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
62
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 63 ===
9.6.34 Spread Spectrum Control 2 Register (address = 0x78) [default = 0x3F]
The Spread Spectrum Control 2 register is shown in 图 9-47 and described in 表 9-43.
图 9-47. Spread Spectrum Control 2 Register
7
6
5
4
3
2
1
0
RESERVED
SS_PRE_DIV[6:0]
R/W-0
R/W-0111111
表 9-43. Spread Spectrum Control 2 Field Descriptions
Bit
Field
Type
Reset
Description
7
RESERVED
R/W
0
RESERVED
6-0
SS_PRE_DIV
R/W
0111111
Pre-divider control for spread-spectrum. Sets the spread-
spectrum center frequency.
Fcenter = 256 * FS / (SS_PRE_DIV * 2 + 2) where FS is the audio 
sample rate.
For example, setting SS_PRE_DIV to 31 (0x1F) results in the 
SS center frequency equal to 256 * 48kHz divided by 64 
resulting in a Fcenter = 192kHz.
9.6.35 Spread Spectrum Control 3 Register (address = 0x79) [default = 0x00]
The Spread Spectrum Control 3 register is shown in 图 9-48 and described in 表 9-44.
图 9-48. Spread Spectrum Control 3 Register
7
6
5
4
3
2
1
0
SS_STEP[7:0]
R/W-00000000
表 9-44. Spread Spectrum Control 3 Field Descriptions
Bit
Field
Type
Reset
Description
7-0
SS_STEP[7:0]
R/W
00000000
Spread Spectrum frequency step size. See Spread-Spectrum 
section to calculate this register value.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
63
Product Folder Links: TAS6424E-Q1

=== Page 64 ===
10 Application and Implementation
Note
Information in the following applications sections is not part of the TI component specification, and TI 
does not warrant its accuracy or completeness. TI’s customers are responsible for determining 
suitability of components for their purposes. Customers should validate and test their design 
implementation to confirm system functionality.
10.1 Application Information
The TAS6424E-Q1 is a four-channel class-D digital-input audio-amplifier design for use in automotive head units 
and external amplifier modules. The TAS6424E-Q1 incorporates the necessary functionality to perform in 
demanding OEM applications.
10.1.1 AM-Radio Band Avoidance
AM-radio frequency interference can be avoided by setting the switching frequency of the device above the AM 
band. The switching frequency options available are 38 fs, 44 fs, and 48 fs. If the switch frequency cannot be set 
above the AM band, then use the two options of 8 fs and 10 fs. These options should be changed to avoid AM 
active channels.
10.1.2 Parallel BTL Operation (PBTL)
The device can drive more current-paralleling BTL channels on the load side of the LC output filter. For parallel 
operation, the parallel BTL mode, PBTL, must be used and the paralleled channels must have the same state in 
the state control register. If the two states are not aligned the device reports a fault condition.
To set the requested channels to PBTL mode the device must be in standby mode for the commands to take 
effect.
A load diagnostic is supported for PBTL channels. Paralleling on the device side of the LC output filter is not 
supported.
10.1.3 Demodulation Filter Design
The amplifier outputs are driven by high-current LDMOS transistors in an H-bridge configuration. These 
transistors are either fully off or fully on. The result is a square-wave output signal with a duty cycle that is 
proportional to the amplitude of the audio signal. An LC demodulation filter is used to recover the audio signal. 
The filter attenuates the high-frequency components of the output signals that are out of the audio band. The 
design of the demodulation filter significantly affects the audio performance of the power amplifier. Therefore, to 
meet the system THD+N requirements, the selection of the inductors used in the output filter should be carefully 
considered.
10.1.4 Line Driver Applications
In many automotive audio applications, the same head unit must drive either a speaker (with several ohms of 
impedance) or an external amplifier input (with several kΩ of impedance). The design is capable of supporting 
both applications and has special line-drive gain and diagnostics. Coupled with the high switching frequency, the 
device is well suited for this type of application. Set the desired channel in line driver mode through I2C register 
0x00, the externally connected amplifier must have a differential impedance from 600 Ω to 4.7 kΩ for the DC 
line diagnostic to detect the connected external amplifier. 图 10-1 shows the recommended external amplifier 
input configuration.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
64
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 65 ===
1 …F
External Amplifier
Output Filter
1 …F
1 …F
1 nF
100 k
100 k
600 
to
4.7 k
1 …F
1 nF
3.3 µH
3.3 µH
图 10-1. External Amplifier Input Configuration for Line Driver
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
65
Product Folder Links: TAS6424E-Q1

=== Page 66 ===
10.2 Typical Application
10.2.1 BTL Application
图 10-2 shows the schematic of a typical 4-channel solution for a head-unit application.
VBAT
PVDD
1 F
2
1
3
4
5
1 F
6
1 F
7
8
1 F
9
2.2 F
10
2.2 F11
17
18
19
2 k
2 k
20
21
22
23
24
25
26
27
28
Micro
13
14
15
16
12
DSP
VDD
VCOM
AVDD
I2C_ADDR0
I2C_ADDR1
SDA
SCL
SDIN1
SDIN2
SCLK
FSYNC
MCLK
STANDBY
MUTE
FAULT
WARN
AREF
VREG
GND
AVSS
GVDD
GVDD
GND
GND
GND
GND
PVDD
56
55
0.1 F
10 F
PVDD
PVDD
PVDD
43
42
0.1 F
10 F
PVDD
PVDD
PVDD
30
29
0.1 F
10 F
PVDD
PVDD
PVDD
36
GND
49
GND
OUT_4M
OUT_4P
BST_4M
1 F
54
BST_4P
53
1 F
1 nF
1 nF
1 F
52
51
50
1 F
3.3 H
3.3 H
GND
4  
OUT_3M
OUT_3P
BST_3M
1 F
48
BST_3P
47
1 F
1 nF
1 nF
1 F
46
45
44
1 F
3.3 H
3.3 H
GND
4  
OUT_2M
OUT_2P
BST_2M
1 F
41
BST_2P
40
1 F
1 nF
1 nF
1 F
39
38
37
1 F
3.3 H
3.3 H
GND
4  
OUT_1M
OUT_1P
BST_1M
1 F
35
BST_1P
34
1 F
1 nF
1 nF
1 F
33
32
31
1 F
3.3 H
3.3 H
GND
4  
PVDD
1 F
1 nF
470 F
PVDD
Input
VDD
1 uF
图 10-2. Typical 4-Channel BTL Application Schematic
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
66
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 67 ===
10.2.1.1 Design Requirements
Use the following requirements for this design:
•
This head-unit example is focused on the smallest solution size for 4 × 25 W output power into 4 Ω with a 
battery supply of 14.4 V.
•
The switching frequency is set above the AM-band with 44 times the input sample rate of 48 kHz which 
results in a frequency of 2.11 MHz.
•
The selection of a 2.11 MHz switch frequency enables the use of a small output inductor value of 3.3 µH 
which leads to a very small solution size.
10.2.1.1.1 Communication
All communications to the TAS6424E-Q1 are through the I2C protocol. A system controller can communicate 
with the device through the SDA pins and SCL pins. The device is an I2C secondary and requires a primary. The 
device cannot generate an I2C clock or initiate a transaction. The maximum clock speed accepted by the device 
is 400 kHz. If multiple TAS6424E-Q1devices are on the same I2C bus, the I2C address must be different for each 
device. Up to four TAS6424E-Q1 devices can be on the same I2C bus.
The I2C bus is shared internally.
Note
Complete any internal operations, such as load diagnostics, before reading the registers for the 
results.
10.2.1.2 Detailed Design Procedure
10.2.1.2.1 Hardware Design
Use the following procedure for the hardware design:
•
Determine the input format. The input format can be either I2S or TDM mode. The mode determines the 
correct pin connections and the I2C register settings.
•
Determine the power output that is required into the load. The power requirement determines the required 
power-supply voltage and current. The output reconstruction-filter components that are required are also 
driven by the output power.
•
With the requirements, adjust the typical application schematic in 图 10-2 for the input connections.
10.2.1.2.2 Digital Input and the Serial Audio Port
The TAS6424E-Q1 device supports four different digital input formats which are: I2S, Right Justified, Left 
Justified, and TDM mode. Depending on the format, the device can support 16, 18, 20, 24, and 32 bit data. The 
supported frequencies are 96 kHz, 48 kHz, and 44.1 kHz. See SAP Control (Serial Audio-Port Control) Register 
(address = 0x03) [default = 0x04] for the complete matrix to set up the serial audio port.
Note
Bits 3, 4, and 5 in this register are ignored in all input formats except for TDM. Setting up all the 
control registers to the system requirements should be done before the device is placed in Mute mode 
or Play mode. After the registers are setup, use bit 7 in register 0x21 to clear any faults. Then read the 
fault registers to make sure no faults are present. When no faults are present, use register 0x04 to 
place the device properly into play mode.
10.2.1.2.3 Bootstrap Capacitors
The bootstrap capacitors provide the gate-drive voltage of the upper N-channel FET. These capacitors must be 
sized appropriately for the system specification. A special condition can occur where the bootstrap may sag if the 
capacitor is not sized accordingly. The special condition is just below clipping where the PWM is slightly less 
than 100% duty cycle with sustained low-frequency signals. Changing the bootstrap capacitor value to 2.2 µF for 
driving subwoofers that require frequencies below 30 Hz may be necessary.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
67
Product Folder Links: TAS6424E-Q1

=== Page 68 ===
10.2.1.2.4 Output Reconstruction Filter
The output FETs drive the amplifier outputs in an H-Bridge configuration. These transistors are either fully off or 
fully on. The result is a square-wave output signal with a duty cycle that is proportional to the amplitude of the 
audio signal. The amplifier outputs require a reconstruction filter that comprises a series inductor and a capacitor 
to ground on each output, generally called an LC filter. The LC filter attenuates the PWM frequency and reduces 
electromagnetic emissions, allowing the reconstructed audio signal to pass to the speakers. refer to the Class-D 
LC Filter Design Application Report, (SLAA701A) for a detailed description of proper component description and 
design of the LC filter based upon the specified load and frequency response. The recommended low-pass 
cutoff frequency of the LC filter is dependent on the selected switching frequency. The low-pass cutoff frequency 
can be as high as 100 kHz for a PWM frequency of 2.1 MHz. At a PWM frequency of 384 kHz the low-pass 
cutoff frequency should be less than 40 kHz. Certain specifications must be understood for a proper inductor. 
The inductance value is given at zero current, but the device has current. Use the inductance versus current 
curve for the inductor to make sure the inductance does not drop below 1 µH (for fSW = 2.1 MHz) at the 
maximum current provided by the system design. The DCR of the inductor directly affects the output power of 
the system design. The lower the DCR, the more power is provided to the speakers. The typical inductor DCR 
for a 4 Ω system is 40 to 50 mΩ and for a 2 Ω system is 20 to 25 mΩ.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
68
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 69 ===
10.2.2 PBTL Application
图 10-3 shows a schematic of a typical 2-channel solution for a head unit or external amplifier application where 
high power into 2 Ω is required.
VBAT
PVDD
1 F
2
1
3
4
5
1 F
6
1 F
7
8
1 F
9
2.2 F
10
2.2 F11
19
2 k
2 k
20
21
22
23
24
25
26
27
28
Micro
13
14
15
16
12
DSP
VDD
VCOM
AVDD
I2C_ADDR0
I2C_ADDR1
SDA
SCL
SDIN1
SDIN2
SCLK
FSYNC
MCLK
STANDBY
MUTE
FAULT
WARN
AREF
VREG
GND
AVSS
GVDD
GVDD
GND
GND
PVDD
56
55
0.1 F
10 F
PVDD
PVDD
PVDD
43
42
0.1 F
10 F
PVDD
PVDD
PVDD
30
29
0.1 F
10 F
PVDD
PVDD
PVDD
36
GND
49
GND
OUT_4M
OUT_4P
BST_4M
1 F
54
BST_4P
53
1 F
1 nF
1 nF
1 F
52
51
50
1 F
3.3 H
3.3 H
GND
2  
OUT_3M
OUT_3P
BST_3M
1 F
48
BST_3P
47
1 F
1 F
46
45
44
1 F
3.3 H
3.3 H
GND
OUT_2M
OUT_2P
BST_2M
1 F
41
BST_2P
40
1 F
1 nF
1 nF
1 F
39
38
37
1 F
3.3 H
3.3 H
GND
2  
OUT_1M
OUT_1P
BST_1M
1 F
36
BST_1P
34
1 F
1 F
33
32
31
1 F
3.3 H
3.3 H
GND
18
GND
GND
PVDD
1 F
1 nF
470 F
PVDD
Input
1 uF
图 10-3. Typical 2-Channel PBTL Application Schematic
To operate in PBTL mode the output stage must be paralleled according to the schematic in 图 10-3. The device 
can operate in a mix of PBTL and BTL mode. This application can be set up for 3-channels, with one channel in 
PBTL mode and two channels in BTL mode. The device does not support a parallel configuration of all four 
channels for a one channel amplifier.
10.2.2.1 Design Requirements
Use the following requirements for this design:
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
69
Product Folder Links: TAS6424E-Q1

=== Page 70 ===
•
This head-unit example is focused on the smallest solution size for 2 x 50 W output power into 2 Ω with a 
battery supply of 14.4 V.
•
The switching frequency is set above the AM-band with 44 times the input sample rate of 48 kHz which 
results in a frequency of 2.11 MHz.
•
The selection of a 2.11 MHz switch frequency enables the use of a small output inductor value of 3.3 µH 
which leads to a very small solution size.
10.2.2.2 Detailed Design Procedure
As a starting point, refer to the Detailed Design Procedures section for the BTL application. PBTL mode requires 
schematic changes in the output stage as shown in 图 10-3. The other required changes include setting up the 
I2C registers correctly (see 表 9-13) and selecting which frame or channel to use on each output. Bit 6 in register 
0x21 controls the frame selection.
11 Power Supply Recommendations
The TAS6424E-Q1 requires three power supplies. The PVDD supply is the high-current supply in the 
recommended supply range. The VBAT supply is lower current supply that must be in the recommended supply 
range. The PVDD and VBAT pins can be connected to the same supply if the recommended supply range for 
VBAT is maintained. The VDD supply is the 3.3 Vdc logic supply and must be maintained in the tolerance as 
shown in the 节 7.2 table.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
70
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 71 ===
12 Layout
12.1 Layout Guidelines
The pinout of the TAS6424E-Q1 was selected to provide flowthrough layout with all high-power connections on 
the right side, and all low-power signals and supply decoupling on the left side.
图 12-1 shows the area for the components in the application example (see the 节 10.2 section).
The TAS6424E-Q1 EVM uses a four-layer PCB. The copper thickness was selected as 70 µm to optimize power 
loss.
The small value of the output filter provides a small size and, in this case, the low height of the inductor enables 
double-sided mounting.
The EVM PCB shown in 图 12-1 is the basis for the layout guidelines.
12.1.1 Electrical Connection of Thermal pad and Heat Sink
For the DKQ package, the heat sink connected to the thermal pad of the device should be connected to GND. 
The heat slug must not be connected to any other electrical node.
12.1.2 EMI Considerations
Automotive-level EMI performance depends on both careful integrated circuit design and good system-level 
design. Controlling sources of electromagnetic interference (EMI) was a major consideration in all aspects of the 
design. The design has minimal parasitic inductances because of the short leads on the package which reduces 
the EMI that results from current passing from the die to the system PCB. Each channel also operates at a 
different phase. The design also incorporates circuitry that optimizes output transitions that cause EMI.
For optimizing the EMI a solid ground layer plane is recommended, for a PCB design that fulfills the CISPR25 
level 5 requirements, see the TAS6424E-Q1 EVM layout.
12.1.3 General Guidelines
The EVM layout is optimized for low noise and EMC performance.
The TAS6424E-Q1 has an exposed thermal pad that is up, away from the PCB. The layout must consider an 
external heat sink.
Refer to 图 12-1 for the following guidelines:
•
A ground plane, A, on the same side as the device pins helps reduce EMI by providing a very-low loop 
impedance for the high-frequency switching current.
•
The decoupling capacitors on PVDD, B, are very close to the device with the ground return close to the 
ground pins.
•
The ground connections for the capacitors in the LC filter, C, have a direct path back to the device and also 
the ground return for each channel is the shared. This direct path allows for improved common mode EMI 
rejection.
•
The traces from the output pins to the inductors, D, should have the shortest trace possible to allow for the 
smallest loop of large switching currents.
•
Heat-sink mounting screws, E, should be close to the device to keep the loop short from the package to 
ground.
•
Many vias, F, stitching together the ground planes can create a shield to isolate the amplifier and power 
supply.
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
71
Product Folder Links: TAS6424E-Q1

=== Page 72 ===
12.2 Layout Example
Power Supply 
and
Amplifier 
Section
A
D
C
B
E
F
图 12-1. EVM Layout
12.3 Thermal Considerations
The thermally enhanced PowerPAD package has an exposed pad up for connection to a heat sink. The output 
power of any amplifier is determined by the thermal performance of the amplifier as well as limitations placed on 
it by the system, such as the ambient operating temperature. The heat sink absorbs heat from the TAS6424E-Q1 
and transfers it to the air. With proper thermal management this process can reach equilibrium and heat can be 
continually transferred from the device. Heat sinks can be smaller than that of classic linear amplifier design 
because of the excellent efficiency of class-D amplifiers. This device is intended for use with a heat sink, 
therefore, RθJC is used as the thermal resistance from junction to the exposed metal package. This resistance 
dominates the thermal management, so other thermal transfers is not considered. The thermal resistance of 
RθJA (junction to ambient) is required to determine the full thermal solution. The thermal resistance is comprised 
of the following components:
•
RθJC of the TAS6424E-Q1
•
Thermal resistance of the thermal interface material
•
Thermal resistance of the heat sink
The thermal resistance of the thermal interface material can be determined from the manufacturer’s value for 
the area thermal resistance (expressed in °Cmm2/W) and the area of the exposed metal package. For example, 
a typical, white, thermal grease with a 0.0254 mm (0.001 inch) thick layer is approximately 4.52°C mm2/W. The 
TAS6424E-Q1 in the DKQ package has an exposed area of 47.6 mm2. By dividing the area thermal resistance 
by the exposed metal area determines the thermal resistance for the thermal grease. The thermal resistance of 
the thermal grease is 0.094°C/W
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
72
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 73 ===
表 12-1 lists the modeling parameters for one device on a heat sink. The junction temperature is assumed to be 
115°C while delivering and average power of 10 watts per channel into a 4 Ω load. The thermal-grease example 
previously described is used for the thermal interface material. Use 方程式 3 to design the thermal system.
RθJA = RθJC + thermal interface resistance + heat sink resistance
(3)
表 12-1. Thermal Modeling
Description
Value
Ambient Temperature
25°C
Average Power to load
40W (4 x 10W)
Power dissipation
8W (4 x 2W)
Junction Temperature
115°C
ΔT inside package
5.6°C (0.7°C/W × 8W)
ΔT through thermal interface material
0.75°C (0.094°C/W × 8W)
Required heat sink thermal resistance
10.45°C/W ([115°C – 25°C – 5.6°C – 0.75°C] / 8W)
System thermal resistance to ambient RθJA
11.24°C/W
www.ti.com.cn
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
Copyright © 2022 Texas Instruments Incorporated
Submit Document Feedback
73
Product Folder Links: TAS6424E-Q1

=== Page 74 ===
13 Device and Documentation Support
13.1 Documentation Support
13.1.1 Related Documentation
For related documentation see the following:
•
PurePath™ Console 3 Graphical Development Suite
•
TAS6424E-Q1 EVM User's Guide (SLOU553)
13.2 接收文档更新通知
要接收文档更新通知，请导航至 ti.com 上的器件产品文件夹。点击订阅更新 进行注册，即可每周接收产品信息更
改摘要。有关更改的详细信息，请查看任何已修订文档中包含的修订历史记录。
13.3 支持资源
TI E2E™ 支持论坛是工程师的重要参考资料，可直接从专家获得快速、经过验证的解答和设计帮助。搜索现有解
答或提出自己的问题可获得所需的快速设计帮助。
链接的内容由各个贡献者“按原样”提供。这些内容并不构成 TI 技术规范，并且不一定反映 TI 的观点；请参阅 
TI 的《使用条款》。
13.4 Trademarks
PurePath™ is a trademark of Texas Instruments.
TI E2E™ is a trademark of Texas Instruments.
所有商标均为其各自所有者的财产。
13.5 Electrostatic Discharge Caution
This integrated circuit can be damaged by ESD. Texas Instruments recommends that all integrated circuits be handled 
with appropriate precautions. Failure to observe proper handling and installation procedures can cause damage.
ESD damage can range from subtle performance degradation to complete device failure. Precision integrated circuits may 
be more susceptible to damage because very small parametric changes could cause the device not to meet its published 
specifications.
13.6 术语表
TI 术语表 
本术语表列出并解释了术语、首字母缩略词和定义。
14 Mechanical, Packaging, and Orderable Information
The following pages include mechanical, packaging, and orderable information. This information is the most 
current data available for the designated devices. This data is subject to change without notice and revision of 
this document. For browser-based versions of this data sheet, refer to the left-hand navigation.
TAS6424E-Q1
ZHCSO75A – JUNE 2021 – REVISED NOVEMBER 2021
www.ti.com.cn
74
Submit Document Feedback
Copyright © 2022 Texas Instruments Incorporated
Product Folder Links: TAS6424E-Q1

=== Page 75 ===
PACKAGE OPTION ADDENDUM
www.ti.com
9-Nov-2025
PACKAGING INFORMATION
Orderable part number
Status
(1)
Material type
(2)
Package | Pins
Package qty | Carrier
RoHS
(3)
Lead finish/
Ball material
(4)
MSL rating/
Peak reflow
(5)
Op temp (°C)
Part marking
(6)
TAS6424EQDKQRQ1
Active
Production
HSSOP (DKQ) | 56
1000 | LARGE T&R
Yes
NIPDAU
Level-3-260C-168 HR
-40 to 125
TAS
6424E
TAS6424EQDKQRQ1.A
Active
Production
HSSOP (DKQ) | 56
1000 | LARGE T&R
Yes
NIPDAU
Level-3-260C-168 HR
-40 to 125
TAS
6424E
TAS6424EQDKQRQ1.B
Active
Production
HSSOP (DKQ) | 56
1000 | LARGE T&R
Yes
NIPDAU
Level-3-260C-168 HR
-40 to 125
TAS
6424E
 
(1) Status:  For more details on status, see our product life cycle.
 
(2) Material type:  When designated, preproduction parts are prototypes/experimental devices, and are not yet approved or released for full production. Testing and final process, including without limitation quality assurance,
reliability performance testing, and/or process qualification, may not yet be complete, and this item is subject to further changes or possible discontinuation. If available for ordering, purchases will be subject to an additional
waiver at checkout, and are intended for early internal evaluation purposes only. These items are sold without warranties of any kind.
 
(3) RoHS values:  Yes, No, RoHS Exempt. See the TI RoHS Statement for additional information and value definition.
 
(4) Lead finish/Ball material:  Parts may have multiple material finish options. Finish options are separated by a vertical ruled line. Lead finish/Ball material values may wrap to two lines if the finish value exceeds the maximum
column width.
 
(5) MSL rating/Peak reflow:  The moisture sensitivity level ratings and peak solder (reflow) temperatures. In the event that a part has multiple moisture sensitivity ratings, only the lowest level per JEDEC standards is shown.
Refer to the shipping label for the actual reflow temperature that will be used to mount the part to the printed circuit board.
 
(6) Part marking:  There may be an additional marking, which relates to the logo, the lot trace code information, or the environmental category of the part.
 
Multiple part markings will be inside parentheses. Only one part marking contained in parentheses and separated by a "~" will appear on a part. If a line is indented then it is a continuation of the previous line and the two
combined represent the entire part marking for that device.
 
Important Information and Disclaimer:The information provided on this page represents TI's knowledge and belief as of the date that it is provided. TI bases its knowledge and belief on information provided by third parties, and
makes no representation or warranty as to the accuracy of such information. Efforts are underway to better integrate information from third parties. TI has taken and continues to take reasonable steps to provide representative
and accurate information but may not have conducted destructive testing or chemical analysis on incoming materials and chemicals. TI and TI suppliers consider certain information to be proprietary, and thus CAS numbers
and other limited information may not be available for release.
 
In no event shall TI's liability arising out of such information exceed the total purchase price of the TI part(s) at issue in this document sold by TI to Customer on an annual basis.
 
Addendum-Page 1

=== Page 76 ===
PACKAGE MATERIALS INFORMATION
 
 
www.ti.com
24-Jul-2025
TAPE AND REEL INFORMATION
Reel Width (W1)
REEL DIMENSIONS
A0
B0
K0
W
Dimension designed to accommodate the component length
Dimension designed to accommodate the component thickness
Overall width of the carrier tape
Pitch between successive cavity centers
Dimension designed to accommodate the component width
TAPE DIMENSIONS
K0
 P1
B0 W
A0
Cavity
QUADRANT ASSIGNMENTS FOR PIN 1 ORIENTATION IN TAPE
Pocket Quadrants
Sprocket Holes
Q1
Q1
Q2
Q2
Q3
Q3
Q4
Q4
User Direction of Feed
P1
Reel
Diameter
 
*All dimensions are nominal
Device
Package
Type
Package
Drawing
Pins
SPQ
Reel
Diameter
(mm)
Reel
Width
W1 (mm)
A0
(mm)
B0
(mm)
K0
(mm)
P1
(mm)
W
(mm)
Pin1
Quadrant
TAS6424EQDKQRQ1
HSSOP
DKQ
56
1000
330.0
32.4
11.35
18.67
3.1
16.0
32.0
Q1
Pack Materials-Page 1

=== Page 77 ===
PACKAGE MATERIALS INFORMATION
 
 
www.ti.com
24-Jul-2025
TAPE AND REEL BOX DIMENSIONS
Width (mm)
W
L
H
 
*All dimensions are nominal
Device
Package Type
Package Drawing
Pins
SPQ
Length (mm)
Width (mm)
Height (mm)
TAS6424EQDKQRQ1
HSSOP
DKQ
56
1000
356.0
356.0
53.0
Pack Materials-Page 2

=== Page 78 ===
重要通知和免责声明
TI“按原样”提供技术和可靠性数据（包括数据表）、设计资源（包括参考设计）、应用或其他设计建议、网络工具、安全信息和其他资源，不
保证没有瑕疵且不做出任何明示或暗示的担保，包括但不限于对适销性、与某特定用途的适用性或不侵犯任何第三方知识产权的暗示担保。
这些资源可供使用 TI 产品进行设计的熟练开发人员使用。您将自行承担以下全部责任：(1) 针对您的应用选择合适的 TI 产品，(2) 设计、验
证并测试您的应用，(3) 确保您的应用满足相应标准以及任何其他安全、安保法规或其他要求。
这些资源如有变更，恕不另行通知。TI 授权您仅可将这些资源用于研发本资源所述的 TI 产品的相关应用。严禁以其他方式对这些资源进行复
制或展示。您无权使用任何其他 TI 知识产权或任何第三方知识产权。对于因您对这些资源的使用而对 TI 及其代表造成的任何索赔、损害、
成本、损失和债务，您将全额赔偿，TI 对此概不负责。
TI 提供的产品受 TI 销售条款)、TI 通用质量指南 或 ti.com 上其他适用条款或 TI 产品随附的其他适用条款的约束。TI 提供这些资源并不会扩
展或以其他方式更改 TI 针对 TI 产品发布的适用的担保或担保免责声明。 除非德州仪器 (TI) 明确将某产品指定为定制产品或客户特定产品，
否则其产品均为按确定价格收入目录的标准通用器件。
TI 反对并拒绝您可能提出的任何其他或不同的条款。
IMPORTANT NOTICE
版权所有 © 2025，德州仪器 (TI) 公司
最后更新日期：2025 年 10 月
