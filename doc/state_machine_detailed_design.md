# TAS6424E-Q1 状态机详细设计文档（v4.0 — 通道状态派生模型）

> **版本**: v4.0.0  
> **日期**: 2026-07-22  
> **状态**: 架构纠正完成 — 通道状态改为组合派生，非独立FSM  
> **主要参考**: `四个通道的状态跳转.jpg`（经过提取分析，最可靠）  
> **辅助参考**: `系统应用状态图.jpg`（初期定义，细节缺失较多）  
> **关联文档**: 
> - `architecture_correction.md` (纠正分析)
> - `architecture_design_v2.md` (架构总览)
> - `module_functional_design.md` (模块功能)

---

## 0. 架构纠正说明 (v4.0 关键变化)

### 0.1 错误纠正

| 项目 | 旧版 (v3.0) | 新版 (v4.0) |
|------|------------|------------|
| 通道状态管理 | 4个独立 channel_fsm 实例 | **组合派生逻辑** (无独立FSM) |
| 状态数 | 5层33个状态 | **4层18个状态** (去掉了通道FSM层) |
| 模块数 | 12个 | **11个** (channel_fsm 取消) |

### 0.2 核心认知

`四个通道的状态跳转.jpg` 中的 CH_HIGH_Z / CH_PLAY / CH_MUTE 是**重叠的复合视图**——每个宏状态同时包含4个通道的子状态。
通道子状态由 `chip_state` + `0x04寄存器` 的**组合逻辑**直接派生，不需要独立的FSM。

### 0.3 正确状态机层次

```
顶层 (3态)   PowerOn / STANDBY / ACT
  │
  └── 芯片主状态机 (5态)   Hi-Z / Play / Mute / Single_Diag / Auto_Diag
       │
       ├── 通道状态派生 (组合逻辑) — 4通道×2bit, 由 reg_04[7:0] 解码
       │
       └── 诊断层
              ├── DC诊断FSM (15态)
              └── AC诊断FSM (6态)
```

**4个层级, 18个FSM状态 + 组合派生通道状态 (无额外FSM状态)**

---

## 1. 顶层包装状态机

### 1.1 状态定义

```verilog
localparam TOP_POWERON = 2'd0;  // 上电过渡
localparam TOP_STANDBY = 2'd1;  // 待机 (最低功耗)
localparam TOP_ACT     = 2'd2;  // 激活 (正常工作)
```

### 1.2 状态转换图

```
            ┌──────────┐
            │ PowerOn  │
            └─────┬────┘
                  │ (模拟上电时序完成: DVDDPowerOn + POR_N释放)
        ┌─────────┴─────────┐
        │                   │
   STANDBY_N=1         STANDBY_N=0
        │                   │
        ▼                   ▼
   ┌──────────┐       ┌──────────┐
   │ STANDBY  │◄─────►│   ACT    │
   │ (低功耗) │ STB_N  │  (工作)  │
   └──────────┘ !STB_N └──────────┘
```

### 1.3 转换条件

| 当前态 | 下一态 | 条件 | 优先级 |
|--------|--------|------|--------|
| POWERON | STANDBY | POR_N释放 + STANDBY_N=1 | — |
| POWERON | ACT | POR_N释放 + STANDBY_N=0 | — |
| STANDBY | ACT | STANDBY_N=0 | — |
| ACT | STANDBY | STANDBY_N=1 | 最高 |

---

## 2. 芯片主状态机

### 2.1 状态定义

```verilog
localparam CHIP_HI_Z        = 3'd0;  // 高阻态 (默认)
localparam CHIP_PLAY        = 3'd1;  // 播放态
localparam CHIP_MUTE        = 3'd2;  // 静音频
localparam CHIP_SINGLE_DIAG = 3'd3;  // 单次诊断 (MCU触发)
localparam CHIP_AUTO_DIAG   = 3'd4;  // 自动诊断 (故障后)
```

### 2.2 正常态转换图

```
    ┌──────────┐
    │  Hi-Z态  │ ◄────────── (默认入口, 所有4通道Hi-Z) ──┐
    │ (强制)   │                                          │
    └────┬─────┘                                          │
         │ 0x04配置诊断/停止诊断                            │ 一次诊断完成
         ▼                                                 │
    ┌────────────┐                                         │
    │ 单次诊断态 │ ── 一次诊断完成 ─────────────────────► │
    │ (部分通道) │                                         │
    └────┬───────┘                                         │
         │ 0x04配置Hi-Z/播放/静音                          │
         ▼                                                 │
    ┌──────────┐    0x04/硬件      ┌──────────┐           │
    │ 播放态   │ ◄──── 切换 ──────►│ 静音频   │           │
    │ (部分通道)│                   │ (部分通道)│           │
    └──────────┘                   └──────────┘           │
              ▲                         ▲                  │
              │                         │                  │
              └──── 0x04配置Hi-Z ───────┘─────────────────┘
```

### 2.3 故障态转换图

```
   ┌────────────┐ 直流偏置异常/过流/时钟错误   ┌──────────────┐
   │ 播放态      │ ────────────────────────►   │  自诊断态    │
   │ 静动态      │                              │  (Auto Diag) │
   │ Hi-Z态      │                              └──────┬───────┘
   └────────────┘                                     │
                                                       │ 异常通道已修复
                                                       │ 0x04指示状态位1
                                                       ▼
                                                  ┌─────────┐
                                                  │ Hi-Z态  │
                                                  └─────────┘
```

### 2.4 状态行为 (datasheet 表9-5)

| 模式名称 | 输出级FETs | 内部振荡器 | I2C | 通道控制 |
|---------|-----------|-----------|-----|---------|
| 待机 (Standby) | Hi-Z | 关闭 | 关闭 | 所有通道Hi-Z |
| Hi-Z | Hi-Z | 工作 | 工作 | **强制所有通道Hi-Z (无视0x04)** |
| Play | 音频调制 | 工作 | 工作 | 通道按0x04独立配置 |
| Mute | 50%占空比 | 工作 | 工作 | 通道按0x04独立配置 |
| Single_Diag | Hi-Z(诊断) | 工作 | 工作 | 0x04=11的通道诊断 |
| Auto_Diag | Hi-Z(诊断) | 工作 | 工作 | 故障通道自动诊断 |

### 2.5 关键设计注释

- **Hi-Z态强制所有通道Hi-Z**: 此时0x04寄存器被读取但被覆盖
- **Play/Mute态**: 各通道按0x04[7:0]独立控制，2bit/通道
- **Single_Diag态**: 仅0x04=11的通道进入DC诊断
- **Auto_Diag态**: 故障通道自动进入DC诊断
- **STANDBY**: 强制所有状态，恢复到芯片状态需重新配置

### 2.6 转换条件详表

| # | 当前态 | 下一态 | 条件 | 优先级 |
|---|--------|--------|------|--------|
| 1 | 任意 | TOP_STANDBY | STANDBY_N=1 | 最高 |
| 2 | 任意(非STANDBY) | CHIP_HI_Z | global_fault=1 | 高 |
| 3 | CHIP_HI_Z/PLAY/MUTE | CHIP_AUTO_DIAG | 时钟错误/直流偏置异常/过流 | — |
| 4 | CHIP_HI_Z | CHIP_SINGLE_DIAG | 0x04任意通道=11 (DC_DIAG) | — |
| 5 | CHIP_HI_Z | CHIP_MUTE | any_ch_mute=1 | — |
| 6 | CHIP_HI_Z | CHIP_PLAY | any_ch_play=1 | — |
| 7 | CHIP_PLAY | CHIP_MUTE | 0x04/硬件引脚静音 | — |
| 8 | CHIP_MUTE | CHIP_PLAY | 0x04/硬件引脚释放 | — |
| 9 | CHIP_PLAY/MUTE | CHIP_HI_Z | 0x04全通道Hi-Z | — |
| 10 | CHIP_PLAY/MUTE | CHIP_SINGLE_DIAG | 0x04任意通道=11 | — |
| 11 | CHIP_SINGLE_DIAG | CHIP_HI_Z | 一次诊断完成 | — |
| 12 | CHIP_AUTO_DIAG | CHIP_HI_Z | 异常通道已修复 | — |

---

## 3. 通道状态组合派生逻辑（非独立FSM）

### 3.1 设计原理

**通道状态不是独立的状态机！** 而是由三个输入源组合派生的：

```
输入1: chip_state[2:0]      (全局芯片状态)
输入2: reg_04[7:0]           (0x04寄存器: 4通道×2bit)
输入3: ac_diag_en[3:0]       (AC诊断使能, 来自0x15/0x16)
       ↓
    [组合派生逻辑]
       ↓
输出:   ch_state[0:3][1:0]   (每通道2bit状态)
        ch_en[3:0]
        ch_mute_mode[3:0]
        ch_diag_active[3:0]
        ch_ac_active[3:0]
```

### 3.2 派生算法

```verilog
// 通道 i 的状态派生 (纯组合逻辑)
// 0x04 子字段编码:
//   00 = PLAY
//   01 = HI_Z  
//   10 = MUTE
//   11 = DC_DIAG

// AC_DIAG 编码复用 2'b11 (通过 chip_state==CHIP_AC_DIAG 区分)

// 优先级: 
//   1. Hi-Z/STANDBY 强制覆盖
//   2. AC诊断覆盖 (仅当ac_diag_en[i]=1)
//   3. DC诊断(0x04=11 and chip_state in {SINGLE, AUTO}_DIAG)
//   4. 0x04直接编码 (PLAY/MUTE/HI_Z)

assign ch_state[i] = (chip_state == CHIP_HI_Z || chip_state == CHIP_STANDBY)
    ? 2'b01  // 强制Hi-Z (无视0x04)
    : (chip_state == CHIP_AC_DIAG && ac_diag_en[i])
        ? 2'b11  // AC诊断: 编码为11
        : ((chip_state == CHIP_SINGLE_DIAG || chip_state == CHIP_AUTO_DIAG) 
           && reg_04_ch[i] == 2'b11)
            ? 2'b11  // DC诊断: 编码为11
            : reg_04_ch[i];  // 直接使用0x04编码: 00=PLAY,01=HI_Z,10=MUTE
```

### 3.3 通道使能信号派生

```verilog
assign ch_en[i]          = (ch_state[i] == 2'b00) || (ch_state[i] == 2'b10);
assign ch_mute_mode[i]   = (ch_state[i] == 2'b10);
assign ch_diag_active[i] = (ch_state[i] == 2'b11) 
                           && (chip_state != CHIP_AC_DIAG);
assign ch_ac_active[i]   = (ch_state[i] == 2'b11) 
                           && (chip_state == CHIP_AC_DIAG);
```

### 3.4 各主状态下的通道行为

| chip_state | 通道编码 | 说明 |
|-----------|---------|------|
| HI_Z | 全部=01 | 强制覆盖0x04, 所有通道Hi-Z |
| STANDBY | 全部=01 | 强制覆盖 |
| PLAY | 以0x04为准 | 00=PLAY, 01=HI_Z, 10=MUTE (11在PLAY态无意义) |
| MUTE | 以0x04为准 | 00=PLAY, 01=HI_Z, 10=MUTE |
| SINGLE_DIAG | 0x04=11的通道 → DC_DIAG (11); 其余 → HI_Z (01) |
| AUTO_DIAG | 故障通道 → DC_DIAG (11); 其余 → HI_Z (01) |
| AC_DIAG | ac_diag_en[i]=1 → AC_DIAG (11); 其余 → HI_Z (01) |

### 3.5 与四个通道的状态跳转图的对应

`四个通道的状态跳转.jpg` 中的重叠区域含义：

- **CH_HIGH_Z 区域**: 所有4通道同时处于Hi-Z（或被chip_state覆盖）
- **CH_PLAY 区域**: 部分通道在播放 (0x04=00)，其余Hi-Z (0x04=01)
- **CH_MUTE 区域**: 部分通道在静音 (0x04=10)，其余Hi-Z (0x04=01)
- **CH_SINGLE_DC_DIAG 区域**: 0x04=11的通道在DC诊断
- **CH_AC_DIAG 区域**: ac_diag_en=1的通道在AC诊断

> **这些不是4个独立的FSM状态，而是一张图中同时展示所有通道在不同条件下的行为。**

---

## 4. DC诊断状态机 (15态)

> 与v3.0相同，无变化。详见旧版文档。

### 4.1 状态编码

```verilog
localparam DC_DIAG_IDLE        = 4'd0;
localparam DC_DIAG_OBSERVATION = 4'd1;
localparam DC_DIAG_CH1_S2GP    = 4'd2;  // CH1 S2G+S2P
localparam DC_DIAG_CH2_S2GP    = 4'd3;
localparam DC_DIAG_CH3_S2GP    = 4'd4;
localparam DC_DIAG_CH4_S2GP    = 4'd5;
localparam DC_DIAG_CH1_SLICK   = 4'd6;  // CH1 SL+OL
localparam DC_DIAG_CH2_SLICK   = 4'd7;
localparam DC_DIAG_CH3_SLICK   = 4'd8;
localparam DC_DIAG_CH4_SLICK   = 4'd9;
localparam DC_DIAG_CH1_LO      = 4'd10; // CH1 LO
localparam DC_DIAG_CH2_LO      = 4'd11;
localparam DC_DIAG_CH3_LO      = 4'd12;
localparam DC_DIAG_CH4_LO      = 4'd13;
localparam DC_DONE             = 4'd14;
```

### 4.2 状态转换

IDLE → OBSERVATION → CH1_S2GP → CH2_S2GP → CH3_S2GP → CH4_S2GP → CH1_SLICK → CH2_SLICK → CH3_SLICK → CH4_SLICK → CH1_LO → CH2_LO → CH3_LO → CH4_LO → DONE → IDLE

---

## 5. AC诊断状态机 (6态)

> 与v3.0相同，无变化。

```verilog
localparam AC_DIAG_IDLE = 3'd0;
localparam CH1_AC       = 3'd1;
localparam CH2_AC       = 3'd2;
localparam CH3_AC       = 3'd3;
localparam CH4_AC       = 3'd4;
localparam AC_DONE      = 3'd5;
```

IDLE → CH1_AC → CH2_AC → CH3_AC → CH4_AC → DONE → IDLE

---

## 6. 状态机间交互关系 (v4.0简化)

### 6.1 信号表

| 信号 | 源 | 目标 | 作用 |
|------|-----|------|------|
| chip_state[2:0] | state_machine | channel_state组合逻辑 | 全局模式 |
| reg_04[7:0] | register_file | channel_state组合逻辑 | 通道配置 |
| ac_diag_en[3:0] | 0x15/0x16 | channel_state组合逻辑 | AC诊断 |
| ch_state[0:3][1:0] | 组合逻辑 | pwm_generator, 0x0F | 通道状态 |
| ch_en[3:0] | 组合逻辑 | pwm_generator | PWM使能 |
| ch_mute_mode[3:0] | 组合逻辑 | pwm_generator | 静音控制 |
| ch_diag_active[3:0] | 组合逻辑 | diagnostic_ctrl | DC诊断使能 |
| ch_ac_active[3:0] | 组合逻辑 | diagnostic_ctrl | AC诊断使能 |
| diag_done | DC/AC FSM | state_machine | 诊断完成 |

### 6.2 简化效果

| 指标 | v3.0 | v4.0 | 改善 |
|------|------|------|------|
| 独立FSM层数 | 5层 | 4层 | -20% |
| 模块数 | 12 | 11 | -1 |
| 互联信号 | ~120 | ~70 | -42% |
| 预估代码行 | ~4400 | ~3800 | -14% |

---

## 7. 设计检查清单

- [ ] 通道状态是否由组合逻辑派生（无独立寄存器）
- [ ] Hi-Z/STANDBY态是否强制所有通道Hi-Z
- [ ] Play/Mute态是否允许通道按0x04独立配置
- [ ] Single_Diag/Auto_Diag态是否正确处理DC诊断通道
- [ ] AC_DIAG是否仅ac_diag_en=1的通道参与
- [ ] 0x04编码 00/01/10/11 是否正确解码
- [ ] DC诊断15态FSM是否顺序正确
- [ ] AC诊断6态FSM是否顺序正确
