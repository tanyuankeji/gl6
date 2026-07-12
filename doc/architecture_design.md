# TAS6424E-Q1 RTL 架构设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-11  
> **状态**: 待审核  
> **关联文件**: `design_spec.md`（设计规格）、`module_design_detail.md`（模块详细设计）

---

## 1. 架构概述

### 1.1 设计目标

基于 TI TAS6424E-Q1 数据手册，构建完整的4通道数字输入D类汽车音频放大器RTL模型，实现：

- I2C 从机控制接口（4个地址选项，100/400kbps）
- 0x00-0x79 寄存器地址空间（30+寄存器）
- 芯片主状态机（STANDBY/Hi-Z/MUTE/PLAY/DIAG）
- 4通道独立通道状态机
- I2S/LJ/DSP/TDM 8种音频接口模式
- 4通道BTL PWM输出（2.1MHz开关频率）
- DC/AC负载诊断
- 过流/过温/欠压/过压/时钟丢失多重保护

### 1.2 设计原则

| 原则 | 实现方式 |
|------|----------|
| 模块化 | 12个独立功能模块，顶层集成 |
| 可追溯性 | 每个模块对应datasheet功能块 |
| 可验证性 | 自校验testbench + I2C/音频主机模型 |
| 可综合性 | 纯Verilog HDL（IEEE 1364-2005），无initial延迟 |
| 复位策略 | 全局异步复位同步释放，rst_n低有效 |

### 1.3 时钟架构

```
┌─────────────────────────────────────────────────┐
│                  时钟域划分                      │
├─────────────┬───────────────────────────────────┤
│ clk (10MHz) │ 主时钟域——所有RTL逻辑运行于此域   │
│             │ I2C从机、寄存器文件、状态机、      │
│             │ 诊断、故障监控、保护电路           │
├─────────────┼───────────────────────────────────┤
│ mclk        │ 音频主时钟——仅输入采样            │
│ sclk (BCLK) │ 音频位时钟——经同步后采样SDIN数据  │
│ fsync       │ 帧同步——经同步后检测帧起始        │
├─────────────┼───────────────────────────────────┤
│ I2C SCL     │ I2C时钟——经同步后驱动I2C状态机    │
└─────────────┴───────────────────────────────────┘
```

**跨时钟域处理**：
- 音频时钟（mclk/sclk/fsync）→ 经2级DFF同步到clk域
- I2C SCL/SDA → 经2级DFF同步到clk域
- 所有跨域信号在clk域统一处理，避免亚稳态

---

## 2. 模块层次结构

### 2.1 模块树

```
tas6424e_top                          # 顶层模块（56引脚接口）
├── i2c_slave                         # I2C从机接口
│   └── [内部] I2C状态机（9状态FSM）
├── register_file                     # 寄存器文件（0x00-0x79）
│   └── [内部] 寄存器阵列 + 读写解码
├── state_machine                     # 芯片主状态机
│   └── [内部] 两段式FSM（5状态）
├── channel_fsm × 4                   # 通道状态机（4实例）
│   └── [内部] 故障锁存 + 状态控制
├── audio_interface                   # 音频接口
│   └── [内部] 时钟同步 + 数据移位 + 模式解码
├── pwm_generator                     # PWM生成器
│   └── [内部] 三角波载波 + 比较器 + BTL输出
├── diagnostic_ctrl                   # 诊断控制器
│   └── [内部] 诊断状态机（4状态）
├── fault_monitor                     # 故障监控器
│   └── [内部] 故障锁存 + 编码
├── pin_control                       # 引脚控制
│   └── [内部] 去抖动 + 开漏输出
├── clock_monitor                     # 时钟监控器
│   └── [内部] 时钟活动检测 + 超时
└── protection                        # 保护电路
    └── [内部] 去毛刺 + OTSD恢复
```

### 2.2 模块规模统计

| 模块 | 文件 | 状态数 | 关键寄存器数 | 代码行数(估) |
|------|------|--------|-------------|-------------|
| `tas6424e_top` | tas6424e_top.v | - | 0 | ~540 |
| `i2c_slave` | i2c_slave.v | 9 | 8 | ~350 |
| `register_file` | register_file.v | - | 30+ | ~400 |
| `state_machine` | state_machine.v | 5 | 2 | ~200 |
| `channel_fsm` | channel_fsm.v | - | 3 | ~150 |
| `audio_interface` | audio_interface.v | - | 12 | ~350 |
| `pwm_generator` | pwm_generator.v | - | 15 | ~400 |
| `diagnostic_ctrl` | diagnostic_ctrl.v | 4 | 10 | ~300 |
| `fault_monitor` | fault_monitor.v | - | 12 | ~350 |
| `pin_control` | pin_control.v | - | 6 | ~200 |
| `clock_monitor` | clock_monitor.v | - | 6 | ~200 |
| `protection` | protection.v | - | 12 | ~250 |
| **合计** | 13文件 | - | ~120 | ~3700 |

---

## 3. 模块间连接关系

### 3.1 总体连接图

```
                    ┌──────────────────────────────────────────────────┐
                    │                  tas6424e_top                     │
                    │                                                  │
  I2C ──────────────┤ i2c_slave ────── reg_wr/rd ───┐                 │
  SCL/SDA/ADDR      │                                  │                 │
                    │                                  ▼                 │
                    │                         ┌────────────────┐         │
                    │                         │ register_file  │         │
                    │                         │ (0x00-0x79)    │         │
                    │                         └───┬────┬───┬───┘         │
                    │              0x04/0x21      │    │   │ 0x00-0x79  │
                    │                  ┌───────────┘    │   └──┬────────┤
                    │                  ▼                ▼      ▼        │
                    │          ┌──────────────┐ ┌──────────┐ ┌────────┐ │
                    │          │ state_machine│ │diagnostic│ │其他模块│ │
                    │          │  (主FSM)     │ │  _ctrl   │ │(pwm等) │ │
                    │          └──┬───┬───────┘ └────┬─────┘ └────────┘ │
                    │    chip_state│   │diag_trig    │diag_done           │
                    │             │   │              │                    │
                    │     ┌───────┘   │              │                    │
                    │     ▼           ▼              │                    │
                    │  ┌────────────────────────┐    │                    │
                    │  │  channel_fsm × 4       │    │                    │
                    │  │  (通道FSM)              │    │                    │
                    │  └──┬─────────────────────┘    │                    │
                    │     │ ch_en/ch_mute             │                    │
                    │     ▼                           │                    │
  Audio ────────────┤  ┌──────────────┐               │                    │
  MCLK/SCLK/        │  │audio_interface│              │                    │
  FSYNC/SDIN        │  └──┬───────────┘               │                    │
                    │     │ audio_data[23:0]×4        │                    │
                    │     ▼                           │                    │
                    │  ┌──────────────┐                                    │
                    │  │pwm_generator │                                    │
                    │  └──┬───────────┘                                    │
                    │     │ out_1p~4m                                       │
  OUT ──────────────┤─────┘                                                │
                    │                                                      │
                    │  ┌──────────┐  ┌────────────┐  ┌──────────┐         │
  Analog FE ────────┤─►│protection│─►│fault_monitor│─►│pin_control│── FAULT│
  OTW/OTSD/UV/OV    │  └──────────┘  └──┬───┬─────┘  └──────────┘── WARN │
                    │                     │   │                              │
                    │          fault_irq  │   │ hw_faults                    │
                    │                     │   └──► register_file (0x10-0x13)│
                    │                     └──────► state_machine            │
                    │                                                      │
  Audio CLK ────────┤─►┌───────────────┐                                   │
  MCLK/SCLK/FSYNC   │  │clock_monitor  │── clock_lost ──► fault_monitor    │
                    │  └───────────────┘                                   │
                    └──────────────────────────────────────────────────────┘
```

### 3.2 信号连接详表

#### 3.2.1 I2C从机 → 寄存器文件

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `reg_wr_en` | 1 | i2c_slave → register_file | 寄存器写使能脉冲 |
| `reg_wr_addr` | 8 | i2c_slave → register_file | 寄存器写地址 |
| `reg_wr_data` | 8 | i2c_slave → register_file | 寄存器写数据 |
| `reg_rd_en` | 1 | i2c_slave → register_file | 寄存器读使能脉冲 |
| `reg_rd_addr` | 8 | i2c_slave → register_file | 寄存器读地址 |
| `reg_rd_data` | 8 | register_file → i2c_slave | 寄存器读数据返回 |

#### 3.2.2 寄存器文件 → 各模块（配置输出）

| 信号 | 位宽 | 目的模块 | 源寄存器 | 描述 |
|------|------|---------|---------|------|
| `reg_mode_ctrl` | 8 | (顶层) | 0x00 | 模式控制 |
| `reg_misc_ctrl1` | 8 | (预留) | 0x01 | 杂项控制1 |
| `reg_misc_ctrl2` | 8 | pwm_generator | 0x02 | PWM频率配置[6:4] |
| `reg_sap_ctrl` | 8 | audio_interface | 0x03 | 音频模式[2:0] |
| `reg_ch_state_ctrl` | 8 | state_machine/channel_fsm | 0x04 | 通道状态控制 |
| `reg_ch1~4_vol` | 8×4 | (预留) | 0x05-0x08 | 音量控制 |
| `reg_dc_diag_ctrl1~3` | 8×3 | diagnostic_ctrl | 0x09-0x0B | DC诊断控制 |
| `reg_pin_ctrl` | 8 | pin_control | 0x14 | 引脚控制配置 |
| `reg_ac_diag_ctrl1~2` | 8×2 | diagnostic_ctrl | 0x15-0x16 | AC诊断控制 |
| `reg_misc_ctrl3` | 8 | (顶层) | 0x21 | CLEAR_FAULT[7], OTSD_AUTO_RCV[3] |
| `reg_clip_ctrl` | 8 | (预留) | 0x22 | 削波控制 |
| `reg_misc_ctrl4/5` | 8×2 | (预留) | 0x26/0x28 | 杂项控制 |
| `reg_ss_ctrl1~3` | 8×3 | (预留) | 0x77-0x79 | 扩频控制 |

#### 3.2.3 内部模块 → 寄存器文件（硬件写入）

| 信号 | 位宽 | 源模块 | 目标寄存器 | 描述 |
|------|------|--------|----------|------|
| `hw_dc_diag_rpt1~3` | 8×3 | diagnostic_ctrl | 0x0C-0x0E | DC诊断报告 |
| `hw_ch_state_rpt` | 8 | 顶层组装 | 0x0F | 通道状态报告 |
| `hw_ch_faults` | 8 | fault_monitor | 0x10 | 通道故障 |
| `hw_global_fault1` | 8 | fault_monitor | 0x11 | 全局故障1 |
| `hw_global_fault2` | 8 | fault_monitor | 0x12 | 全局故障2 |
| `hw_warnings` | 8 | fault_monitor | 0x13 | 警告 |
| `hw_ac_diag_rpt_ch1~4` | 8×4 | diagnostic_ctrl | 0x17-0x1A | AC诊断报告 |

#### 3.2.4 状态机控制信号

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `chip_state` | 3 | state_machine → channel_fsm/pwm/clock_mon/fault_mon | 芯片全局状态 |
| `diag_trigger` | 1 | state_machine → diagnostic_ctrl/channel_fsm | 诊断触发脉冲 |
| `diag_done` | 1 | diagnostic_ctrl → state_machine/channel_fsm | 诊断完成信号 |
| `global_fault_irq` | 1 | fault_monitor → state_machine | 全局故障中断 |
| `standby_n_int` | 1 | pin_control → state_machine | 去抖动后standby |
| `clear_fault` | 1 | register_file → state_machine/fault_mon/protection | 清除故障 |
| `soft_reset` | 1 | register_file → (顶层) | 软件复位(0x00 bit7) |

#### 3.2.5 通道控制信号（每通道）

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `ch_state_req` | 2 | register_file[0x04] → channel_fsm | 通道状态请求 |
| `ch_fault` | 1 | fault_monitor → channel_fsm | 通道故障 |
| `ch_state` | 2 | channel_fsm → 顶层组装(0x0F) | 通道当前状态 |
| `ch_en` | 1 | channel_fsm → pwm_generator | 通道使能(PWM允许) |
| `ch_mute_mode` | 1 | channel_fsm → pwm_generator | 通道静音模式 |
| `ch_diag_active` | 1 | channel_fsm → diagnostic_ctrl | 通道诊断进行中 |

#### 3.2.6 音频数据流

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `audio_data_ch1~4` | 24×4 | audio_interface → pwm_generator | 4通道24位音频数据 |
| `audio_valid` | 1 | audio_interface → (预留) | 数据有效脉冲 |

#### 3.2.7 故障保护信号流

| 信号 | 位宽 | 方向 | 描述 |
|------|------|------|------|
| `otw_raw`等 | 1×6 | 引脚 → protection | 原始模拟前端输入 |
| `otw_int`等 | 1×6 | protection → fault_monitor | 去毛刺后故障信号 |
| `clock_lost` | 1 | clock_monitor → fault_monitor | 时钟丢失 |
| `oc_ch1~4` | 1×4 | 引脚 → fault_monitor | 过流输入(直接) |
| `dc_ch1~4` | 1×4 | 引脚 → fault_monitor | 直流检测(直接) |
| `fault_n` | 1 | pin_control → 引脚 | 故障输出(开漏) |
| `warn_n` | 1 | pin_control → 引脚 | 警告输出(开漏) |

---

## 4. 数据流分析

### 4.1 控制流（I2C配置路径）

```
MCU I2C Master
    │
    │ START + 7bit Addr + W
    ▼
i2c_slave (SCL同步采样, 地址匹配)
    │
    │ reg_wr_en + reg_wr_addr + reg_wr_data
    ▼
register_file (地址解码, 写入对应寄存器)
    │
    ├──► reg_ch_state_ctrl[0x04] ──► state_machine (判断全局状态转换)
    │                             ──► channel_fsm (每通道状态请求)
    ├──► reg_misc_ctrl2[0x02]   ──► pwm_generator (PWM频率配置)
    ├──► reg_sap_ctrl[0x03]     ──► audio_interface (音频模式选择)
    ├──► reg_dc_diag_ctrl[0x09] ──► diagnostic_ctrl (诊断参数)
    ├──► reg_misc_ctrl3[0x21]   ──► clear_fault信号 (清除锁存故障)
    │                             ──► otsd_auto_recovery (过温恢复)
    └──► reg_pin_ctrl[0x14]     ──► pin_control (引脚配置)
```

**延迟分析**：I2C写入到寄存器生效 = 1个clk周期（寄存器写入延迟）

### 4.2 音频流（播放路径）

```
外部音频源
    │
    │ MCLK + SCLK + FSYNC + SDIN1/SDIN2
    ▼
audio_interface
    │ (1) SCLK/FSYNC 2级同步到clk域
    │ (2) 边沿检测：sclk_falling, fsync_rising
    │ (3) 根据sap_mode选择解码模式
    │ (4) 移位寄存器在sclk_falling采样SDIN
    │ (5) FSYNC边沿锁存24位数据到通道寄存器
    │
    │ audio_data_ch1~4 [23:0]
    ▼
pwm_generator
    │ (1) 三角波载波计数器（pwm_freq配置频率）
    │ (2) 音频数据与载波比较
    │ (3) ch_en=1且ch_mute=0：PWM调制输出
    │ (4) ch_en=1且ch_mute=1：50%占空比方波
    │ (5) ch_en=0：输出0（Hi-Z）
    │
    │ out_1p/1m ~ out_4p/4m
    ▼
外部BTL负载（扬声器）
```

**延迟分析**：
- 音频数据采样到锁存：1个音频帧周期（~20.8us @48kHz）
- 锁存到PWM输出：1个clk周期

### 4.3 故障流（保护路径）

```
模拟前端 / 外部输入
    │
    │ otw_raw / otsd_raw / vbat_uv_raw / vbat_ov_raw / pvdd_uv_raw / pvdd_ov_raw
    ▼
protection (去毛刺：连续FAULT_DEGLITCH_CYCLES个周期确认)
    │
    │ otw_int / otsd_int / vbat_uv_int / vbat_ov_int / pvdd_uv_int / pvdd_ov_int
    ▼
fault_monitor (故障锁存 + 编码到寄存器格式)
    │
    ├──► hw_global_fault1[0x11] ──► register_file (MCU可读)
    ├──► hw_global_fault2[0x12] ──► register_file
    ├──► hw_warnings[0x13]      ──► register_file
    ├──► global_fault_irq ──────► state_machine (触发Hi-Z转换)
    ├──► ch1~4_fault ───────────► channel_fsm (对应通道进Hi-Z)
    └──► (间接) pin_control ────► fault_n引脚拉低

并行路径：
clock_monitor ── clock_lost ──► fault_monitor ──► (同上)
oc_ch1~4 / dc_ch1~4 ──────────► fault_monitor ──► (同上)
```

**延迟分析**：
- protection去毛刺：FAULT_DEGLITCH_CYCLES × clk_period（10us @10MHz）
- fault_monitor锁存：1个clk周期
- state_machine响应：1个clk周期
- **总故障响应延迟**：~10us + 2个clk周期

### 4.4 诊断流（DC诊断路径）

```
MCU配置0x04寄存器通道状态=CH_DC_DIAG(2'b11)
    │
    ▼
state_machine检测any_ch_diag
    │
    │ chip_state → CHIP_DIAG, diag_trigger脉冲
    ▼
channel_fsm (对应通道进入DC_DIAG态)
    │
    │ ch_diag_active=1
    ▼
diagnostic_ctrl (诊断状态机运行)
    │ (1) DIAG_IDLE → DIAG_DC_RUN (diag_trigger触发)
    │ (2) 运行DC诊断计时（模拟前端测量）
    │ (3) 生成诊断报告（开路/短路/正常）
    │ (4) DIAG_DC_RUN → DIAG_DONE
    │
    ├──► dc_diag_rpt1~3 ──► register_file (0x0C-0x0E, MCU可读)
    └──► diag_done ───────► state_machine (退出DIAG态→HI_Z)
```

**延迟分析**：
- 诊断运行时间：DIAG_TIMEOUT_CYCLES × clk_period（~100ms最大）

---

## 5. 状态机设计

### 5.1 芯片主状态机

```
                     ┌──────────────────────────────────────────────┐
                     │                                              │
                     ▼                                              │
              ┌───────────┐                                        │
         ┌───►│  STANDBY  │◄──────── standby_n=0 ──────────────────┤
         │    └─────┬─────┘                                        │
         │          │ standby_n=1                                  │
         │          ▼                                              │
         │    ┌───────────┐                                        │
         │    │   HI_Z    │◄────── diag_done ────────┐             │
         │    └─────┬─────┘                          │             │
         │          │                                │             │
         │     ┌────┼────┐                           │             │
         │     │         │                           │             │
         │     ▼         ▼                           │             │
         │ ┌───────┐ ┌───────────┐                   │             │
         │ │ MUTE  │ │   PLAY    │                   │             │
         │ └───┬───┘ └─────┬─────┘                   │             │
         │     │           │                         │             │
         │     │  any_ch_diag                        │             │
         │     │    =1     │                         │             │
         │     └───┬───────┘                         │             │
         │         ▼                                 │             │
         │    ┌───────────┐                          │             │
         │    │   DIAG    │── diag_done ─────────────┘             │
         │    └───────────┘                                        │
         │          │                                              │
         │          │ global_fault                                 │
         └──────────┘ (POR/UV/OV/OTSD)                             │
                    │                                              │
                    └──────── clear_fault ─────────────────────────┘
                              (清除后回HI_Z)
```

**状态转换条件详表**：

| 当前状态 | 下一状态 | 转换条件 | 说明 |
|---------|---------|---------|------|
| STANDBY | HI_Z | `standby_n=1` | 退出待机 |
| HI_Z | MUTE | `any_ch_mute=1 && !any_ch_diag` | 有通道请求静音 |
| HI_Z | PLAY | `any_ch_play=1 && !any_ch_diag` | 有通道请求播放 |
| HI_Z | DIAG | `any_ch_diag=1` | 有通道请求诊断 |
| MUTE | HI_Z | `all_ch_hiz=1 \|\| any_ch_diag` | 全通道Hi-Z或请求诊断 |
| MUTE | PLAY | `any_ch_play=1` | 切换到播放 |
| PLAY | HI_Z | `all_ch_hiz=1 \|\| any_ch_diag` | 全通道Hi-Z或请求诊断 |
| PLAY | MUTE | `any_ch_mute=1 && !any_ch_play` | 切换到静音 |
| DIAG | HI_Z | `diag_done=1` | 诊断完成 |
| 任意 | STANDBY | `standby_n=0` | 强制待机 |
| 任意(非STANDBY) | HI_Z | `global_fault=1` | 全局故障 |
| HI_Z | HI_Z | `global_fault=1` | 故障保持Hi-Z |

### 5.2 通道状态机

每通道独立运行，受主状态机`chip_state`和0x04寄存器配置`ch_state_req`共同控制：

```
                ┌─────────────────────────────────┐
                │                                 │
                ▼                                 │
         ┌───────────┐                            │
    ┌───►│   HI_Z    │◄──── ch_fault_latched ────┤
    │    └─────┬─────┘                            │
    │          │                                  │
    │    chip_state=PLAY/MUTE                     │
    │    ch_state_req=PLAY/MUTE                   │
    │          │                                  │
    │     ┌────┴────┐                             │
    │     ▼         ▼                             │
    │ ┌───────┐ ┌───────────┐                     │
    │ │ PLAY  │ │   MUTE    │                     │
    │ └───┬───┘ └─────┬─────┘                     │
    │     │           │                           │
    │     └───┬───────┘                           │
    │         │ chip_state=DIAG                   │
    │         │ ch_state_req=DC_DIAG              │
    │         ▼                                   │
    │    ┌───────────┐                            │
    │    │ DC_DIAG   │── diag_done ───────────────┤
    │    └───────────┘                            │
    │         │                                   │
    │         │ clear_fault                       │
    └─────────┘ (清除故障锁存)                     │
```

**通道使能信号逻辑**：

| `ch_state` | `ch_en` | `ch_mute_mode` | PWM输出 |
|------------|---------|----------------|---------|
| CH_PLAY (00) | 1 | 0 | 音频调制PWM |
| CH_HI_Z (01) | 0 | 0 | 高阻(输出0) |
| CH_MUTE (10) | 1 | 1 | 50%占空比方波 |
| CH_DC_DIAG (11) | 0 | 0 | 高阻(诊断模式) |

### 5.3 I2C从机状态机

```
  ┌───────┐  START  ┌───────┐  8bit  ┌──────────┐  ACK  ┌──────────┐
  │ IDLE  │────────►│ ADDR  │───────►│ ACK_ADDR │──────►│ WR_ADDR  │
  └───┬───┘         └───────┘        └──────────┘       └────┬─────┘
      │                  ▲                                     │ ACK
      │ STOP             │ NACK                                ▼
      └──────────┐  ┌────┴──────────┐                   ┌──────────┐
                 │  │               │◄──────────────────│ ACK_WA   │
                 │  │               │      8bit         └────┬─────┘
                 │  │   读路径       │                       │
                 │  │               │◄─────── ACK ◄──────────┤
                 │  │               │                   ┌────▼─────┐
                 │  │               │      8bit         │ WR_DATA  │
                 │  │               │◄──────────────────│ ACK_WD   │
                 │  │               │                   └────┬─────┘
                 │  │               │                        │ ACK + STOP
                 │  └───────────────┘                        │
                 │                                           ▼
                 │  ┌───────┐  8bit  ┌──────────┐      ┌──────────┐
                 └─►│RD_DATA│───────►│ ACK_RD   │      │  IDLE    │
                    └───────┘        └────┬─────┘      └──────────┘
                                          │ ACK
                                          ▼
                                     ┌──────────┐
                                     │ RD_DATA  │ (顺序读)
                                     └──────────┘
```

### 5.4 诊断控制器状态机

```
  ┌───────────┐  diag_trigger  ┌─────────────┐  timer_done  ┌─────────┐
  │ DIAG_IDLE │───────────────►│ DIAG_DC_RUN │─────────────►│DIAG_DONE│
  └───────────┘                └─────────────┘              └────┬────┘
                                    │                            │
                                    │ AC诊断使能                  │ 1clk
                                    ▼                            ▼
                               ┌─────────────┐             ┌───────────┐
                               │ DIAG_AC_RUN │────────────►│ DIAG_IDLE │
                               └─────────────┘  done       └───────────┘
```

---

## 6. 寄存器访问架构

### 6.1 寄存器分类

| 类型 | 寄存器 | 访问方式 | 说明 |
|------|--------|---------|------|
| **R/W** | 0x00-0x08, 0x09-0x0B, 0x14-0x16, 0x21-0x28, 0x77-0x79 | I2C读写 | 配置寄存器，由MCU设置 |
| **R** | 0x0C-0x0E, 0x0F-0x13, 0x17-0x1A | 内部硬件写，I2C读 | 状态/报告寄存器 |

### 6.2 读写优先级

- **R/W寄存器**：仅I2C可写，硬件不可写（避免冲突）
- **R寄存器**：仅硬件可写，I2C不可写；I2C读取时返回硬件最新值
- **特殊控制位**：`soft_reset`(0x00 bit7)、`clear_fault`(0x21 bit7) 为脉冲型，写入后自动清除

### 6.3 寄存器复位策略

| 复位源 | 影响范围 | 触发条件 |
|--------|---------|---------|
| `rst_n` | 所有寄存器恢复默认值 | 外部硬复位 |
| `pad_rst_n` (POR) | 所有寄存器恢复默认值 + 置POR标志 | 上电复位 |
| `soft_reset` (0x00 bit7) | 所有寄存器恢复默认值（不含POR标志） | MCU软件复位 |

---

## 7. 时序设计

### 7.1 关键时序参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 系统时钟周期 | 100ns | clk = 10MHz |
| I2C SCL周期 | 10us (100kHz) / 2.5us (400kHz) | 由主机决定 |
| 音频帧周期 | 20.8us | fs = 48kHz |
| SCLK周期 | 0.65us | 32×fs @48kHz |
| PWM载波周期 | 476ns | 2.1MHz (44×fs) |
| 去抖动时间 | 50us | DEBOUNCE_CYCLES=500 |
| 故障去毛刺 | 10us | FAULT_DEGLITCH_CYCLES=100 |
| 时钟丢失超时 | ~100ms | CLK_TIMEOUT_CYCLES=0xFFFFF |
| 诊断超时 | ~100ms | DIAG_TIMEOUT_CYCLES=0xFFFFF |
| OTSD恢复冷却 | ~16s | OTSD_RECOVERY_CYCLES=0xFFFFFF |

### 7.2 关键时序路径

#### 7.2.1 I2C写入到状态转换

```
I2C SCL          ──┐    ┌──┐    ┌──
                    │    │  │    │
SDA               ──X────X──X────X──  (数据位)
                    
i2c_slave                    │
  reg_wr_en ─────────────────X────────  (写使能脉冲, 1clk)
  reg_wr_addr/data ─────────X────────  (地址+数据)

register_file                          │
  reg_ch_state_ctrl ──────────────────X──  (0x04更新, 1clk延迟)

state_machine                                   │
  chip_state ──────────────────────────────────X──  (状态转换, 1clk延迟)

总延迟: I2C最后1字节ACK → chip_state更新 ≈ 3个clk周期 (300ns)
```

#### 7.2.2 故障检测到PWM关断

```
模拟前端 otw_raw ───┐
                     │
protection 去毛刺    │ (10us连续确认)
                     │
fault_monitor 锁存   ├───┐ (1clk)
                     │   │
state_machine        │   ├───┐ (1clk)
  chip_state→HI_Z   │   │   │
                     │   │   │
channel_fsm          │   │   ├───┐ (1clk)
  ch_en→0           │   │   │   │
                     │   │   │   │
pwm_generator        │   │   │   ├───┐ (1clk)
  out→0 (Hi-Z)      │   │   │   │   │

总延迟: 故障原始信号 → PWM关断 ≈ 10us + 4个clk周期 (10.4us)
```

#### 7.2.3 音频数据到PWM输出

```
audio_interface:
  sclk_falling ────┐ (采样SDIN)
                    │
  shift_reg更新 ────┤ (1clk)
                    │
  fsync_rising ─────┤ (帧起始)
                    │
  audio_data锁存 ───┘ (1clk)

pwm_generator:
  carrier计数器 ────┐ (持续运行)
                    │
  比较器 ───────────┤ (audio_data vs carrier)
                    │
  out更新 ──────────┘ (1clk)

延迟: SDIN采样 → PWM输出 ≈ 1帧周期 + 2个clk周期
```

---

## 8. 故障保护架构

### 8.1 故障分层

```
┌─────────────────────────────────────────────────┐
│ 第一层：全局故障（强制芯片进Hi-Z）               │
│  POR / VBAT_UV / VBAT_OV / PVDD_UV / PVDD_OV    │
│  OTSD / CLOCK_LOST                              │
│  → global_fault_irq → state_machine → HI_Z      │
├─────────────────────────────────────────────────┤
│ 第二层：通道故障（仅影响对应通道）               │
│  OC_CH1~4 (过流) / DC_CH1~4 (直流检测)          │
│  → chN_fault → channel_fsm → 对应通道HI_Z       │
├─────────────────────────────────────────────────┤
│ 第三层：警告（不影响工作状态，仅输出WARN引脚）   │
│  OTW (过温警告) / CLIP (削波)                   │
│  → warn_n引脚拉低 + warnings寄存器              │
└─────────────────────────────────────────────────┘
```

### 8.2 故障恢复机制

| 故障类型 | 恢复方式 | 条件 |
|---------|---------|------|
| 全局故障(UV/OV/CLOCK) | `CLEAR_FAULT`(0x21 bit7=1) | 故障源已消除 |
| OTSD | 自动恢复（若0x21 bit3=1） | 冷却时间后自动恢复 |
| 通道故障(OC/DC) | `CLEAR_FAULT` | 故障源已消除 |
| POR | 仅POR标志清除，需重新配置 | 写0x00 bit7=1软复位 |

### 8.3 FAULT/WARN引脚逻辑

```
fault_n = 0 (拉低) 当:
  ├── global_fault_irq = 1 (全局故障)
  └── any_ch_fault = 1 (任意通道故障)
  
  (可被0x14寄存器bit配置屏蔽)

warn_n = 0 (拉低) 当:
  ├── otw_warning = 1 (过温警告)
  └── por_flag = 1 (POR标志)
  
  (可被0x14寄存器bit配置屏蔽)
```

---

## 9. 诊断架构

### 9.1 DC负载诊断

**触发方式**：MCU写0x04寄存器，将目标通道状态设为`CH_DC_DIAG`(2'b11)

**诊断流程**：
1. state_machine检测`any_ch_diag`，进入`CHIP_DIAG`态
2. `diag_trigger`脉冲启动diagnostic_ctrl
3. 对应通道`ch_diag_active=1`，PWM输出Hi-Z
4. 模拟前端施加测试电流，测量输出端电压
5. diagnostic_ctrl计时等待（DIAG_TIMEOUT_CYCLES）
6. 生成诊断报告写入0x0C-0x0E寄存器
7. `diag_done`信号触发state_machine退出DIAG态

**诊断结果编码（每通道2位）**：

| 编码 | 含义 |
|------|------|
| 00 | 正常 |
| 01 | 开路 |
| 10 | 短路到地 |
| 11 | 短路到电池 |

### 9.2 AC负载诊断

**触发方式**：通过0x15-0x16寄存器配置，在PLAY态运行

**诊断内容**：测量负载阻抗和相位响应，用于高频扬声器检测

---

## 10. 设计约束与优化

### 10.1 关键路径分析

| 路径 | 频率 | 优化策略 |
|------|------|---------|
| PWM载波比较 | 2.1MHz | 载波计数器+比较器流水线 |
| I2C状态机 | 100/400kHz | SCL同步后单周期处理 |
| 音频数据移位 | ~1.5MHz (SCLK) | sclk_falling单bit移位 |
| 故障检测 | 10MHz | 去毛刺+锁存，无组合环路 |

### 10.2 面积优化

- 4通道PWM生成器复用载波计数器（仅1个三角波发生器）
- channel_fsm模块复用（4实例例化）
- 寄存器文件使用reg阵列而非分布式RAM（便于综合）

### 10.3 功耗优化

- STANDBY态关闭PWM载波计数器
- Hi-Z态关闭音频接口移位寄存器
- clock_monitor仅在非STANDBY态运行

---

## 11. 可扩展性设计

### 11.1 预留接口

| 功能 | 预留信号 | 扩展方向 |
|------|---------|---------|
| 音量控制 | `reg_ch1~4_vol`已输出 | 后续可在pwm_generator前增加音量衰减器 |
| 削波检测 | `reg_clip_ctrl/window`已输出 | 后续可增加削波检测比较器 |
| 扩频调制 | `reg_ss_ctrl1~3`已输出 | 后续可在PWM载波增加抖动 |
| PBTL模式 | `reg_mode_ctrl` bit4/5已解码 | 后续可在PWM输出级增加PBTL合并 |

### 11.2 模块可移植性

- 所有模块使用标准Verilog HDL，无厂商原语
- 参数化设计：`CLK_FREQ`可配置
- 复位策略统一：异步复位同步释放
- 无组合逻辑环路，无锁存器

---

## 12. 审核检查清单

请审核以下关键设计点：

- [ ] 模块划分是否合理（12个模块功能边界是否清晰）
- [ ] 状态机设计是否完整覆盖datasheet系统状态图
- [ ] 寄存器映射是否与datasheet一致
- [ ] 故障保护分层是否符合datasheet描述
- [ ] 时序设计是否满足实时性要求
- [ ] 模块间信号连接是否有遗漏
- [ ] 预留接口是否满足后续扩展需求
- [ ] 编码规范一致性（命名、复位、时钟）

> **审核完成后请告知是否需要修改，确认后我将开始编写/修改代码。**
