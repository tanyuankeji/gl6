# TAS6424E-Q1 寄存器映射详细设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-14  
> **状态**: 待审核  
> **关联文档**: `architecture_design_v2.md`，基于datasheet §9.6

---

## 1. 寄存器设计原则

### 1.1 分类与访问权限

| 分类 | 类型标记 | I2C读 | I2C写 | 硬件写 | 说明 |
|------|---------|-------|-------|--------|------|
| 配置寄存器 | R/W | ✓ | ✓ | ✗ | MCU通过I2C写入配置 |
| 状态/报告寄存器 | R | ✓ | ✗ | ✓ | 硬件写入结果，MCU只读 |
| 保留寄存器 | — | ✓ (0) | ✗ | ✗ | 读返回0，写忽略 |

### 1.2 特殊处理

| 特性 | 寄存器 | 行为 |
|------|--------|------|
| 自清除位 | 0x00 bit7 (RESET) | 写入1后下一周期自动回0 |
| 脉冲型位 | 0x21 bit7 (CLEAR_FAULT) | 写入1产生脉冲，自清除 |
| 写1清除 | 0x24 (Clip Warning) | 写入1清除对应位 |
| 保留位 | 各寄存器 | 写忽略，读返回0 |
| I2C地址自增 | — | 顺序读写时自动递增子地址 |

---

## 2. 寄存器完整定义

### 2.1 寄存器 0x00 — 模式控制 (Mode Control)

**默认值**: 0x00 | **访问**: R/W

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7 | RESET | 0 | 0: 正常运行; 1: 软件复位 (自清除) |
| 6 | RESERVED | 0 | 保留 |
| 5 | PBTL CH34 | 0 | 0: CH3/4 BTL模式; 1: CH3/4 PBTL并行模式 |
| 4 | PBTL CH12 | 0 | 0: CH1/2 BTL模式; 1: CH1/2 PBTL并行模式 |
| 3 | CH1 LO MODE | 0 | 0: 正常/扬声器模式; 1: 线路输出模式 |
| 2 | CH2 LO MODE | 0 | 0: 正常/扬声器模式; 1: 线路输出模式 |
| 1 | CH3 LO MODE | 0 | 0: 正常/扬声器模式; 1: 线路输出模式 |
| 0 | CH4 LO MODE | 0 | 0: 正常/扬声器模式; 1: 线路输出模式 |

**RTL连接**:
- `soft_reset` = reg_00[7] → 自清除脉冲
- `pbtl_ch12` = reg_00[4] → pwm_generator (输出级配置)
- `pbtl_ch34` = reg_00[5] → pwm_generator (输出级配置)
- `lo_mode[3:0]` = reg_00[3:0] → 预留 (诊断阈值调整)

---

### 2.2 寄存器 0x01 — 杂项控制1 (Miscellaneous Control 1)

**默认值**: 0x32 | **访问**: R/W

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7 | HPF BYPASS | 0 | 0: 高通滤波器使能; 1: 禁用 |
| 6-5 | OTW CONTROL | 01 | 00: 140°C; 01: 130°C; 10: 120°C; 11: 110°C |
| 4 | OC CONTROL | 1 | 0: 过流Level 1 (4.8A); 1: 过流Level 2 (7.2A) |
| 3-2 | VOLUME RATE | 00 | 00: 1step/FSYNC; 01: 1step/2FSYNC; 10: 1step/4FSYNC; 11: 1step/8FSYNC |
| 1-0 | GAIN | 10 | 00: 7.5V; 01: 15V; 10: 21V; 11: 29V (峰值输出电压) |

**RTL连接**:
- `hpf_bypass` = reg_01[7] → audio_interface (DC blocking)
- `oc_level` = reg_01[4] → fault_monitor (过流阈值选择)
- `gain[1:0]` = reg_01[1:0] → pwm_generator (增益/缩放)
- `otw_threshold` = reg_01[6:5] → (仅用于文档记录，模拟域)

---

### 2.3 寄存器 0x02 — 杂项控制2 (Miscellaneous Control 2)

**默认值**: 0x62 | **访问**: R/W

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7 | RESERVED | 0 | 保留 |
| 6-4 | PWM FREQUENCY | 110 | 000: 8×fs; 001: 10×fs; 101: 38×fs; 110: 44×fs; 111: 48×fs (其他保留) |
| 3 | RESERVED | 0 | 保留 |
| 2 | SDM_OSR | 0 | 0: 64x OSR; 1: 128x OSR |
| 1-0 | OUTPUT PHASE [1:0] | 10 | LSB 2位, MSB在0x28 bit5 (必须设为101/110/111) |

**RTL连接**:
- `pwm_freq[2:0]` = reg_02[6:4] → pwm_generator (载波频率)
- `output_phase[2:0]` = {reg_28[5], reg_02[1:0]} → pwm_generator (相位偏移)
- `sdm_osr` = reg_02[2] → 预留 (Sigma-Delta过采样)

**PWM频率编码** (datasheet 表9-3):

| reg_02[6:4] | 44.1kHz | 48kHz | 96kHz |
|-------------|---------|-------|-------|
| 000 | 352.8k | 384k | 384k |
| 001 | 441k | 480k | 480k |
| 101 | 1.68M | 1.82M | 1.82M |
| 110 (default) | 1.94M | 2.11M | 2.11M |
| 111 | 2.12M | N/A | N/A |

**相位编码** {reg_28[5], reg_02[1:0]}:

| 编码 | CH1 | CH2 | CH3 | CH4 |
|------|-----|-----|-----|-----|
| 101 | 0° | 210° | 60° | 270° |
| 110 | 0° | 225° | 90° | 315° |
| 111 | 0° | 240° | 120° | 360° |

> ⚠ **重要**: reg_28[5]必须设为1（默认0=不支持），否则相位模式无效

---

### 2.4 寄存器 0x03 — 串行音频端口控制 (SAP Control)

**默认值**: 0x04 | **访问**: R/W

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7-6 | INPUT SAMPLING RATE | 00 | 00: 44.1kHz; 01: 48kHz; 10: 96kHz; 11: 保留 |
| 5 | 8Ch TDM SLOT SELECT | 0 | 0: 前4个TDM时隙; 1: 后4个TDM时隙 |
| 4 | TDM SLOT SIZE | 0 | 0: 24/32-bit; 1: 16-bit |
| 3 | TDM SLOT SELECT 2 | 0 | 0: 正常; 1: 交换 (参见datasheet 表9-1) |
| 2-0 | INPUT FORMAT | 100 | 000: RJ24; 001: RJ20; 010: RJ18; 011: RJ16; 100: I2S; 101: LJ; 110: DSP; 111: 保留 |

**RTL连接**:
- `fs_sample[1:0]` = reg_03[7:6] → audio_interface (采样率)
- `tdm_slot_sel` = reg_03[5] → audio_interface (TDM时隙)
- `tdm_slot_size` = reg_03[4] → audio_interface (16/24/32bit)
- `tdm_swap` = reg_03[3] → audio_interface
- `sap_mode[2:0]` = reg_03[2:0] → audio_interface (格式选择)

---

### 2.5 寄存器 0x04 — 通道状态控制 (Channel State Control)

**默认值**: 0x55 (所有通道Hi-Z) | **访问**: R/W

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7-6 | CH1 STATE CONTROL | 01 | 00: PLAY; 01: Hi-Z; 10: MUTE; 11: DC诊断 |
| 5-4 | CH2 STATE CONTROL | 01 | 同上 |
| 3-2 | CH3 STATE CONTROL | 01 | 同上 |
| 1-0 | CH4 STATE CONTROL | 01 | 同上 |

**RTL连接**:
- `ch_state_req[1:0] × 4` → state_machine + channel_fsm × 4

---

### 2.6 寄存器 0x05-0x08 — 通道1~4音量控制

**默认值**: 0xCF (0dB) | **访问**: R/W

| Bit | 名称 | 描述 |
|-----|------|------|
| 7-0 | CHx VOLUME | 8位音量控制, 0.5dB/step:  0xFF=+24dB, 0xCF=0dB, 0x07=-100dB, <0x07=MUTE |

**RTL连接**: `ch_vol[7:0] × 4` → 预留（音量缩放模块）

---

### 2.7 寄存器 0x09-0x0B — DC诊断控制

**0x09 — DC Load Diagnostic Control 1** (默认: 0x00)

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7 | DC LDG ABORT | 0 | 1: 中止诊断 |
| 6 | 2x_RAMP | 0 | 1: 加倍斜升时间 |
| 5 | 2x_SETTLE | 0 | 1: 加倍稳定时间 |
| 4-2 | RESERVED | 000 | 保留 |
| 1 | LDG LO ENABLE | 0 | 1: 使能线路输出诊断 |
| 0 | LDG BYPASS | 0 | 1: 不自动运行诊断 (需手动触发) |

**0x0A — DC Load Diagnostic Control 2** (默认: 0x11)

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7-4 | CH1 DC LDG SL | 0001 | CH1短路负载阈值 (0.5Ω/step, 0000=0.5Ω ~ 1001=5Ω) |
| 3-0 | CH2 DC LDG SL | 0001 | CH2短路负载阈值 |

**0x0B — DC Load Diagnostic Control 3** (默认: 0x11)

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7-4 | CH3 DC LDG SL | 0001 | CH3短路负载阈值 |
| 3-0 | CH4 DC LDG SL | 0001 | CH4短路负载阈值 |

**RTL连接**: `dc_diag_ctrl` → diagnostic_ctrl

---

### 2.8 寄存器 0x0C-0x0E — DC诊断报告 (只读)

**0x0C — DC Load Diagnostic Report 1** (CH1/CH2) (默认: 0x00, 硬件写入)

| Bit | 名称 | 含义=1 |
|-----|------|--------|
| 7 | CH1 S2G | CH1 对地短路 |
| 6 | CH1 S2P | CH1 对电源短路 |
| 5 | CH1 OL | CH1 开路 |
| 4 | CH1 SL | CH1 负载短路 |
| 3 | CH2 S2G | CH2 对地短路 |
| 2 | CH2 S2P | CH2 对电源短路 |
| 1 | CH2 OL | CH2 开路 |
| 0 | CH2 SL | CH2 负载短路 |

**0x0D — DC Load Diagnostic Report 2** (CH3/CH4) — 同上格式

**0x0E — DC Load Diagnostic Report 3** (Line Output) (默认: 0x00)

| Bit | 名称 | 含义 |
|-----|------|------|
| 7-4 | RESERVED | 0000 |
| 3 | CH1 LO LDG | CH1检测到线路输出 |
| 2 | CH2 LO LDG | CH2检测到线路输出 |
| 1 | CH3 LO LDG | CH3检测到线路输出 |
| 0 | CH4 LO LDG | CH4检测到线路输出 |

---

### 2.9 寄存器 0x0F — 通道状态报告 (Channel State Reporting)

**默认值**: 0x55 | **访问**: R (硬件写入)

| Bit | 名称 | 编码 |
|-----|------|------|
| 7-6 | CH1 STATE REPORT | 00=PLAY, 01=Hi-Z, 10=MUTE, 11=DC诊断 |
| 5-4 | CH2 STATE REPORT | 同上 |
| 3-2 | CH3 STATE REPORT | 同上 |
| 1-0 | CH4 STATE REPORT | 同上 |

**来源**: 顶层组装 channel_fsm × 4 的 `ch_state[1:0]` 输出

---

### 2.10 寄存器 0x10 — 通道故障 (Channel Faults)

**默认值**: 0x00 | **访问**: R (硬件写入)

| Bit | 名称 | 含义 |
|-----|------|------|
| 7 | CH1 OC | CH1过流关断 |
| 6 | CH2 OC | CH2过流关断 |
| 5 | CH3 OC | CH3过流关断 |
| 4 | CH4 OC | CH4过流关断 |
| 3 | CH1 DC | CH1直流检测 |
| 2 | CH2 DC | CH2直流检测 |
| 1 | CH3 DC | CH3直流检测 |
| 0 | CH4 DC | CH4直流检测 |

**来源**: fault_monitor → 通道故障锁存

**清除**: 写 CLEAR_FAULT (0x21 bit7=1)

---

### 2.11 寄存器 0x11 — 全局故障1 (Global Faults 1)

**默认值**: 0x00 | **访问**: R (硬件写入)

| Bit | 名称 | 含义 |
|-----|------|------|
| 7-5 | RESERVED | 000 |
| 4 | INVALID CLOCK | 时钟错误检测 |
| 3 | PVDD OV | PVDD过压 |
| 2 | VBAT OV | VBAT过压 |
| 1 | PVDD UV | PVDD欠压 |
| 0 | VBAT UV | VBAT欠压 |

**来源**: fault_monitor + clock_monitor  
**清除**: 写 CLEAR_FAULT (0x21 bit7=1)

---

### 2.12 寄存器 0x12 — 全局故障2 (Global Faults 2)

**默认值**: 0x00 | **访问**: R (硬件写入)

| Bit | 名称 | 含义 |
|-----|------|------|
| 7-5 | RESERVED | 000 |
| 4 | OTSD | 全局过温关断 |
| 3 | CH1 OTSD | CH1过温关断 |
| 2 | CH2 OTSD | CH2过温关断 |
| 1 | CH3 OTSD | CH3过温关断 |
| 0 | CH4 OTSD | CH4过温关断 |

**来源**: fault_monitor (经protection去毛刺)

---

### 2.13 寄存器 0x13 — 警告 (Warnings)

**默认值**: 0x00 (复位后写0x20? 参考默认值表) | **访问**: R (硬件写入)

| Bit | 名称 | 含义 |
|-----|------|------|
| 7-6 | RESERVED | 00 |
| 5 | VDD POR | VDD上电复位已发生 |
| 4 | OTW | 全局过温警告 |
| 3 | OTW CH1 | CH1过温警告 |
| 2 | OTW CH2 | CH2过温警告 |
| 1 | OTW CH3 | CH3过温警告 |
| 0 | OTW CH4 | CH4过温警告 |

---

### 2.14 寄存器 0x14 — 引脚控制 (Pin Control)

**默认值**: 0x00 | **访问**: R/W

| Bit | 名称 | 描述 (设为1时) |
|-----|------|--------------|
| 7 | MASK OC | 不在FAULT引脚上报过流故障 |
| 6 | MASK OTSD | 不在FAULT引脚上报过温故障 |
| 5 | MASK UV | 不在FAULT引脚上报欠压故障 |
| 4 | MASK OV | 不在FAULT引脚上报过压故障 |
| 3 | MASK DC | 不在FAULT引脚上报DC故障 |
| 2 | RESERVED | 保留 |
| 1 | MASK CLIP | 不在WARN引脚上报削波 |
| 0 | MASK OTW | 不在WARN引脚上报过温警告 |

**RTL连接**: `pin_mask[7:0]` → pin_control (仅掩蔽引脚输出，不掩蔽寄存器报告)

---

### 2.15 寄存器 0x15-0x16 — AC诊断控制

**0x15 — AC Load Diagnostic Control 1** (默认: 0x00)

| Bit | 名称 | 描述 |
|-----|------|------|
| 7 | CH1 GAIN | 0: Gain=1; 1: Gain=4 (PBTL12共用) |
| 6 | CH2 GAIN | 同上 |
| 5 | CH3 GAIN | 同上 (PBTL34共用) |
| 4 | CH4 GAIN | 同上 |
| 3 | CH1 ENABLE | 1: 使能CH1 AC诊断 |
| 2 | CH2 ENABLE | 1: 使能CH2 AC诊断 |
| 1 | CH3 ENABLE | 1: 使能CH3 AC诊断 |
| 0 | CH4 ENABLE | 1: 使能CH4 AC诊断 |

**0x16 — AC Load Diagnostic Control 2** (默认: 0x00)

| Bit | 名称 | 描述 |
|-----|------|------|
| 7 | AC_DIAGS_LOOPBACK | 0: 正常; 1: 内部环回模式 |
| 6-4 | RESERVED | 000 |
| 3-2 | AC TIMING | 诊断时序选择 |
| 1 | AC CURRENT | 0: 10mA; 1: 19mA |
| 0 | RESERVED | 0 |

**RTL连接**: `ac_diag_ctrl` → diagnostic_ctrl

---

### 2.16 寄存器 0x17-0x1E — AC诊断报告 (只读)

| 地址 | 名称 | 描述 |
|------|------|------|
| 0x17 | AC LDG RPT CH1 | CH1 AC诊断阻抗 |
| 0x18 | AC LDG RPT CH2 | CH2 AC诊断阻抗 |
| 0x19 | AC LDG RPT CH3 | CH3 AC诊断阻抗 |
| 0x1A | AC LDG RPT CH4 | CH4 AC诊断阻抗 |
| 0x1B | AC LDG PHASE HIGH | AC诊断相位高字节 |
| 0x1C | AC LDG PHASE LOW | AC诊断相位低字节 |
| 0x1D | AC LDG STI HIGH | AC诊断刺激值高字节 |
| 0x1E | AC LDG STI LOW | AC诊断刺激值低字节 |

---

### 2.17 寄存器 0x21 — 杂项控制3 (重要)

**默认值**: 0x00 | **访问**: R/W

| Bit | 名称 | 复位 | 描述 |
|-----|------|------|------|
| 7 | CLEAR FAULT | 0 | 1: 清除所有锁存故障 (自清除) |
| 6 | PBTL 数据源 | 0 | PBTL模式下TDM数据源选择 |
| 5-4 | RESERVED | 00 | 保留 |
| 3 | OTSD AUTO RECOVERY | 0 | 0: 过温关断后锁存; 1: 自动恢复 |
| 2-0 | RESERVED | 000 | 保留 |

**RTL连接**:
- `clear_fault` = reg_21[7] → 脉冲 → fault_monitor/protection/pin_control
- `otsd_auto_recovery` = reg_21[3] → protection

---

### 2.18 寄存器 0x22-0x24 — 削波控制

**0x22 — Clip Control** (默认: 0x00)

| Bit | 名称 | 描述 |
|-----|------|------|
| 7-3 | RESERVED | 00000 |
| 2 | CLIP LATCHED | 0: 非锁存; 1: 锁存 |
| 1-0 | RESERVED | 00 |

**0x23 — Clip Window** (默认: 0x14, 20个PWM周期)

**0x24 — Clip Warning** (默认: 0x00, R, 写1清除)

| Bit | 名称 |
|-----|------|
| 7-4 | RESERVED |
| 3 | CH1 CLIP |
| 2 | CH2 CLIP |
| 1 | CH3 CLIP |
| 0 | CH4 CLIP |

---

### 2.19 寄存器 0x25 — ILIMIT状态

**默认值**: 0x00 | **访问**: R/W

逐周期电流限制状态，非锁存（自动恢复）。

---

### 2.20 寄存器 0x26 — 杂项控制4

**默认值**: 0x00 | **访问**: R/W

| Bit | 名称 | 描述 |
|-----|------|------|
| 7-4 | RESERVED | 0x0 |
| 3-0 | HPF CORNER | 高通滤波器截止频率选择 (4Hz/8Hz/15Hz/30Hz) |

---

### 2.21 寄存器 0x28 — 杂项控制5

**默认值**: 0x0A | **访问**: R/W

| Bit | 名称 | 描述 |
|-----|------|------|
| 7-6 | RESERVED | 00 |
| 5 | PHASE_SEL MSB | ⚠ **必须设为1** (与0x02[1:0]组成相位选择) |
| 4-0 | RESERVED | 0_1010 |

---

### 2.22 寄存器 0x77-0x79 — 扩频控制

**0x77 — Spread Spectrum Control 1** (默认: 0x00)

| Bit | 名称 | 描述 |
|-----|------|------|
| 7 | SS ENABLE | 1: 使能扩频 |
| 6-0 | SS_AMPL | 扩频幅度 |

**0x78 — Spread Spectrum Control 2** (默认: 0x00): SS_PRE_DIV
**0x79 — Spread Spectrum Control 3** (默认: 0x00): SS_STEP

**RTL连接**: `ss_ctrl` → pwm_generator (预留)

---

## 3. 寄存器文件硬件接口

### 3.1 写入接口 (I2C → Register File)

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `reg_wr_en` | 1 | i2c_slave → reg_file | 写使能脉冲 (1 clk) |
| `reg_wr_addr` | 8 | i2c_slave → reg_file | 写地址 (0x00-0x79) |
| `reg_wr_data` | 8 | i2c_slave → reg_file | 写数据 |
| `reg_rd_en` | 1 | i2c_slave → reg_file | 读使能脉冲 (1 clk) |
| `reg_rd_addr` | 8 | i2c_slave → reg_file | 读地址 |
| `reg_rd_data` | 8 | reg_file → i2c_slave | 读数据返回 |

### 3.2 硬件写入接口 (内部模块 → Register File)

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `hw_wr_en` | 1 | 各模块 → reg_file | 硬件写使能 |
| `hw_wr_addr` | 8 | 各模块 → reg_file | 硬件写地址 |
| `hw_wr_data` | 8 | 各模块 → reg_file | 硬件写数据 |

### 3.3 RTL实现要点

```verilog
// 寄存器文件伪代码结构
module register_file (
    // I2C接口
    input  wire       clk, rst_n,
    input  wire       reg_wr_en,
    input  wire [7:0] reg_wr_addr, reg_wr_data,
    input  wire       reg_rd_en,
    input  wire [7:0] reg_rd_addr,
    output wire [7:0] reg_rd_data,
    // 硬件写入
    input  wire       hw_wr_en,
    input  wire [7:0] hw_wr_addr, hw_wr_data,
    // 模块配置输出 (关键信号)
    output reg  [7:0] reg_00_mode_ctrl,
    output reg  [7:0] reg_01_misc_ctrl1,
    output reg  [7:0] reg_02_misc_ctrl2,
    output reg  [7:0] reg_03_sap_ctrl,
    output reg  [7:0] reg_04_ch_state_ctrl,
    // ... 其他寄存器
    // 特殊控制信号
    output wire       soft_reset,        // 0x00 bit7 脉冲
    output wire       clear_fault        // 0x21 bit7 脉冲
);
    // 内部: reg [7:0] reg_array [0:127]; // 128字节寄存器空间
    
    // 写逻辑: I2C写优先, R寄存器不允许I2C写
    // 读逻辑: 组合逻辑返回寄存器值
    // 自清除逻辑: soft_reset/clear_fault写入后自动清零
endmodule
```

---

## 4. 寄存器复位值汇总

| 地址 | 名称 | 默认值 | 复位方式 |
|------|------|--------|---------|
| 0x00 | Mode Control | 0x00 | rst_n/POR/soft_reset |
| 0x01 | Misc Control 1 | 0x32 | rst_n/POR/soft_reset |
| 0x02 | Misc Control 2 | 0x62 | rst_n/POR/soft_reset |
| 0x03 | SAP Control | 0x04 | rst_n/POR/soft_reset |
| 0x04 | Ch State Ctrl | 0x55 | rst_n/POR/soft_reset |
| 0x05-0x08 | Ch1~4 Volume | 0xCF | rst_n/POR/soft_reset |
| 0x09-0x0B | DC Diag Ctrl | 0x00/0x11/0x11 | rst_n/POR/soft_reset |
| 0x0C-0x1E | Reports | 0x00 | rst_n/POR/soft_reset (硬件随后填充) |
| 0x21 | Misc Control 3 | 0x00 | rst_n/POR/soft_reset |
| 0x22-0x26 | Clip/Misc | 0x00 | rst_n/POR/soft_reset |
| 0x28 | Misc Control 5 | 0x0A | rst_n/POR/soft_reset |
| 0x77-0x79 | SS Control | 0x00 | rst_n/POR/soft_reset |

---

## 5. 设计检查清单

- [ ] 所有R/W寄存器是否仅由I2C写入（硬件不可写）
- [ ] 所有R寄存器是否仅由硬件写入（I2C不可写）
- [ ] soft_reset (0x00 bit7) 是否实现自清除
- [ ] clear_fault (0x21 bit7) 是否实现自清除脉冲
- [ ] 保留寄存器读是否返回0
- [ ] 保留位写是否忽略
- [ ] I2C顺序读写时子地址是否自动递增
- [ ] 寄存器默认值是否与datasheet一致
- [ ] 相位选择MSB (0x28 bit5) 的是否正确处理
