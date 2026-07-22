# TAS6424E-Q1 RTL 架构设计文档 (v2.0)

> **版本**: v2.0.0  
> **日期**: 2026-07-14  
> **状态**: 架构完善阶段  
> **基于**: TI TAS6424E-Q1 数据手册 (ZHCSO75A, 2021年11月修订版A)
>
> **关联文档**: 
> - `state_machine_detailed_design.md` — 状态机详细设计 (基于doc_src原始图)
> - `fsm_design.md` — 状态机总览 (v3.0)
> - `clock_reset_design.md` — 时钟与复位设计
> - `register_map_design.md` — 寄存器映射详细设计
> - `module_interface_design.md` — 模块接口设计
> - `timing_diagram.md` — 时序图
> - `module_functional_design.md` — 模块功能设计

---

## 1. 芯片概述

### 1.1 器件基本信息

| 属性 | 值 |
|------|-----|
| 器件型号 | TAS6424E-Q1 |
| 类型 | 4通道数字输入D类汽车音频放大器 |
| 封装 | HSSOP-56 (DKQ) |
| 通信接口 | I2C从机 (100/400 kbps)，4个地址选项 |
| 电源 | VDD=3.3V, VBAT=4.5~18V, PVDD=4.5~26.4V |
| 温度 | -40°C 至 +125°C (TA)，Grade 1 |
| 认证 | AEC-Q100 |
| 开关频率 | 384kHz / 2.1MHz (可编程) |
| 通道电流限制 | 7.2A (Typ) |

### 1.2 数据手册核心设计块

根据数据手册 §9.1，芯片包含以下核心设计块：

| 设计块 | 描述 | 对应RTL模块 |
|--------|------|-----------|
| Serial Audio Port | 音频串行接口 | `audio_interface` |
| Clock Management | PLL与时钟管理 (模拟) / 时钟监控 (数字) | `clock_monitor` |
| High-Pass Filter + Volume Control | DC隔直 + 音量控制 (-100~+24dB) | 集成于`audio_interface` (预留) |
| Pulse Width Modulator (PWM) | 高速PWM调制器 | `pwm_generator` |
| Gate Drive | 栅极驱动 (模拟) | 不可综合(模拟部分) |
| Power FETs | BTL功率级 (模拟) | 不可综合(模拟部分) |
| Diagnostics | DC/AC负载诊断 | `diagnostic_ctrl` |
| Protection | 过流/过温/过压/欠压保护 | `protection` + `fault_monitor` |
| Power Supply | 电源管理 (模拟) | 不可综合(模拟部分) |
| I2C Serial Bus | I2C通信 | `i2c_slave` |

---

## 2. 设计目标

### 2.1 RTL模型设计范围

本RTL模型实现TAS6424E-Q1的**数字核心部分**，以构建一个可综合、可验证的行为级模型：

**RTL实现范围（可综合数字逻辑）**：
- I2C从机控制器 (SCL/SDA同步+地址匹配+读写FSM)
- 寄存器文件 (0x00-0x79完整寄存器空间，含位域)
- 芯片主状态机 (STANDBY/Hi-Z/MUTE/PLAY/DIAG)
- 4通道独立通道状态机 (含故障锁存/恢复)
- 串行音频接口 (I2S/LJ/RJ/DSP/TDM全模式，时钟同步)
- PWM生成器 (三角波载波+比较器+BTL正反相输出)
- 诊断控制器 (DC/AC诊断FSM + 报告生成)
- 故障监控器 (故障锁存、编码到寄存器格式)
- 引脚控制 (FAULT/WARN输出，去抖动，开漏模拟)
- 时钟监控器 (MCLK/SCLK/FSYNC活动检测+超时)
- 保护电路 (去毛刺+OTSD恢复逻辑)

**模拟部分（仅端口建模，不可综合辅助信号）**：
- 电源管理 (VDD/VBAT/PVDD上电检测端口)
- 过温检测 (OTW(i)/OTSD(i)模拟前端端口)
- 过流检测 (OC逐周期限制端口)
- DC检测端口
- 栅极驱动与BTL功率级

### 2.2 设计原则

| 原则 | 实现方式 |
|------|----------|
| **模块化** | 12个独立功能模块，顶层集成，每个模块对应datasheet中的功能块 |
| **可追溯性** | 所有寄存器位域、状态编码、时序参数均可追溯到datasheet具体章节 |
| **可验证性** | 预留测试端口，支持自校验testbench + I2C/音频主机BFM模型 |
| **可综合性** | 纯Verilog HDL (IEEE 1364-2005)，无initial延迟，无系统任务 |
| **复位策略** | 全局异步复位同步释放，rst_n低有效；所有寄存器有明确复位值 |
| **时钟策略** | 单主时钟域(clk)运行所有RTL逻辑；音频/I2C时钟经同步后处理 |

---

## 3. 引脚映射与分析

### 3.1 引脚分类总表

从数据手册 §6 (表6-1) 提取引脚信息，按功能分类：

#### 3.1.1 数字控制引脚

| 引脚名 | 编号 | 方向 | RTL连接 | 描述 |
|--------|------|------|---------|------|
| STANDBY | 24 | DI (低有效) | `pin_control` → `state_machine` | 待机控制，内部100kΩ下拉 |
| MUTE | 25 | DI (低有效) | `pin_control` → `state_machine` | 硬件静音，内部100kΩ下拉 |
| FAULT | 26 | DO (开漏,低有效) | `pin_control` → 引脚 | 故障报告，内部100kΩ上拉 |
| WARN | 27 | DO (开漏,低有效) | `pin_control` → 引脚 | 警告输出，内部100kΩ上拉 |

#### 3.1.2 I2C通信引脚

| 引脚名 | 编号 | 方向 | RTL连接 | 描述 |
|--------|------|------|---------|------|
| SCL | 20 | DI | `i2c_slave` | I2C时钟输入 |
| SDA | 21 | DI/O | `i2c_slave` | I2C数据输入/输出 |
| I2C_ADDR0 | 22 | DI | `i2c_slave` | I2C地址选择位0 |
| I2C_ADDR1 | 23 | DI | `i2c_slave` | I2C地址选择位1 |

**I2C地址映射** (datasheet 表9-8):

| I2C_ADDR1 | I2C_ADDR0 | Write Addr | Read Addr |
|-----------|-----------|------------|-----------|
| 0 | 0 | 0xD4 | 0xD5 |
| 0 | 1 | 0xD6 | 0xD7 |
| 1 | 0 | 0xD8 | 0xD9 |
| 1 | 1 | 0xDA | 0xDB |

#### 3.1.3 音频接口引脚

| 引脚名 | 编号 | 方向 | RTL连接 | 描述 |
|--------|------|------|---------|------|
| MCLK | 12 | DI | `audio_interface` + `clock_monitor` | 音频主时钟 (max 25MHz) |
| SCLK | 13 | DI | `audio_interface` + `clock_monitor` | 音频位时钟 (BCLK) |
| FSYNC | 14 | DI | `audio_interface` + `clock_monitor` | 帧同步 (LRCLK) |
| SDIN1 | 15 | DI | `audio_interface` | TDM数据 / I2S CH1+CH2 |
| SDIN2 | 16 | DI | `audio_interface` | I2S CH3+CH4 / TDM时接地 |

#### 3.1.4 输出通道引脚

| 引脚名 | 编号 | 方向 | RTL连接 | 描述 |
|--------|------|------|---------|------|
| OUT_1P/1M | 34/32 | PO/NO | `pwm_generator` | 通道1 BTL正/负输出 |
| OUT_2P/2M | 40/38 | PO/NO | `pwm_generator` | 通道2 BTL正/负输出 |
| OUT_3P/3M | 47/45 | PO/NO | `pwm_generator` | 通道3 BTL正/负输出 |
| OUT_4P/4M | 53/51 | PO/NO | `pwm_generator` | 通道4 BTL正/负输出 |

#### 3.1.5 保护/诊断输入端口 (模拟前端信号)

| 信号 | 方向 | RTL连接 | 描述 |
|------|------|---------|------|
| `otw_raw` | DI | `protection` | 全局过温警告原始信号 |
| `otsd_raw` | DI | `protection` | 全局过温关断原始信号 |
| `otw_ch1_raw` ~ `ch4_raw` | DI×4 | `protection` | 通道过温警告原始信号 |
| `otsd_ch1_raw` ~ `ch4_raw` | DI×4 | `protection` | 通道过温关断原始信号 |
| `vbat_uv_raw` | DI | `protection` | VBAT欠压原始信号 |
| `vbat_ov_raw` | DI | `protection` | VBAT过压原始信号 |
| `pvdd_uv_raw` | DI | `protection` | PVDD欠压原始信号 |
| `pvdd_ov_raw` | DI | `protection` | PVDD过压原始信号 |
| `oc_ch1` ~ `ch4` | DI×4 | `fault_monitor` | 通道过流检测输入 |
| `dc_ch1` ~ `ch4` | DI×4 | `fault_monitor` | 通道DC偏移检测输入 |
| `por_vdd` | DI | `fault_monitor` | VDD POR检测输入 |

---

## 4. 时钟架构

### 4.1 时钟域划分

```
┌─────────────────────────────────────────────────────────────────┐
│                       时钟域架构                                 │
├──────────────────┬──────────────────────────────────────────────┤
│ clk (10MHz)      │ 【主时钟域】所有RTL数字逻辑运行于此域        │
│                  │ i2c_slave, register_file, state_machine,     │
│                  │ channel_fsm, pwm_generator, diagnostic_ctrl,│
│                  │ fault_monitor, pin_control, clock_monitor,   │
│                  │ protection                                   │
├──────────────────┼──────────────────────────────────────────────┤
│ scl_i (I2C SCL)  │ 【I2C时钟域】                                 │
│                  │ 经2级DFF同步到clk域后驱动I2C状态机           │
│                  │ 频率: 100kHz或400kHz                          │
├──────────────────┼──────────────────────────────────────────────┤
│ mclk_i           │ 【音频主时钟域】仅输入采样后同步              │
│                  │ 频率: 128/256/512 × fs, max 25MHz             │
├──────────────────┼──────────────────────────────────────────────┤
│ sclk_i (BCLK)    │ 【音频位时钟域】经同步后采样SDIN数据          │
│                  │ 频率: 32/64 × fs (I2S/LJ/RJ)                 │
│                  │       128/256 × fs (TDM)                     │
├──────────────────┼──────────────────────────────────────────────┤
│ fsync_i (LRCLK)  │ 【帧同步域】经同步后检测帧边界               │
│                  │ 频率: 44.1/48/96 kHz                         │
└──────────────────┴──────────────────────────────────────────────┘
```

### 4.2 跨时钟域同步策略

```
异步输入信号 ──► [DFF1] ──► [DFF2] ──► 同步到clk域的信号
                        clk上升沿采样 ×2，两级同步消除亚稳态
```

| 源时钟域 | 目标时钟域 | 同步方式 | 延迟 |
|---------|-----------|---------|------|
| I2C SCL | clk | 2级DFF同步器 | 2 clk cycles |
| I2C SDA | clk | 2级DFF同步器 | 2 clk cycles |
| mclk/sclk/fsync | clk | 2级DFF同步器 + 边沿检测 | 2 clk cycles |
| sd_in1/sd_in2 | clk | sclk同步后的下降沿采样 | 采样+1 clk |
| 模拟前端故障信号 | clk | protection模块内去毛刺(多个周期) | FAULT_DEGLITCH_CYCLES |

### 4.3 时钟频率关系 (datasheet §9.3.1.5)

| 采样率 (fs) | MCLK | SCLK (I2S/LJ/RJ) | SCLK (TDM8) | PWM载波 |
|------------|------|-------------------|-------------|---------|
| 44.1 kHz | 5.6448 / 11.2896 / 22.5792 MHz | 1.4112 / 2.8224 MHz | 5.6448 / 11.2896 MHz | 352.8k~2.12M Hz |
| 48 kHz | 6.144 / 12.288 / 24.576 MHz | 1.536 / 3.072 MHz | 6.144 / 12.288 MHz | 384k~2.11M Hz |
| 96 kHz | 12.288 / 24.576 MHz (max) | 3.072 / 6.144 MHz | 12.288 / 24.576 MHz | 384k~2.11M Hz |

---

## 5. 复位架构

### 5.1 复位源与策略

| 复位源 | 类型 | 作用范围 | 条件 |
|--------|------|---------|------|
| `rst_n` (外部) | 硬件复位 | 所有寄存器恢复默认值 | 引脚拉低 |
| POR (VDD) | 上电复位 | 所有寄存器恢复默认值 + POR标志置位 | VDD < VPOR (~2.7V) |
| `soft_reset` (0x00 bit7) | 软件复位 | 所有寄存器恢复默认值 (POR标志保持) | MCU写1 |
| `clear_fault` (0x21 bit7) | 故障清除 | 清除故障锁存、清除FAULT/WARN引脚 | MCU写1 |

### 5.2 复位释放时序 (上电序列, datasheet §9.3.10.1)

```
VBAT/PVDD ────────────────────────────────────────────►
                │
                │ (电源稳定后)
                ▼
VDD ──────────────────────────────────────────────────►
                │
                │ tSTART (12ms max)
                ▼
I2C就绪 ◄──────────────────────────────────────────────►
```

---

## 6. 模块层次结构

### 6.1 顶层模块树

```
tas6424e_top                              # 顶层模块 (56引脚 + 模拟输入端口)
│
├── i2c_slave                             # I2C从机接口
│   ├── [内部] I2C FSM (9状态: IDLE→ADDR→ACK_ADDR→...)
│   ├── [内部] SCL/SDA 2级DFF同步器
│   ├── [内部] START/STOP条件检测
│   └── [内部] 地址匹配 (4个I2C地址选项)
│
├── register_file                         # 寄存器文件 (地址0x00-0x79)
│   ├── [内部] R/W寄存器阵列 (配置寄存器)
│   ├── [内部] R寄存器阵列 (状态报告寄存器)
│   ├── [内部] 地址解码器
│   ├── [内部] 硬件写入仲裁器
│   └── [内部] soft_reset / clear_fault 脉冲生成
│
├── state_machine                         # 芯片主状态机
│   ├── [内部] 2段式FSM (5状态)
│   ├── [内部] 状态转换组合逻辑
│   └── [内部] any_ch_diag/all_ch_hiz检测
│
├── channel_fsm × 4                       # 通道状态机 (4实例)
│   ├── [内部] 组合逻辑: ch_en/ch_mute/ch_diag_active
│   ├── [内部] 时序逻辑: ch_state锁存
│   └── [内部] 故障锁存与恢复
│
├── audio_interface                       # 串行音频接口
│   ├── [内部] MCLK/SCLK/FSYNC 2级同步器
│   ├── [内部] 时钟边沿检测 (上升沿/下降沿)
│   ├── [内部] 模式解码器 (I2S/LJ/RJ/DSP/TDM)
│   ├── [内部] 移位寄存器 (SDIN采样)
│   ├── [内部] 通道数据锁存 (24位×4通道)
│   └── [内部] TDM时隙选择逻辑
│
├── pwm_generator                         # PWM生成器
│   ├── [内部] 三角波载波计数器 (复用, 4通道共享)
│   ├── [内部] 4通道并行比较器
│   ├── [内部] BTL正反相输出生成
│   ├── [内部] MUTE模式50%占空比输出
│   └── [内部] Hi-Z模式输出禁用
│
├── diagnostic_ctrl                       # 诊断控制器
│   ├── [内部] DC诊断FSM (15状态: IDLE/OBSERVATION/4阶段×4通道/DONE)
│   ├── [内部] AC诊断FSM (6状态: IDLE/CH1~4_AC/DONE)
│   ├── [内部] DC/AC诊断计时器
│   ├── [内部] 诊断报告生成
│   └── [内部] DC/AC模式选择
│
├── fault_monitor                         # 故障监控器
│   ├── [内部] 全局故障锁存 (OV/UV/OTSD/CLOCK_LOST)
│   ├── [内部] 通道故障锁存 (OC/DC × 4)
│   ├── [内部] 警告锁存 (OTW/OTW_CH/POR/CLIP)
│   ├── [内部] 故障编码到寄存器格式
│   └── [内部] global_fault_irq / ch_fault 生成
│
├── pin_control                           # 引脚控制
│   ├── [内部] STANDBY/MUTE去抖动
│   ├── [内部] FAULT开漏输出控制
│   ├── [内部] WARN开漏输出控制
│   └── [内部] 遮罩逻辑 (MASK寄存器位)
│
├── clock_monitor                         # 时钟监控器
│   ├── [内部] MCLK活动检测
│   ├── [内部] SCLK活动检测
│   ├── [内部] FSYNC活动检测
│   ├── [内部] 超时计数器 (CLK_TIMEOUT_CYCLES)
│   └── [内部] 时钟比例校验 (可选)
│
└── protection                            # 保护电路
    ├── [内部] OTW/OTSD去毛刺 (多个周期确认)
    ├── [内部] UV/OV去毛刺 (多个周期确认)
    ├── [内部] OTSD自动恢复冷却计时器
    └── [内部] clear_fault清除逻辑
```

### 6.2 模块规模估算

| 模块 | 文件 | FSM状态 | 关键寄存器 | 代码行(估) |
|------|------|---------|-----------|-----------|
| `tas6424e_top` | tas6424e_top.v | - | 0 (仅连线) | ~600 |
| `i2c_slave` | i2c_slave.v | 9 | 8 | ~350 |
| `register_file` | register_file.v | - | 40+ (30+寄存器) | ~500 |
| `state_machine` | state_machine.v | 5 | 2 | ~250 |
| `channel_fsm` | channel_fsm.v | 5 | 3 | ~200 |
| `audio_interface` | audio_interface.v | - | 15 | ~400 |
| `pwm_generator` | pwm_generator.v | - | 12 | ~400 |
| `diagnostic_ctrl` | diagnostic_ctrl.v | DC:15+AC:6 | 10 | ~450 |
| `fault_monitor` | fault_monitor.v | - | 12 | ~400 |
| `pin_control` | pin_control.v | - | 6 | ~250 |
| `clock_monitor` | clock_monitor.v | - | 8 | ~250 |
| `protection` | protection.v | - | 16 | ~300 |
| **合计** | 12文件 | - | ~130 | ~4400 |

---

## 7. 模块间信号连接

### 7.1 总体连接图

```
                        ┌─────────────────────────────────────────────────────────┐
                        │                     tas6424e_top                          │
                        │                                                          │
  I2C ──────────────────┤ i2c_slave ────── wr_en/addr/data ───┐                    │
  SCL/SDA/ADDR[1:0]     │                ◄──── rd_data ────   │                    │
                        │                                      ▼                    │
                        │                            ┌──────────────────┐           │
                        │                            │  register_file   │           │
                        │                            │  (0x00 - 0x79)   │           │
                        │                            └──┬───┬───┬───┬───┘           │
                        │       ┌───────────────────────┘   │   │   └──────────┐    │
                        │       ▼                           │   │              │    │
                        │ ┌──────────────┐                  │   │              │    │
                        │ │state_machine │◄──any_ch_diag───┘   │              │    │
                        │ │  (主FSM)     │──diag_trigger──────►│              │    │
                        │ └──┬───┬───┬───┘                    │              │    │
                        │    │   │   │                        │              │    │
                        │    │   │   └── chip_state (3bit) ───┼──────────────┤    │
                        │    │   │                            │              │    │
                        │    ▼   ▼                            ▼              │    │
                        │ ┌────────────────────────┐  ┌───────────────┐     │    │
                        │ │   channel_fsm × 4      │  │ diagnostic    │     │    │
                        │ │   (通道FSM)            │  │    _ctrl      │     │    │
                        │ └──┬─────────────────────┘  └──┬────┬───┬───┘     │    │
                        │    │ ch_en / ch_mute   diag_active│    │   │       │    │
                        │    ▼                           │    │   │       │    │
  Audio ────────────────┤ ┌──────────────┐               │    │   │       │    │
  MCLK/SCLK/FSYNC/SDIN  │ │audio_interface│              │    │   │       │    │
                        │ └──┬───────────┘               │    │   │       │    │
                        │    │ audio_data[23:0]×4        │    │   │       │    │
                        │    ▼                           │    │   │       │    │
                        │ ┌──────────────┐               │    │   │       │    │
                        │ │pwm_generator │               │    │   │       │    │
                        │ └──┬───────────┘               │    │   │       │    │
                        │    │ out_1p~4m                 │    │   │       │    │
  OUT ──────────────────┤────┘                           │    │   │       │    │
                        │                                │    │   │       │    │
  Analog FE ────────────┤ ┌──────────┐ ┌───────────────┐ │    │   │       │    │
  OTW/OTSD/UV/OV/OC/DC  │ │protection│ │ fault_monitor │ │    │   │       │    │
                        │ └────┬─────┘ └──┬───┬───┬────┘ │    │   │       │    │
                        │      │          │   │   │       │    │   │       │    │
                        │      │          │   │   └── hw_faults ─► register_file │
                        │      │          │   └── global_fault_irq ─► state_machine│
                        │      │          └── ch_fault[3:0] ──► channel_fsm      │
                        │      │                                                  │
                        │      └── fault/warn ──► pin_control ──► FAULT/WARN引脚  │
                        │                                                          │
  Audio CLK ────────────┤ ┌───────────────┐                                       │
  MCLK/SCLK/FSYNC       │ │ clock_monitor │── clock_lost ──► fault_monitor        │
                        │ └───────────────┘                                       │
                        └──────────────────────────────────────────────────────────┘
```

### 7.2 关键信号连接表

详细的信号连接表（含位宽、方向、描述）移入 `module_interface_design.md`。

---

## 8. 寄存器分类总览

### 8.1 寄存器地址空间

完整的寄存器详细位域定义移入 `register_map_design.md`。

**寄存器地址映射总表** (datasheet 表9-9):

| 地址范围 | 类型 | 功能分类 | 寄存器数量 |
|---------|------|---------|-----------|
| 0x00 | R/W | 模式控制 | 1 |
| 0x01-0x02 | R/W | 杂项控制 | 2 |
| 0x03 | R/W | 串行音频端口控制 | 1 |
| 0x04 | R/W | 通道状态控制 | 1 |
| 0x05-0x08 | R/W | 通道音量控制 (CH1~4) | 4 |
| 0x09-0x0B | R/W | DC诊断控制 | 3 |
| 0x0C-0x0E | R | DC诊断报告 | 3 |
| 0x0F | R | 通道状态报告 | 1 |
| 0x10 | R | 通道故障报告 | 1 |
| 0x11-0x12 | R | 全局故障报告 | 2 |
| 0x13 | R | 警告报告 | 1 |
| 0x14 | R/W | 引脚控制 (遮罩) | 1 |
| 0x15-0x16 | R/W | AC诊断控制 | 2 |
| 0x17-0x1A | R | AC诊断报告 (CH1~4) | 4 |
| 0x1B-0x1E | R | AC诊断相位/STI报告 | 4 |
| 0x1F-0x20 | — | 保留 | 2 |
| 0x21 | R/W | 杂项控制3 (清除故障/OTSD恢复) | 1 |
| 0x22-0x24 | R/W | 削波控制/窗口/警告 | 3 |
| 0x25 | R/W | ILIMIT状态 | 1 |
| 0x26 | R/W | 杂项控制4 (高通滤波器) | 1 |
| 0x27 | — | 保留 | 1 |
| 0x28 | R/W | 杂项控制5 (相位MSB) | 1 |
| 0x77-0x79 | R/W | 扩频控制 | 3 |

**总计**: 约42个寄存器 (含保留)

---

## 9. 数据流分析

详细的时序分析和数据流移入 `timing_diagram.md`。

### 9.1 数据流路径总结

| 路径类型 | 源 → 目标 | 延迟 | 关键特性 |
|---------|-----------|------|---------|
| **控制流** | MCU I2C → 寄存器 → 各模块 | ~3 clk (300ns) | I2C字节级→寄存器→模块输出 |
| **音频流** | 外部音频源 → 音频接口 → PWM → 输出 | ~1帧+2 clk | 跨时钟域同步+移位采样 |
| **故障流** | 模拟前端 → 保护 → 故障监控 → 状态机 | ~10us+4 clk | 去毛刺+锁存+FSM响应 |
| **诊断流** | MCU配置 → 状态机 → 诊断控制 → 寄存器 | ~100ms max | 长超时+报告生成 |

---

## 10. 保护分层架构

详细的状态机设计移入 `fsm_design.md`。

### 10.1 三层故障保护 (datasheet 表9-6, 9-7)

```
┌──────────────────────────────────────────────────────────────────┐
│ 第一层：全局故障 (Global Faults) → 芯片强制Hi-Z + FAULT引脚    │
│ ├── PVDD OV (overvoltage)         → 0x11 bit3                    │
│ ├── VBAT OV (overvoltage)         → 0x11 bit2                    │
│ ├── PVDD UV (undervoltage)        → 0x11 bit1                    │
│ ├── VBAT UV (undervoltage)        → 0x11 bit0                    │
│ ├── INVALID CLOCK                 → 0x11 bit4                    │
│ ├── OTSD (global overtemp)        → 0x12 bit4                    │
│ └── POR (VDD power-on-reset)      → 进入STANDBY (WARN)           │
├──────────────────────────────────────────────────────────────────┤
│ 第二层：通道故障 (Channel Faults) → 对应通道Hi-Z + FAULT引脚    │
│ ├── OC_CH1~4 (overcurrent shutdown)→ 0x10 bit7~4                │
│ ├── DC_CH1~4 (DC detect)          → 0x10 bit3~0                 │
│ └── OTSD_CH1~4 (per-channel)      → 0x12 bit3~0                 │
├──────────────────────────────────────────────────────────────────┤
│ 第三层：警告 (Warnings) → WARN引脚 + Warnings寄存器              │
│ ├── OTW (global overtemp warn)    → 0x13 bit4                    │
│ ├── OTW_CH1~4 (per-channel warn)  → 0x13 bit3~0                 │
│ ├── POR (VDD POR occurred)        → 0x13 bit5                    │
│ ├── CLIP_DETECT                   → 0x24 + WARN引脚              │
│ └── ILIMIT (cycle-by-cycle limit) → 0x25 + WARN引脚 (不锁存)     │
└──────────────────────────────────────────────────────────────────┘
```

---

## 11. 工作模式转换 (datasheet 表9-5)

**5层状态机层次**:

```
顶层包装 (3态) → 芯片主状态机 (5态) → 通道状态机×4 (5态) → DC/AC诊断FSM
   │                  │                    │
PowerOn            Hi-Z                 CH_HIGH_Z
STANDBY            Play                 CH_MUTE
ACT                Mute                 CH_PLAY
                   Single_Diag          CH_SINGLE_DC_DIAG
                   Auto_Diag            CH_AC_DIAG
```

| 状态 | 输出FET | 振荡器 | I2C | 转换条件 |
|------|---------|--------|-----|---------|
| STANDBY (顶层) | Hi-Z | 停止 | 关闭 | STANDBY_N=1 |
| ACT (顶层) | (主状态机决定) | 运行 | 活跃 | STANDBY_N=0 |
| Hi-Z (主) | Hi-Z | 运行 | 活跃 | 默认/故障/0x04配置Hi-Z |
| Mute (主) | 50%占空比开关 | 运行 | 活跃 | 0x04配置静音/硬件MUTE |
| Play (主) | 音频调制开关 | 运行 | 活跃 | 0x04配置播放 |
| Single_Diag (主) | Hi-Z (诊断中) | 运行 | 活跃 | 0x04配置诊断态 |
| Auto_Diag (主) | Hi-Z (诊断中) | 运行 | 活跃 | 故障时自动进入 |

**关键设计注释**:
- 芯片上电复位处于Hi-Z态，且0x13复位标志位置1
- 芯片在任何状态，STANDBY引脚拉低时进入待机；拉高时回到原状态
- 从静音/播放触发待机再唤醒，会触发自动DC诊断（除非LDG_BYPASS=1）
- AC诊断只能从CH_HIGH_Z进入

> 完整状态机转换图详见 `state_machine_detailed_design.md`

---

## 12. 音频接口模式支持

详细的音频接口设计移入 `module_functional_design.md`。

| 模式 | SAP控制(0x03[2:0]) | 数据格式 | FSYNC极性 |
|------|---------------------|---------|-----------|
| I2S | 100 | MSB-first, 延迟1个SCLK | L=0, R=1 |
| Left-Justified | 101 | MSB-first, 无延迟 | L=1, R=0 |
| Right-Justified (24b) | 000 | MSB-first, LSB对齐 | L=1, R=0 |
| Right-Justified (20b) | 001 | MSB-first, LSB对齐 | L=1, R=0 |
| Right-Justified (18b) | 010 | MSB-first, LSB对齐 | L=1, R=0 |
| Right-Justified (16b) | 011 | MSB-first, LSB对齐 | L=1, R=0 |
| DSP | 110 | 与I2S类似, FSYNC脉冲 | 脉冲指示 |
| TDM4/TDM8 | 自动检测 | SDIN1承载, TDM时隙 | 脉冲指示 |

---

## 13. PWM开关频率选项 (datasheet 表9-3)

| 0x02[6:4] | 44.1kHz fs | 48kHz fs | 96kHz fs |
|-----------|------------|----------|----------|
| 000 (8×fs) | 352.8 kHz | 384 kHz | 384 kHz |
| 001 (10×fs) | 441 kHz | 480 kHz | 480 kHz |
| 101 (38×fs) | 1.68 MHz | 1.82 MHz | 1.82 MHz |
| 110 (44×fs, default) | 1.94 MHz | 2.11 MHz | 2.11 MHz |
| 111 (48×fs) | 2.12 MHz | 不支持 | 不支持 |

---

## 14. 设计约束与参数化

### 14.1 全局参数

| 参数 | 默认值 | 描述 |
|------|--------|------|
| CLK_FREQ | 10_000_000 | 系统主时钟频率 (Hz) |
| DEBOUNCE_CYCLES | 500 | STANDBY/MUTE去抖周期 (50us @10MHz) |
| FAULT_DEGLITCH_CYCLES | 100 | 故障去毛刺周期 (10us @10MHz) |
| CLK_TIMEOUT_CYCLES | 24'hFFFFF | 时钟丢失超时 (~100ms @10MHz) |
| DIAG_TIMEOUT_CYCLES | 24'hFFFFF | 诊断超时 (~100ms @10MHz) |
| OTSD_RECOVERY_CYCLES | 32'hFFFFFF | OTSD恢复冷却 (~16s @10MHz) |

### 14.2 关键路径分析

| 路径 | 频率/延迟 | 优化策略 |
|------|----------|---------|
| PWM载波比较 | 2.1MHz | 载波计数器复用，4通道并行比较器 |
| I2C状态机 | 100/400kHz | SCL同步后单周期FSM转换 |
| 音频数据移位 | <25MHz (SCLK) | SCLK下降沿单bit采样 |
| 故障响应 | <10.4us | 去毛刺+组合+锁存 |

---

## 15. 审核检查清单

请审核以下关键设计点：

- [ ] 模块划分是否完整覆盖datasheet §9.1核心设计块
- [ ] 引脚映射是否与datasheet §6一致
- [ ] 寄存器地址空间是否覆盖0x00-0x79所有寄存器
- [ ] 故障保护三层架构是否与datasheet 表9-6/9-7一致
- [ ] 音频接口模式是否覆盖I2S/LJ/RJ/DSP/TDM全模式
- [ ] PWM频率选项是否与datasheet 表9-3一致
- [ ] 时钟架构是否清晰定义跨域处理策略
- [ ] 复位源和上电时序是否与datasheet §9.3.10一致
- [ ] 参数化设计是否便于后续移植

> **审核完成后请告知是否需要修改。确认后将继续编写后续的详细设计文档。**
