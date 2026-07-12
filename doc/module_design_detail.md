# TAS6424E-Q1 模块详细设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-11  
> **状态**: 待审核  
> **关联文件**: `architecture_design.md`（架构设计）、`design_spec.md`（设计规格）

---

## 目录

1. [tas6424e_defines.v - 全局参数定义](#1-tas6424e_definesv)
2. [i2c_slave.v - I2C从机接口](#2-i2c_slavev)
3. [register_file.v - 寄存器文件](#3-register_filev)
4. [state_machine.v - 芯片主状态机](#4-state_machinev)
5. [channel_fsm.v - 通道状态机](#5-channel_fsmv)
6. [audio_interface.v - 音频接口](#6-audio_interfacev)
7. [pwm_generator.v - PWM生成器](#7-pwm_generatorv)
8. [diagnostic_ctrl.v - 诊断控制器](#8-diagnostic_ctrlv)
9. [fault_monitor.v - 故障监控器](#9-fault_monitorv)
10. [pin_control.v - 引脚控制](#10-pin_controlv)
11. [clock_monitor.v - 时钟监控器](#11-clock_monitorv)
12. [protection.v - 保护电路](#12-protectionv)
13. [tas6424e_top.v - 顶层模块](#13-tas6424e_topv)

---

## 1. tas6424e_defines.v

### 1.1 功能描述

全局参数定义文件，使用Verilog宏定义（`define）集中管理所有模块共用的常量，包括状态编码、寄存器地址、默认值、位域定义、时间常量等。

### 1.2 设计考量

- **使用宏定义而非parameter**：宏定义在编译时全局替换，适用于跨模块共享的常量
- **使用`ifndef保护**：防止重复包含
- **分组注释**：按功能分组（状态编码、寄存器地址、默认值、位域、时间常量）

### 1.3 定义内容

#### 状态编码

| 宏名 | 值 | 说明 |
|------|-----|------|
| `CHIP_STANDBY` | 3'd0 | 芯片待机态 |
| `CHIP_HI_Z` | 3'd1 | 芯片高阻态 |
| `CHIP_MUTE` | 3'd2 | 芯片静音态 |
| `CHIP_PLAY` | 3'd3 | 芯片播放态 |
| `CHIP_DIAG` | 3'd4 | 芯片诊断态 |
| `CH_PLAY` | 2'd0 | 通道播放 |
| `CH_HI_Z` | 2'd1 | 通道高阻 |
| `CH_MUTE` | 2'd2 | 通道静音 |
| `CH_DC_DIAG` | 2'd3 | 通道DC诊断 |

#### 寄存器地址（0x00-0x79）

| 宏名 | 地址 | 寄存器名 |
|------|------|---------|
| `REG_MODE_CTRL` | 0x00 | 模式控制 |
| `REG_MISC_CTRL1` | 0x01 | 杂项控制1 |
| `REG_MISC_CTRL2` | 0x02 | 杂项控制2（含PWM频率） |
| `REG_SAP_CTRL` | 0x03 | 音频接口控制 |
| `REG_CH_STATE_CTRL` | 0x04 | 通道状态控制 |
| `REG_CH1~4_VOL` | 0x05-0x08 | 通道音量 |
| `REG_DC_DIAG_CTRL1~3` | 0x09-0x0B | DC诊断控制 |
| `REG_DC_DIAG_RPT1~3` | 0x0C-0x0E | DC诊断报告 |
| `REG_CH_STATE_RPT` | 0x0F | 通道状态报告 |
| `REG_CH_FAULTS` | 0x10 | 通道故障 |
| `REG_GLOBAL_FAULT1` | 0x11 | 全局故障1 |
| `REG_GLOBAL_FAULT2` | 0x12 | 全局故障2 |
| `REG_WARNINGS` | 0x13 | 警告 |
| `REG_PIN_CTRL` | 0x14 | 引脚控制 |
| `REG_AC_DIAG_CTRL1~2` | 0x15-0x16 | AC诊断控制 |
| `REG_AC_DIAG_RPT_CH1~4` | 0x17-0x1A | AC诊断报告 |
| `REG_MISC_CTRL3` | 0x21 | 杂项控制3（CLEAR_FAULT） |
| `REG_CLIP_CTRL/WINDOW/WARNING` | 0x22-0x24 | 削波控制 |
| `REG_MISC_CTRL4/5` | 0x26/0x28 | 杂项控制4/5 |
| `REG_SS_CTRL1~3` | 0x77-0x79 | 扩频控制 |

#### 时间常量（@10MHz系统时钟）

| 宏名 | 值 | 实际时间 | 说明 |
|------|-----|---------|------|
| `DEBOUNCE_CYCLES` | 500 | 50us | 引脚去抖动 |
| `CLK_TIMEOUT_CYCLES` | 0xFFFFF | ~100ms | 时钟丢失超时 |
| `DIAG_TIMEOUT_CYCLES` | 0xFFFFF | ~100ms | 诊断超时 |
| `OTSD_RECOVERY_CYCLES` | 0xFFFFFF | ~16s | 过温恢复冷却 |
| `FAULT_DEGLITCH_CYCLES` | 100 | 10us | 故障去毛刺 |

---

## 2. i2c_slave.v

### 2.1 功能描述

标准I2C从机接口，支持7位地址匹配、单字节写、顺序写、随机读、顺序读。地址由`i2c_addr1/i2c_addr0`引脚选择4个选项。

### 2.2 接口定义

```verilog
module i2c_slave #(
    parameter CLK_FREQ = 10_000_000
) (
    input  wire        clk,
    input  wire        rst_n,
    // I2C总线
    input  wire        scl,           // SCL输入采样
    input  wire        sda_i,         // SDA输入
    output reg         sda_o,         // SDA输出
    output reg         sda_oe,        // SDA输出使能
    // 地址选择
    input  wire        i2c_addr1,
    input  wire        i2c_addr0,
    // 寄存器访问接口
    output reg         reg_wr_en,
    output reg  [7:0]  reg_wr_addr,
    output reg  [7:0]  reg_wr_data,
    output reg         reg_rd_en,
    output reg  [7:0]  reg_rd_addr,
    input  wire [7:0]  reg_rd_data
);
```

### 2.3 内部架构

```
┌──────────────────────────────────────────────────┐
│ i2c_slave                                        │
│                                                  │
│  ┌─────────┐   ┌──────────┐   ┌──────────────┐  │
│  │SCL/SDA  │──►│边沿检测   │──►│ I2C状态机    │  │
│  │2级同步  │   │START/STOP│   │ (9状态FSM)   │  │
│  └─────────┘   └──────────┘   └──────┬───────┘  │
│                                      │           │
│                 ┌────────────────────┘           │
│                 ▼                                │
│  ┌──────────────────┐  ┌──────────────────────┐ │
│  │ 地址比较器        │  │ 移位寄存器/计数器     │ │
│  │ 7bit + R/W匹配   │  │ 8bit数据收发          │ │
│  └──────────────────┘  └──────────────────────┘ │
│                                      │           │
│                 ┌────────────────────┘           │
│                 ▼                                │
│  ┌──────────────────────────────────────────┐    │
│  │ 寄存器读写接口生成                        │    │
│  │ reg_wr_en/addr/data, reg_rd_en/addr      │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
```

### 2.4 I2C状态机（9状态）

| 状态 | 编码 | 描述 | 转移条件 |
|------|------|------|---------|
| `I2C_IDLE` | 4'd0 | 等待START | 检测到START→ADDR |
| `I2C_ADDR` | 4'd1 | 接收7位地址+R/W | 8bit接收完→ACK_ADDR |
| `I2C_ACK_ADDR` | 4'd2 | 地址ACK | 地址匹配→WR_ADDR(写)/RD_DATA(读) |
| `I2C_WR_ADDR` | 4'd3 | 接收寄存器地址 | 8bit→ACK_WA |
| `I2C_ACK_WA` | 4'd4 | 地址ACK | →WR_DATA |
| `I2C_WR_DATA` | 4'd5 | 接收数据字节 | 8bit→ACK_WD |
| `I2C_ACK_WD` | 4'd6 | 数据ACK | STOP→IDLE / 继续写→WR_DATA |
| `I2C_RD_DATA` | 4'd7 | 发送数据字节 | 8bit→ACK_RD |
| `I2C_ACK_RD` | 4'd8 | 接收ACK/NACK | ACK→RD_DATA / NACK→IDLE |

### 2.5 关键设计点

1. **START/STOP检测**：SCL高电平期间SDA下降沿=START，SDA上升沿=STOP
2. **数据采样**：SCL上升沿采样SDA（主机驱动），SCL下降沿更新SDA（从机驱动）
3. **地址匹配**：`{i2c_addr1, i2c_addr0}`选择4个地址偏移，基地址0x6A
4. **时钟同步**：SCL和SDA均经2级DFF同步到clk域，消除亚稳态
5. **顺序写支持**：写入寄存器地址后，后续数据字节地址自动递增
6. **顺序读支持**：读取一个字节后，地址自动递增，主机ACK继续读

### 2.6 时序要求

- 支持标准模式(100kHz)和快速模式(400kHz)
- 系统时钟(10MHz)远高于I2C时钟，满足采样定理
- SCL高电平最小宽度4us(100kHz)，系统时钟100ns，足够检测START/STOP

---

## 3. register_file.v

### 3.1 功能描述

实现0x00-0x79地址空间的寄存器存储，支持I2C读写接口和内部硬件写接口。R/W类型由I2C驱动，R类型由内部硬件驱动。

### 3.2 接口定义

```verilog
module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pad_rst_n,
    // I2C写接口
    input  wire        i2c_wr_en,
    input  wire [7:0]  i2c_wr_addr,
    input  wire [7:0]  i2c_wr_data,
    // I2C读接口
    input  wire        i2c_rd_en,
    input  wire [7:0]  i2c_rd_addr,
    output reg  [7:0]  i2c_rd_data,
    // 配置寄存器输出（R/W类型）
    output wire [7:0]  reg_mode_ctrl,       // 0x00
    output wire [7:0]  reg_misc_ctrl1,      // 0x01
    output wire [7:0]  reg_misc_ctrl2,      // 0x02
    output wire [7:0]  reg_sap_ctrl,        // 0x03
    output wire [7:0]  reg_ch_state_ctrl,   // 0x04
    output wire [7:0]  reg_ch1_vol,         // 0x05
    // ... (其余配置寄存器输出省略)
    // 硬件写入接口（R类型）
    input  wire [7:0]  hw_dc_diag_rpt1,     // 0x0C
    input  wire [7:0]  hw_ch_state_rpt,     // 0x0F
    input  wire [7:0]  hw_ch_faults,        // 0x10
    input  wire [7:0]  hw_global_fault1,    // 0x11
    input  wire [7:0]  hw_global_fault2,    // 0x12
    input  wire [7:0]  hw_warnings,         // 0x13
    // ... (其余硬件写入接口省略)
    // 特殊控制信号输出
    output wire        soft_reset,          // 0x00 bit7
    output wire        clear_fault,         // 0x21 bit7
    output wire        otsd_auto_recovery   // 0x21 bit3
);
```

### 3.3 内部架构

```
┌─────────────────────────────────────────────────────┐
│ register_file                                       │
│                                                     │
│  I2C写 ──► ┌─────────────────────────┐              │
│            │    地址解码器             │              │
│            │    (i2c_wr_addr匹配)     │              │
│            └────────┬────────────────┘              │
│                     │ 写使能                         │
│  ┌──────────────────▼──────────────────────┐        │
│  │  R/W寄存器阵列                           │        │
│  │  reg_00_mode_ctrl     ← DEF_MODE_CTRL   │        │
│  │  reg_01_misc_ctrl1    ← DEF_MISC_CTRL1  │        │
│  │  reg_04_ch_state_ctrl ← DEF_CH_STATE_CTRL│       │
│  │  ...                                    │        │
│  └──────────────────┬──────────────────────┘        │
│                     │                               │
│  ┌──────────────────▼──────────────────────┐        │
│  │  R寄存器直通（硬件写入值直接输出）        │        │
│  │  hw_ch_faults → 0x10读出                │        │
│  │  hw_global_fault1 → 0x11读出            │        │
│  │  ...                                    │        │
│  └──────────────────┬──────────────────────┘        │
│                     │                               │
│  I2C读 ◄── ┌────────▼────────┐                      │
│            │  读多路选择器     │                      │
│            │  (i2c_rd_addr)   │                      │
│            └─────────────────┘                      │
└─────────────────────────────────────────────────────┘
```

### 3.4 寄存器实现策略

| 寄存器类型 | 实现方式 | 写入源 | 读取源 |
|-----------|---------|--------|--------|
| R/W配置寄存器 | `reg` + always块 | I2C写 | I2C读 + 模块输出 |
| R状态寄存器 | `wire`直通 | 硬件模块 | I2C读（多路选择） |

### 3.5 复位逻辑

```verilog
// 复位条件：rst_n=0 或 pad_rst_n=0 或 soft_reset=1
wire reg_rst_n = rst_n & pad_rst_n & ~soft_reset;

always @(posedge clk or negedge reg_rst_n) begin
    if (!reg_rst_n) begin
        reg_mode_ctrl <= `DEF_MODE_CTRL;        // 0x00
        reg_misc_ctrl1 <= `DEF_MISC_CTRL1;      // 0x01
        // ... 所有R/W寄存器恢复默认值
    end else if (i2c_wr_en) begin
        case (i2c_wr_addr)
            `REG_MODE_CTRL: reg_mode_ctrl <= i2c_wr_data;
            `REG_MISC_CTRL1: reg_misc_ctrl1 <= i2c_wr_data;
            // ...
        endcase
    end
end
```

### 3.6 读多路选择器

```verilog
always @(*) begin
    case (i2c_rd_addr)
        `REG_MODE_CTRL:     i2c_rd_data = reg_mode_ctrl;
        `REG_CH_FAULTS:     i2c_rd_data = hw_ch_faults;       // R类型直通
        `REG_GLOBAL_FAULT1: i2c_rd_data = hw_global_fault1;   // R类型直通
        // ...
        default:            i2c_rd_data = 8'h00;
    endcase
end
```

---

## 4. state_machine.v

### 4.1 功能描述

芯片主状态机，管理STANDBY→HI_Z→MUTE→PLAY→DIAG全局状态转换。两段式FSM设计：组合逻辑生成下一状态，时序逻辑寄存状态。

### 4.2 接口定义

```verilog
module state_machine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pad_rst_n,
    input  wire        standby_n,          // 去抖动后STANDBY引脚
    input  wire [7:0]  ch_state_ctrl,      // 0x04寄存器
    input  wire        global_fault,       // 全局故障
    input  wire        diag_done,          // 诊断完成
    input  wire        clear_fault,        // 清除故障
    output reg  [2:0]  chip_state,         // 当前芯片状态
    output reg         diag_trigger        // 诊断触发脉冲
);
```

### 4.3 状态转换逻辑

**内部条件信号**（从0x04寄存器解码）：

```verilog
wire any_ch_diag = (ch_state_ctrl[1:0]==`CH_DC_DIAG) || ... ;  // 任意通道请求诊断
wire any_ch_play = (ch_state_ctrl[1:0]==`CH_PLAY) || ... ;     // 任意通道请求播放
wire any_ch_mute = (ch_state_ctrl[1:0]==`CH_MUTE) || ... ;     // 任意通道请求静音
wire all_ch_hiz  = (ch_state_ctrl[1:0]==`CH_HI_Z) && ... ;     // 所有通道Hi-Z
```

**状态转换表**：

| 当前态 | 条件 | 下一态 | 优先级 |
|--------|------|--------|--------|
| STANDBY | standby_n=1 | HI_Z | 1 |
| HI_Z | global_fault | HI_Z | 1(保持) |
| HI_Z | !standby_n | STANDBY | 2 |
| HI_Z | any_ch_diag | DIAG | 3 |
| HI_Z | any_ch_play | PLAY | 4 |
| HI_Z | any_ch_mute | MUTE | 5 |
| MUTE | global_fault | HI_Z | 1 |
| MUTE | !standby_n | STANDBY | 2 |
| MUTE | any_ch_diag | DIAG | 3 |
| MUTE | any_ch_play && !any_ch_mute | PLAY | 4 |
| MUTE | all_ch_hiz | HI_Z | 5 |
| PLAY | global_fault | HI_Z | 1 |
| PLAY | !standby_n | STANDBY | 2 |
| PLAY | any_ch_diag | DIAG | 3 |
| PLAY | any_ch_mute && !any_ch_play | MUTE | 4 |
| PLAY | all_ch_hiz | HI_Z | 5 |
| DIAG | global_fault | HI_Z | 1 |
| DIAG | diag_done | HI_Z | 2 |
| DIAG | !standby_n | STANDBY | 3 |

### 4.4 诊断触发脉冲

```verilog
// 进入DIAG态时产生1周期脉冲
always @(posedge clk or negedge internal_rst_n) begin
    if (!internal_rst_n)
        diag_trigger <= 1'b0;
    else
        diag_trigger <= (chip_state != `CHIP_DIAG && state_next == `CHIP_DIAG);
end
```

### 4.5 复位策略

- `internal_rst_n = rst_n & pad_rst_n`：POR也触发状态机复位
- 复位后`chip_state = CHIP_STANDBY`

---

## 5. channel_fsm.v

### 5.1 功能描述

4通道独立状态机（4实例例化），管理每通道PLAY/Hi-Z/MUTE/DC_DIAG状态。通道故障时仅该通道进Hi-Z，其他通道不受影响。

### 5.2 接口定义

```verilog
module channel_fsm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  chip_state,        // 主状态机全局状态
    input  wire [1:0]  ch_state_req,      // 0x04该通道配置
    input  wire        ch_fault,          // 该通道故障
    input  wire        clear_fault,       // 清除故障
    input  wire        diag_trigger,      // 诊断触发
    input  wire        diag_done,         // 诊断完成
    output reg  [1:0]  ch_state,          // 当前通道状态
    output wire        ch_en,             // 通道使能
    output wire        ch_mute_mode,      // 静音模式
    output wire        ch_diag_active     // 诊断进行中
);
```

### 5.3 故障锁存逻辑

```verilog
reg ch_fault_latched_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ch_fault_latched_reg <= 1'b0;
    else if (clear_fault)
        ch_fault_latched_reg <= 1'b0;     // CLEAR_FAULT清除
    else if (ch_fault)
        ch_fault_latched_reg <= 1'b1;     // 故障锁存
end
```

### 5.4 通道状态控制逻辑

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ch_state <= `CH_HI_Z;
    else if (ch_fault_latched_reg)
        ch_state <= `CH_HI_Z;             // 故障锁存→强制Hi-Z
    else if (chip_state == `CHIP_STANDBY || chip_state == `CHIP_HI_Z)
        ch_state <= `CH_HI_Z;             // 全局Hi-Z
    else if (chip_state == `CHIP_DIAG)
        ch_state <= (ch_state_req == `CH_DC_DIAG) ? `CH_DC_DIAG : `CH_HI_Z;
    else // PLAY or MUTE
        ch_state <= ch_state_req;         // 跟随0x04配置
end
```

### 5.5 输出信号生成

```verilog
assign ch_en         = (ch_state == `CH_PLAY) || (ch_state == `CH_MUTE);
assign ch_mute_mode  = (ch_state == `CH_MUTE);
assign ch_diag_active = (ch_state == `CH_DC_DIAG);
```

---

## 6. audio_interface.v

### 6.1 功能描述

支持I2S/LJ/DSP/TDM 8种音频接口模式，接收MCLK/SCLK/FSYNC/SDIN1/SDIN2，输出4通道24位音频数据。

### 6.2 SAP模式定义（0x03寄存器[2:0]）

| 编码 | 模式 | 数据线 | 通道分配 |
|------|------|--------|---------|
| 000 | I2S | SDIN1=CH1/2, SDIN2=CH3/4 | 左右声道各1通道 |
| 001 | Left Justified | SDIN1=CH1/2, SDIN2=CH3/4 | 左对齐 |
| 010 | DSP/PCM mode A | SDIN1=CH1/2, SDIN2=CH3/4 | FSYNC后1 BCLK |
| 011 | DSP/PCM mode B | SDIN1=CH1/2, SDIN2=CH3/4 | FSYNC同1 BCLK |
| 100 | TDM 4ch/SDIN1 | SDIN1=CH1-4 | 4通道TDM |
| 101 | TDM 4ch/SDIN2 | SDIN2=CH1-4 | 4通道TDM |
| 110 | Reserved | - | - |
| 111 | Reserved | - | - |

### 6.3 内部架构

```
┌──────────────────────────────────────────────────┐
│ audio_interface                                  │
│                                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│  │MCLK同步 │  │SCLK同步 │  │FSYNC同步│          │
│  │2级DFF   │  │2级DFF   │  │2级DFF   │          │
│  └─────────┘  └────┬────┘  └────┬────┘          │
│                    │            │                │
│              ┌─────▼─────┐ ┌────▼─────┐         │
│              │sclk边沿   │ │fsync边沿 │         │
│              │检测       │ │检测      │         │
│              └─────┬─────┘ └────┬─────┘         │
│                    │            │                │
│  ┌─────────────────▼────────────▼──────────┐    │
│  │  模式解码器（sap_mode选择）              │    │
│  │  I2S: FSYNC高=右, FSYNC低=左            │    │
│  │  LJ:  FSYNC后立即数据                   │    │
│  │  DSP: FSYNC后1BCLK开始                  │    │
│  │  TDM: 4通道时隙解码                     │    │
│  └─────────────────┬──────────────────────┘    │
│                    │                            │
│  ┌──────────┐ ┌────▼────┐ ┌──────────┐         │
│  │SDIN1     │ │移位寄存器│ │SDIN2     │         │
│  │采样      │─►│24bit×4  │◄─│采样      │         │
│  └──────────┘ └────┬────┘ └──────────┘         │
│                    │                            │
│              ┌─────▼─────┐                      │
│              │锁存器      │                      │
│              │audio_data │                      │
│              │ch1~4[23:0]│                      │
│              └───────────┘                      │
└──────────────────────────────────────────────────┘
```

### 6.4 数据采样时序

**I2S模式时序**：
```
FSYNC ──────┐                    ┌──────────────
             │                    │
             └────────────────────┘
             ←左声道(L)→           ←右声道(R)→

SCLK ──┐  ┌──┐  ┌──┐    ┌──┐  ┌──┐  ┌──┐
        │  │  │  │  │    │  │  │  │  │  │
        └──┘  └──┘  └──..┘  └──┘  └──┘  └..

SDIN     X====D0===D1..D22  X====D0===D1..D22
         ↑                   ↑
         FSYNC下降沿          FSYNC上升沿
         锁存左声道           锁存右声道
```

### 6.5 关键设计点

1. **SCLK下降沿采样**：I2S标准在SCLK下降沿更新数据，上升沿采样
2. **MSB First**：音频数据高位先传
3. **24位有效位**：移位24个SCLK周期后锁存
4. **TDM模式**：4通道在1个FSYNC周期内按时隙传输，每通道32个SCLK（24有效+8空闲）

---

## 7. pwm_generator.v

### 7.1 功能描述

4通道BTL PWM输出。PLAY态根据音频数据进行PWM调制，MUTE态输出50%占空比方波，Hi-Z态输出0。

### 7.2 PWM频率配置

| `pwm_freq[2:0]` | 倍率 | 频率(@48kHz) | 说明 |
|-----------------|------|-------------|------|
| 000 | 8×fs | 384kHz | 低频高效 |
| 001 | 16×fs | 768kHz | - |
| 010 | 22×fs | 1.06MHz | - |
| 011 | 32×fs | 1.54MHz | - |
| 100 | 44×fs | 2.11MHz | 默认 |
| 101 | 48×fs | 2.30MHz | - |
| 110 | 64×fs | 3.07MHz | - |
| 111 | - | - | 保留 |

### 7.3 内部架构

```
┌──────────────────────────────────────────────────┐
│ pwm_generator                                    │
│                                                  │
│  ┌─────────────────────────────────────┐         │
│  │ 载波计数器（三角波发生器）           │         │
│  │ 根据pwm_freq配置周期                 │         │
│  │ carrier[15:0] 0→MAX→0 锯齿/三角     │         │
│  └────────────────┬────────────────────┘         │
│                   │ carrier值                    │
│  ┌────────────────▼────────────────────┐         │
│  │ 4通道比较器                          │         │
│  │ audio_data_chN[23:0] >> 8 vs carrier│         │
│  └──┬──────┬──────┬──────┬─────────────┘         │
│     │      │      │      │                       │
│  ┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐                   │
│  │ CH1 ││ CH2 ││ CH3 ││ CH4 │                   │
│  │模式 ││模式 ││模式 ││模式 │                   │
│  │选择 ││选择 ││选择 ││选择 │                   │
│  └──┬──┘└──┬──┘└──┬──┘└──┬──┘                   │
│     │      │      │      │                       │
│  ┌──▼──────▼──────▼──────▼───┐                   │
│  │ BTL输出级                  │                   │
│  │ PLAY: out_p=!out_m=PWM波形 │                   │
│  │ MUTE: out_p=!out_m=50%方波 │                   │
│  │ Hi-Z: out_p=out_m=0        │                   │
│  └──┬───┬───┬───┬───┬───┬────┘                   │
│     │   │   │   │   │   │                        │
│   1p 1m 2p 2m 3p 3m 4p 4m                       │
└──────────────────────────────────────────────────┘
```

### 7.4 PWM调制原理

```
三角波载波 carrier:  0 ────► MAX ────► 0 (一个PWM周期)

音频数据 audio_data: 24位有符号数 (范围 -2^23 ~ +2^23-1)

比较结果:
  if (audio_data >> 8 > carrier)
      out_p = 1, out_m = 0    (正输出)
  else
      out_p = 0, out_m = 1    (负输出)

占空比 = (audio_data + 2^23) / 2^24 × 100%
  → audio_data = 0 时：50%占空比
  → audio_data = +MAX 时：~100%占空比
  → audio_data = -MAX 时：~0%占空比
```

### 7.5 通道模式选择逻辑

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_1p <= 0; out_1m <= 0; // ...
    end else begin
        // CH1
        if (!ch1_en) begin
            out_1p <= 0; out_1m <= 0;           // Hi-Z: 输出0
        end else if (ch1_mute) begin
            out_1p <= carrier_msb;               // MUTE: 50%方波
            out_1m <= ~carrier_msb;
        end else begin
            out_1p <= pwm_cmp_ch1;               // PLAY: PWM调制
            out_1m <= ~pwm_cmp_ch1;
        end
        // CH2-4 同理
    end
end
```

### 7.6 BTL输出特性

- BTL（桥接式负载）：正负输出反向驱动负载
- 静态（0输入）：out_p和out_m均为50%方波，负载两端无直流压差
- 正输入：out_p占空比>50%，out_m占空比<50%，负载电流正向
- 负输入：out_p占空比<50%，out_m占空比>50%，负载电流反向

---

## 8. diagnostic_ctrl.v

### 8.1 功能描述

DC负载诊断（开路/短路到地/短路到电池）和AC负载诊断（阻抗/相位测量）。诊断由主状态机`diag_trigger`触发。

### 8.2 诊断状态机（4状态）

| 状态 | 编码 | 描述 | 转移条件 |
|------|------|------|---------|
| `DIAG_IDLE` | 2'd0 | 空闲等待 | diag_trigger→DC_RUN |
| `DIAG_DC_RUN` | 2'd1 | DC诊断运行 | timer_done→AC_RUN或DONE |
| `DIAG_AC_RUN` | 2'd2 | AC诊断运行 | timer_done→DONE |
| `DIAG_DONE` | 2'd3 | 诊断完成 | 自动→IDLE (1clk) |

### 8.3 DC诊断结果编码

每通道2位编码（4通道共8位，分布在0x0C-0x0E寄存器）：

| 编码 | 含义 | 检测原理 |
|------|------|---------|
| 00 | 正常 | 阻抗在正常范围（如4-8Ω） |
| 01 | 开路 | 阻抗过高（>100Ω） |
| 10 | 短路到地 | 阻抗过低（<1Ω） |
| 11 | 短路到电池 | 检测到电池电压偏移 |

### 8.4 诊断流程

```
1. MCU写0x04寄存器，目标通道设为CH_DC_DIAG(2'b11)
2. state_machine检测any_ch_diag → 进入CHIP_DIAG态
3. diag_trigger脉冲启动diagnostic_ctrl
4. DIAG_IDLE → DIAG_DC_RUN
5. 诊断计时器运行（模拟前端测量时间）
6. 计时器到 → 生成诊断报告 → DIAG_AC_RUN (若AC诊断使能)
7. AC诊断完成 → DIAG_DONE
8. diag_done信号 → state_machine退出DIAG态 → HI_Z
9. MCU读取0x0C-0x0E获取DC诊断结果
10. MCU读取0x17-0x1A获取AC诊断结果
```

---

## 9. fault_monitor.v

### 9.1 功能描述

集中监控所有故障源（OC/DC/OTW/OTSD/UV/OV/CLOCK），故障锁存后输出到寄存器文件和状态机。CLEAR_FAULT清除锁存。

### 9.2 故障源映射

#### 0x10 - Channel Faults（通道故障）

| Bit | 信号 | 描述 |
|-----|------|------|
| [7:4] | oc_ch4~1 | 通道4~1过流 |
| [3:0] | dc_ch4~1 | 通道4~1直流检测 |

#### 0x11 - Global Faults 1（全局故障1）

| Bit | 信号 | 描述 |
|-----|------|------|
| [4] | clock_lost | 时钟丢失 |
| [3] | pvdd_ov | PVDD过压 |
| [2] | vbat_ov | VBAT过压 |
| [1] | pvdd_uv | PVDD欠压 |
| [0] | vbat_uv | VBAT欠压 |

#### 0x12 - Global Faults 2（全局故障2）

| Bit | 信号 | 描述 |
|-----|------|------|
| [5] | otsd | 过温关断 |
| [4:1] | otsd_ch4~1 | 通道4~1过温关断 |
| [0] | (保留) | - |

#### 0x13 - Warnings（警告）

| Bit | 信号 | 描述 |
|-----|------|------|
| [5] | por_flag | POR标志 |
| [4] | otw | 过温警告 |
| [3:0] | otw_ch4~1 | 通道4~1过温警告 |

### 9.3 故障中断信号

```verilog
// 全局故障中断（触发state_machine进Hi-Z）
assign global_fault_irq = otsd_latched || vbat_uv_latched || vbat_ov_latched ||
                          pvdd_uv_latched || pvdd_ov_latched || clock_lost_latched;

// 通道故障信号（触发对应channel_fsm进Hi-Z）
assign ch1_fault = oc_ch1_latched || dc_ch1_latched;
assign ch2_fault = oc_ch2_latched || dc_ch2_latched;
// ...
```

### 9.4 故障锁存与清除

```verilog
// 故障锁存寄存器
reg otsd_latched, vbat_uv_latched, ...;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        otsd_latched <= 0;
        // ...
    end else if (clear_fault) begin
        otsd_latched <= 0;     // CLEAR_FAULT清除所有锁存
        // ...
    end else begin
        if (otsd) otsd_latched <= 1;  // 故障发生时锁存
        // ...
    end
end
```

### 9.5 POR标志处理

```verilog
// POR标志特殊处理：仅POR或软复位可清除
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        por_flag <= 1;          // 复位时置POR标志
    else if (!pad_rst_n)
        por_flag <= 1;          // POR时置标志
    else if (soft_reset)
        por_flag <= 0;          // 软复位清除
end
```

---

## 10. pin_control.v

### 10.1 功能描述

STANDBY/MUTE引脚去抖动处理，FAULT/WARN开漏输出驱动。

### 10.2 引脚去抖动

```
连续采样DEBOUNCE_CYCLES(500)次相同值才更新输出
├── 消除开关抖动（<50us的毛刺被滤除）
└── 确保引脚信号稳定

去抖动计数器逻辑：
  if (pin_input != pin_prev)
      counter <= 0;           // 信号变化，重置计数器
  else if (counter < DEBOUNCE_CYCLES)
      counter <= counter + 1; // 信号稳定，计数
  else
      pin_output <= pin_input; // 稳定足够久，更新输出
```

### 10.3 FAULT/WARN输出逻辑

```verilog
// FAULT引脚（开漏低有效）
always @(*) begin
    if (global_fault_irq || any_ch_fault)
        fault_n = 1'b0;       // 有故障：拉低
    else
        fault_n = 1'b1;       // 无故障：释放（外部上拉）
end

// WARN引脚（开漏低有效）
always @(*) begin
    if (otw_warning || por_flag)
        warn_n = 1'b0;        // 有警告：拉低
    else
        warn_n = 1'b1;        // 无警告：释放
end

// 0x14寄存器可配置屏蔽
// (实际实现中pin_ctrl_reg的某些bit可屏蔽fault_n/warn_n)
```

---

## 11. clock_monitor.v

### 11.1 功能描述

监控MCLK/SCLK/FSYNC的存在性，检测时钟丢失。仅在非STANDBY态监控。

### 11.2 监控原理

```
对每个时钟信号：
1. 2级DFF同步到clk域
2. 边沿检测（XOR前后级）
3. 时钟活动计数器：
   - 检测到边沿 → 重置计数器
   - 无边沿 → 计数器递增
   - 计数器溢出(CLK_TIMEOUT_CYCLES) → clock_lost=1

时钟丢失条件：
  (chip_state != CHIP_STANDBY) && (任意时钟计数器溢出)
```

### 11.3 监控条件

| 芯片状态 | 是否监控 | 说明 |
|---------|---------|------|
| STANDBY | 否 | 振荡器关闭，无音频时钟 |
| HI_Z | 是 | 等待音频时钟稳定 |
| MUTE | 是 | 需要时钟产生50%方波 |
| PLAY | 是 | 需要时钟接收音频数据 |
| DIAG | 否 | DC诊断不需要音频时钟 |

---

## 12. protection.v

### 12.1 功能描述

过温/过压/欠压去毛刺检测，OTSD自动恢复控制。输入来自模拟前端的原始信号。

### 12.2 去毛刺逻辑

```
对每个故障输入信号：
1. 连续FAULT_DEGLITCH_CYCLES(100)个周期检测到故障
2. 才确认为真实故障（消除<10us的毛刺）

去毛刺计数器：
  if (fault_raw)
      counter <= counter + 1;      // 故障持续，计数
  else
      counter <= 0;                // 故障消失，重置
  
  if (counter >= FAULT_DEGLITCH_CYCLES)
      fault_output = 1;            // 确认故障
```

### 12.3 OTSD自动恢复

```
OTSD自动恢复流程（0x21 bit3 = 1时使能）：
1. 检测到OTSD → 故障锁存 → 芯片进Hi-Z
2. 启动冷却计时器（OTSD_RECOVERY_CYCLES ≈ 16s）
3. 冷却完成 + OTSD信号已消失 → 自动清除锁存
4. CLEAR_FAULT或自动恢复 → 芯片可重新进入工作态

若0x21 bit3 = 0（禁用自动恢复）：
  OTSD恢复需MCU手动写CLEAR_FAULT
```

### 12.4 去毛刺后输出信号

| 输出信号 | 输入信号 | 说明 |
|---------|---------|------|
| `otw` | `otw_raw` | 过温警告（去毛刺后） |
| `otsd` | `otsd_raw` | 过温关断（去毛刺后） |
| `vbat_uv` | `vbat_uv_raw` | VBAT欠压 |
| `vbat_ov` | `vbat_ov_raw` | VBAT过压 |
| `pvdd_uv` | `pvdd_uv_raw` | PVDD欠压 |
| `pvdd_ov` | `pvdd_ov_raw` | PVDD过压 |

---

## 13. tas6424e_top.v

### 13.1 功能描述

顶层模块，集成所有12个子模块，定义56引脚（简化模型）接口，完成模块间信号连接。

### 13.2 引脚接口

| 引脚组 | 引脚 | 方向 | 描述 |
|--------|------|------|------|
| 系统 | clk, rst_n, pad_rst_n | input | 时钟与复位 |
| I2C | i2c_scl, i2c_sda | inout | I2C总线 |
| I2C地址 | i2c_addr1, i2c_addr0 | input | 地址选择 |
| 音频 | mclk, sclk, fsync, sdin1, sdin2 | input | 音频接口 |
| 控制 | standby_n_pin, mute_n_pin | input | 控制引脚 |
| 状态 | fault_n, warn_n | output | 故障/警告指示 |
| PWM输出 | out_1p~4m | output | 4通道BTL输出 |
| 模拟前端 | otw_raw, otsd_raw, vbat_uv/ov_raw, pvdd_uv/ov_raw | input | 保护信号 |
| 过流 | oc_ch1~4 | input | 通道过流 |
| 直流 | dc_ch1~4 | input | 通道直流检测 |

### 13.3 模块例化清单

| 实例名 | 模块名 | 数量 | 说明 |
|--------|--------|------|------|
| `u_i2c_slave` | i2c_slave | 1 | I2C从机 |
| `u_register_file` | register_file | 1 | 寄存器文件 |
| `u_state_machine` | state_machine | 1 | 主状态机 |
| `u_ch1_fsm` ~ `u_ch4_fsm` | channel_fsm | 4 | 通道状态机 |
| `u_audio_interface` | audio_interface | 1 | 音频接口 |
| `u_pwm_generator` | pwm_generator | 1 | PWM生成器 |
| `u_diagnostic_ctrl` | diagnostic_ctrl | 1 | 诊断控制器 |
| `u_fault_monitor` | fault_monitor | 1 | 故障监控器 |
| `u_clock_monitor` | clock_monitor | 1 | 时钟监控器 |
| `u_protection` | protection | 1 | 保护电路 |
| `u_pin_control` | pin_control | 1 | 引脚控制 |

### 13.4 关键内部信号连接

```verilog
// 通道状态报告组装
assign hw_ch_state_rpt = {ch4_state, ch3_state, ch2_state, ch1_state};

// 通道状态控制分拆到各通道
// u_ch1_fsm.ch_state_req = reg_ch_state_ctrl[1:0]
// u_ch2_fsm.ch_state_req = reg_ch_state_ctrl[3:2]
// u_ch3_fsm.ch_state_req = reg_ch_state_ctrl[5:4]
// u_ch4_fsm.ch_state_req = reg_ch_state_ctrl[7:6]

// 任意通道故障
wire any_ch_fault = ch1_fault | ch2_fault | ch3_fault | ch4_fault;

// POR标志和OTW警告
wire por_flag = hw_warnings[5];
wire otw_warning = hw_warnings[4];
```

### 13.5 I2C SDA三态驱动

```verilog
// SDA三态控制：sda_oe=1时从机驱动SDA
assign i2c_sda = i2c_sda_oe ? i2c_sda_o : 1'bz;
```

---

## 附录A：模块间信号完整性检查

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 所有模块clk统一连接 | OK | 全部使用顶层clk |
| 所有模块rst_n统一连接 | OK | 全部使用顶层rst_n |
| pad_rst_n连接到需要POR的模块 | OK | register_file, state_machine, fault_monitor |
| 寄存器输出到所有消费模块 | OK | 见架构文档3.2.2节 |
| 硬件写入寄存器到register_file | OK | 见架构文档3.2.3节 |
| 状态机信号双向连接 | OK | chip_state/diag_trigger/diag_done |
| 故障信号链完整 | OK | protection→fault_monitor→register_file+state_machine |
| 通道控制信号4通道完整 | OK | ch1~4_state/en/mute/diag_active/fault |
| PWM输出8引脚 | OK | out_1p~4m |
| 无悬空信号 | OK | 所有output有驱动，所有input有源 |

---

## 附录B：待优化项

| 项目 | 当前状态 | 优化建议 | 优先级 |
|------|---------|---------|--------|
| 音量控制 | 寄存器已输出，未接入PWM | 在PWM比较前增加音量衰减器 | 中 |
| 削波检测 | 寄存器已定义，未实现 | 增加削波比较器和锁存 | 低 |
| 扩频调制 | 寄存器已定义，未实现 | 在载波计数器增加抖动 | 低 |
| HPF高通滤波 | 寄存器已定义，未实现 | 在audio_interface后增加HPF | 低 |
| PBTL模式 | 寄存器位已解码，未实现 | 在PWM输出级合并通道 | 低 |

> **审核完成后请告知是否需要修改，确认后我将开始编写/修改代码。**
