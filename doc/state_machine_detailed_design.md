# TAS6424E-Q1 状态机详细设计文档 (v5.0 — 恢复4通道FSM + ENTRY子状态)

> **版本**: v5.0.0  
> **日期**: 2026-07-27  
> **状态**: 二次纠正完成 — 恢复 4 通道独立 FSM, 添加 ENTRY 桥接子状态  
> **主要参考**: 
> - `四个通道顶层状态图.jpg` (顶层共享诊断态结构)
> - `修改后的四个通道的状态跳转.jpg` (每通道 FSM 详细转换)
> - `四个通道的状态跳转.jpg` (原始分析参考)
> **关联文档**: 
> - `architecture_correction_v2.md` (二次纠正分析)
> - `architecture_design_v2.md` (架构总览)
> - `module_functional_design.md` (模块功能)
> - `state_machine_detailed_design.md` (本文档的v4.0版本，已被取代)

---

## 0. 架构纠正说明 (v5.0 关键变化)

### 0.1 二次纠正的核心认知

| 项目 | v4.0 (错误) | v5.0 (正确) |
|------|------------|------------|
| 通道状态实现 | 纯组合派生 (0个独立FSM) | **4个独立 FSM** + 共享诊断态入口 |
| 每通道状态数 | 0 (隐式编码) | **6 个明确状态** |
| 诊断桥接 | 无 | **CH_DC_DIAG_ENTRY / CH_AC_DIAG_ENTRY** |
| Verilog 可综合性 | 部分功能丢失 | **完整** |

### 0.2 v5.0 状态机层次

```
顶层包装 (3 态)      PowerOn / STANDBY / ACT
  │
  └── 芯片主状态机 (5 态)   Hi-Z / Play / Mute / Single_Diag / Auto_Diag
       │
       ├── 通道 FSM ×4 (每通道 6 态)  ━━━━━━━━━━━━ 本次核心 ━━━━━━━━━━━━
       │     ├── IDLE
       │     ├── CH_HIGH_Z                ← 默认/复位
       │     ├── CH_PLAY                  ← 播放
       │     ├── CH_MUTE                  ← 静音
       │     ├── CH_DC_DIAG_ENTRY         ← 全局 DC FSM 桥接 ★
       │     └── CH_AC_DIAG_ENTRY         ← 全局 AC FSM 桥接 ★
       │
       └── 诊断 FSM 层
              ├── DC诊断FSM (15 态) —— 通过 CH_DC_DIAG_ENTRY 入口触发通道
              └── AC诊断FSM (6 态)  —— 通过 CH_AC_DIAG_ENTRY 入口触发通道
```

**5 个层级, 24 个 FSM 状态** (顶层 3 + 主 5 + 通道 24 中含 ENTRY + DC 15 + AC 6)

### 0.3 关键概念：ENTRY 桥接子状态

```
通道 FSM 中加入了 2 个特殊的"桥接子状态":
- CH_DC_DIAG_ENTRY: 通道 i 的 FSM 进入此状态, 等待全局 DC FSM 完成该通道的诊断项
- CH_AC_DIAG_ENTRY: 通道 i 的 FSM 进入此状态, 等待全局 AC FSM 完成该通道的诊断项

这两个状态是从 channel FSM 到全局诊断 FSM 的接口, 是真正实现4通道并发诊断的关键。
```

---

## 1. 顶层包装状态机

### 1.1 状态定义

```verilog
localparam TOP_POWERON = 2'd0;
localparam TOP_STANDBY = 2'd1;
localparam TOP_ACT     = 2'd2;
```

### 1.2 状态转换图

```
            ┌──────────┐
            │ PowerOn  │
            └─────┬────┘
                  │ (上电时序完成: DVDDPowerOn + POR_N释放)
        ┌─────────┴─────────┐
        │                   │
   STANDBY_N=1         STANDBY_N=0
        │                   │
        ▼                   ▼
   ┌──────────┐       ┌──────────┐
   │ STANDBY  │◄─────►│   ACT    │
   └──────────┘       └──────────┘
```

### 1.3 转换条件

| 当前态 | 下一态 | 条件 | 优先级 |
|--------|--------|------|--------|
| POWERON | STANDBY | POR_N释放 + STANDBY_N=1 | — |
| POWERON | ACT | POR_N释放 + STANDBY_N=0 | — |
| STANDBY | ACT | STANDBY_N=0 | — |
| ACT | STANDBY | STANDBY_N=1 | 最高 |

---

## 2. 芯片主状态机 (5 态)

### 2.1 状态定义

```verilog
localparam CHIP_HI_Z        = 3'd0;
localparam CHIP_PLAY        = 3'd1;
localparam CHIP_MUTE        = 3'd2;
localparam CHIP_SINGLE_DIAG = 3'd3;
localparam CHIP_AUTO_DIAG   = 3'd4;
```

### 2.2 正常态转换图

```
    ┌──────────┐
    │  Hi-Z    │ (默认入口)
    └────┬─────┘
         │ any_ch_diag=1
         ▼
    ┌────────────┐
    │Single_Diag │
    └────┬───────┘
         │ diag_done
         │
         ▼
    ┌──────────┐         ┌──────────┐
    │  Play    │ ◄─────►│  Mute   │
    └────┬─────┘         └────┬─────┘
         │ any_ch_fault       │
         └────► Hi-Z ◄───────┘
         
    Hi-Z 也可因 any_ch_diag→Single_Diag
```

### 2.3 故障态转换

```
   ┌──────────┐
   │ Play/Mute │  ─ 直流偏置异常/过流/时钟错误 ─►  ┌────────────┐
   │ Hi-Z     │                                    │ Auto_Diag  │
   └──────────┘                                    └─────┬──────┘
                                                         │ 异常通道已修复
                                                         ▼
                                                     Hi-Z
```

### 2.4 转换条件详表

| # | 当前态 | 下一态 | 条件 | 优先级 |
|---|--------|--------|------|--------|
| 1 | 任意 | TOP_STANDBY | STANDBY_N=1 | 最高 |
| 2 | 任意 | CHIP_HI_Z | global_fault | 高 |
| 3 | Hi-Z/Play/Mute | CHIP_AUTO_DIAG | 直流偏置/过流/时钟错误 | — |
| 4 | Hi-Z | CHIP_SINGLE_DIAG | any_ch_diag | — |
| 5 | Hi-Z | CHIP_PLAY | any_ch_play | — |
| 6 | Hi-Z | CHIP_MUTE | any_ch_mute | — |
| 7 | Play | CHIP_MUTE | 0x04配置MUTE / 硬件静音 | — |
| 8 | Mute | CHIP_PLAY | 0x04配置PLAY / 硬件释放 | — |
| 9 | Play/Mute | CHIP_HI_Z | all_ch_hiz | — |
| 10 | Play/Mute | CHIP_SINGLE_DIAG | any_ch_diag | — |
| 11 | Single_Diag | CHIP_HI_Z | diag_done | — |
| 12 | Auto_Diag | CHIP_HI_Z | 异常通道已修复 | — |

---

## 3. 通道状态机 ×4 (每通道 6 态) ★ 核心 ★

### 3.1 状态定义

```verilog
localparam CH_IDLE          = 3'd0;  // 上电初始
localparam CH_HIGH_Z        = 3'd1;  // 默认/复位
localparam CH_PLAY          = 3'd2;  // 播放
localparam CH_MUTE          = 3'd3;  // 静音
localparam CH_DC_DIAG_ENTRY = 3'd4;  // DC 诊断桥接 ★
localparam CH_AC_DIAG_ENTRY = 3'd5;  // AC 诊断桥接 ★
```

### 3.2 状态转换图 (修正后的完整版)

```
                  ┌────────────────────────────────────────────┐
                  │ 复位 (rst_n)                                │
                  └──────────────────┬─────────────────────────┘
                                     │
                                     ▼
                              ┌──────────┐
                              │   IDLE   │
                              └────┬─────┘
                                   │ (init, 1clk)
                                   ▼
                              ┌──────────┐
        ┌─────────────────────┤ CH_HIGH_Z │◄─────────────────┐
        │                     │ (默认)    │                  │
        │                     └──┬────┬───┘                  │
        │                        │    │                      │
        │          (0x04=11 + chip_state=DIAG)                │
        │                        │    │                      │
        │              ┌─────────┘    └─────── 0x04=00/10    │
        │              ▼                ──► PLAY/MUTE       │
        │      ┌──────────────┐                              │
        │      │ CH_DC_DIAG_  │ ── ch_diag_done ──► 回到主状态
        │      │   ENTRY      │
        │      └──────┬───────┘
        │             │ (ac_diag_en)
        │             ▼
        │      ┌──────────────┐
        │      │ CH_AC_DIAG_  │ ── ch_ac_done ──►
        │      │   ENTRY      │
        │      └──────────────┘
        │
        │    0x04配置 / 硬件引脚
        │              ┌─────────────┐ ┌─────────────┐
        │              │   CH_PLAY   │ │   CH_MUTE   │
        │              └──────┬──────┘ └──────┬──────┘
        │                     │                │
        │                     │ 0x04 / 硬件引脚切换
        │                     └──────┬─────────┘
        │                            │
        └────────────────────────────┘
         (回到 CH_HIGH_Z)

故障强制路径:
任意状态 + ch_fault_latched → CH_HIGH_Z
任意状态 + global_fault → CH_HIGH_Z
```

### 3.3 完整转换条件表

| 当前态 | 下一态 | 条件 | 备注 |
|--------|--------|------|------|
| IDLE | CH_HIGH_Z | (init, 1clk) | 复位后初始化 |
| CH_HIGH_Z | CH_PLAY | 0x04=00, chip_state允许 | 进入播放 |
| CH_HIGH_Z | CH_MUTE | 0x04=10, chip_state允许 | 进入静音 |
| CH_HIGH_Z | CH_DC_DIAG_ENTRY | ch_dc_diag_en[i]=1 | DC 诊断触发 |
| CH_HIGH_Z | CH_AC_DIAG_ENTRY | ch_ac_diag_en[i]=1 | AC 诊断触发 |
| CH_PLAY | CH_MUTE | 0x04=10 / 硬件 MUTE 引脚 | 切换 |
| CH_PLAY | CH_DC_DIAG_ENTRY | ch_dc_diag_en[i]=1 | 进入 DC 诊断 |
| CH_PLAY | CH_HIGH_Z | ch_fault_latched / all_ch_hiz | 故障或回退 |
| CH_MUTE | CH_PLAY | 0x04=00 / 硬件 MUTE 释放 | 切换 |
| CH_MUTE | CH_DC_DIAG_ENTRY | ch_dc_diag_en[i]=1 | 进入 DC 诊断 |
| CH_MUTE | CH_HIGH_Z | ch_fault_latched / all_ch_hiz | 故障或回退 |
| CH_DC_DIAG_ENTRY | CH_HIGH_Z | ch_diag_done[i]=1 | 全局 DC FSM 报告完成 |
| CH_AC_DIAG_ENTRY | CH_HIGH_Z | ch_ac_done[i]=1 | 全局 AC FSM 报告完成 |
| 任意态 | CH_HIGH_Z | global_fault / STANDBY_N=0 | 顶层强制 |

### 3.4 通道使能信号

```verilog
// 组合逻辑派生 (channel_fsm 内部)
assign ch_en[i]          = (ch_state[i] == CH_PLAY) || (ch_state[i] == CH_MUTE);
assign ch_mute_mode[i]   = (ch_state[i] == CH_MUTE);
assign ch_diag_active[i] = (ch_state[i] == CH_DC_DIAG_ENTRY);
assign ch_ac_active[i]   = (ch_state[i] == CH_AC_DIAG_ENTRY);
```

### 3.5 关键设计注释 (来自新图)

1. **AC 诊断不能从 CH_HIGH_Z 直接进入** —— 实际是可以, 但需要 0x15/0x16 配置
2. **从 PLAY/MUTE 进入 DC 诊断前**: 实际上 0x04 配置为 11 时, 通道 FSM 直接进 DC_DIAG_ENTRY; 但建议先静音
3. **完成所有 DC 诊断后**: 通道退出 CH_DC_DIAG_ENTRY 回 CH_HIGH_Z (或回原 0x04 配置态)
4. **完成 AC 诊断后**: 通道回 CH_HIGH_Z
5. **0x04 配置禁止诊断**: 阻止进入 DC_DIAG_ENTRY (LDG_BYPASS=1)
6. **过流发生时**: 通道立即回 CH_HIGH_Z

### 3.6 桥接状态机制详解

```
ENTRY 子状态是 channel FSM 与 全局诊断 FSM 的接口:

                  ┌───────────────────────────────────┐
                  │     channel_fsm[i]                │
                  │                                   │
                  │   IDLE ──► HIGH_Z ──► PLAY/MUTE  │
                  │                   │                │
                  │                   │ (ch_dc_diag_en)│
                  │                   ▼                │
                  │   ┌───────────────────────────┐   │
                  │   │   CH_DC_DIAG_ENTRY        │◄──┼──┐ 全局 DC FSM
                  │   │   (桥接: 等通道i所有测试项)│   │  │ 完成通道i后
                  │   └───────────────────────────┘   │  │ 通知channel
                  │                   │ (ch_diag_done) │  │
                  │                   ▼                │  │
                  │            回 CH_HIGH_Z / 0x04态 │  │
                  │                                   │  │
                  │   ┌───────────────────────────┐   │  │
                  │   │   CH_AC_DIAG_ENTRY        │◄──┼──┤ 全局 AC FSM
                  │   │   (桥接: 等通道i的AC测试项)│   │  │ 完成通道i后
                  │   └───────────────────────────┘   │  │ 通知channel
                  │                                   │  │
                  └───────────────────────────────────┘  │
                                                          │
                  ┌───────────────────────────────────┐   │
                  │  全局 DC FSM                       │───┘
                  │  通过 chN_en/chN_ol/chN_lo 驱动通道│
                  │  检测信号来自模拟前端              │
                  └───────────────────────────────────┘
```

---

## 4. DC 诊断状态机 (15 态) —— 全局共享

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

**流程**: IDLE → OBSERVATION → CH1_S2GP → CH2_S2GP → ... → CH4_LO → DONE → IDLE

**与通道 FSM 协作**:
- 进入 DC_DIAG_CH1_S2GP 时: 通道 1 的 FSM 必须已在 CH_DC_DIAG_ENTRY
- 通过 chN_en 信号触发模拟前端对该通道的测试
- 完成时: 设置 ch_diag_done[i]=1, 通知通道 i FSM 退出 CH_DC_DIAG_ENTRY

---

## 5. AC 诊断状态机 (6 态) —— 全局共享

```verilog
localparam AC_DIAG_IDLE = 3'd0;
localparam CH1_AC       = 3'd1;
localparam CH2_AC       = 3'd2;
localparam CH3_AC       = 3'd3;
localparam CH4_AC       = 3'd4;
localparam AC_DONE      = 3'd5;
```

**流程**: IDLE → CH1_AC → CH2_AC → CH3_AC → CH4_AC → DONE → IDLE

**与通道 FSM 协作**:
- 进入 CH1_AC 时: 通道 1 的 FSM 必须已在 CH_AC_DIAG_ENTRY
- 测量完成后: 设置 ch_ac_done[0]=1, 通知通道 1 退出
- 然后进入 CH2_AC, 测试通道 2

---

## 6. 模块间信号交互总览

### 6.1 信号流向图

```
                          ┌─────────────────────────────────────┐
                          │ 顶层封装 FSM                        │
                          │ (PowerOn/Standby/Act)               │
                          └──────────┬──────────────────────────┘
                                     │ STANDBY_N
                                     ▼
                          ┌─────────────────────────────────────┐
                          │ 芯片主 FSM                          │
                          │ (Hi-Z/Play/Mute/Single/Auto)        │
                          └──────────┬──────────────────────────┘
                                     │ chip_state, global_fault
                                     ▼
                ┌────────────────────┴────────────────────┐
                │                                          │
                ▼                                          ▼
   ┌────────────────────────┐               ┌────────────────────────┐
   │  channel_fsm[0] (CH1)  │ ... 重复 ×4 ... │  channel_fsm[3] (CH4)  │
   │  IDLE/HIGH_Z/          │               │                          │
   │  PLAY/MUTE/            │               │                          │
   │  DC_DIAG_ENTRY/        │               │                          │
   │  AC_DIAG_ENTRY         │               │                          │
   │  (6 态 FSM)            │               │                          │
   └─────┬──────────────────┘               └────────────────────────┘
         │ ch1_state_req, ch1_dc_diag_en, ch1_ac_diag_en
         │ ch1_diag_done (来自全局 DC FSM)
         │ ch1_ac_done (来自全局 AC FSM)
         │
         ▼
   ┌─────────────────────────────────────────────────────────────┐
   │ 全局诊断 FSM 层                                            │
   │   DC FSM (15 态) ─── ch_diag_done[3:0]                    │
   │   AC FSM (6 态)  ─── ch_ac_done[3:0]                     │
   │   (由 ch_diag_active[3:0]/ch_ac_active[3:0] 触发)         │
   └─────────────────────────────────────────────────────────────┘
```

### 6.2 信号列表

| 信号 | 位宽 | 方向 | 作用 |
|------|------|------|------|
| chip_state[2:0] | 3 | 主 FSM → 通道 FSM | 全局状态约束 |
| global_fault | 1 | fault_monitor → 主 FSM | 全局故障 |
| ch_state_req[i][1:0] | 2×4 | 0x04 → 通道 FSM | 用户配置的请求 |
| ch_dc_diag_en[i] | 1×4 | 主 FSM → 通道 FSM | 启动该通道 DC 诊断 |
| ch_ac_diag_en[i] | 1×4 | 0x15/0x16 → 通道 FSM | 启动该通道 AC 诊断 |
| ch_diag_done[i] | 1×4 | DC FSM → 通道 FSM | 单通道 DC 诊断完成 |
| ch_ac_done[i] | 1×4 | AC FSM → 通道 FSM | 单通道 AC 诊断完成 |
| ch_fault[i] | 1×4 | fault_monitor → 通道 FSM | 通道故障 (非锁存) |
| ch_fault_latched[i] | 1×4 | 通道 FSM → 0x0F | 通道故障状态上报 |
| diag_done | 1 | DC/AC FSM → 主 FSM | 整体诊断完成 |

---

## 7. 设计检查清单

- [ ] 通道 FSM 是否有 6 个状态 (IDLE/HIGH_Z/PLAY/MUTE/DC_DIAG_ENTRY/AC_DIAG_ENTRY)
- [ ] ENTRY 子状态是否正确桥接到全局诊断 FSM
- [ ] ch_diag_done / ch_ac_done 是否全局诊断 FSM 在完成该通道时拉高
- [ ] ch_fault 时通道 FSM 是否回 CH_HIGH_Z
- [ ] STANDBY_N 是否强制所有通道回 CH_HIGH_Z
- [ ] clear_fault 是否清除通道故障锁存
- [ ] DC FSM 是否在通道进入 ENTRY 后才开始对该通道的测试
- [ ] 全局 DC FSM 的 ch1_en/ch2_en/... 是否正确触发通道 1-4 测试项
- [ ] 0x04 配置禁止诊断时是否阻止进入 DC 诊断
- [ ] 通道状态机的所有时序逻辑是否避免组合逻辑环路
