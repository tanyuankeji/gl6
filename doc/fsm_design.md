# TAS6424E-Q1 状态机设计文档 (v6.0 — 无芯片主FSM)

> **版本**: v6.0.0 | **日期**: 2026-07-27  
> **核心**: Hi-Z/Play/Mute 是通道级状态，芯片级仅有 PowerOn/STANDBY/ACT

---

## 0. 层次总览

```
顶层 (3 态)             PowerOn / STANDBY / ACT
  │
  │ (ACT 内部 —— 通道自由运行)
  │
  ├── 通道 FSM ×4 (6 态)    ← Hi-Z / Play / Mute 在此管理
  ├── DC 诊断 FSM (15 态)
  └── AC 诊断 FSM (6 态)
```

**3 层, 24 个 FSM 状态**

---

## 1. 顶层控制 (3 态)

| 状态 | 振荡器 | 通道 | I2C |
|------|--------|------|-----|
| POWERON | 停 | 全 Hi-Z | 初始化 |
| STANDBY | 停 | 全强制 Hi-Z | 活跃 |
| ACT | 工作 | **4通道独立运行** | 活跃 |

STANDBY_N=0 → ACT, STANDBY_N=1 → STANDBY  
POR完成后根据STANDBY_N决定初始状态

---

## 2. 聚合信号 (纯组合, 替代 v5.0 芯片主FSM)

```verilog
assign any_ch_play  = (ch0_state==CH_PLAY) | (ch1_state==CH_PLAY) | (ch2_state==CH_PLAY) | (ch3_state==CH_PLAY);
assign any_ch_mute  = (ch0_state==CH_MUTE) | (ch1_state==CH_MUTE) | (ch2_state==CH_MUTE) | (ch3_state==CH_MUTE);
assign all_ch_hiz   = (ch0_state==CH_HIGH_Z) & (ch1_state==CH_HIGH_Z) & (ch2_state==CH_HIGH_Z) & (ch3_state==CH_HIGH_Z);
assign any_ch_diag  = (ch0_state==CH_DC_DIAG_ENTRY) | (ch1_state==CH_DC_DIAG_ENTRY) | (ch2_state==CH_DC_DIAG_ENTRY) | (ch3_state==CH_DC_DIAG_ENTRY);
assign any_ch_ac    = (ch0_state==CH_AC_DIAG_ENTRY) | (ch1_state==CH_AC_DIAG_ENTRY) | (ch2_state==CH_AC_DIAG_ENTRY) | (ch3_state==CH_AC_DIAG_ENTRY);
```

| 信号 | 用途 |
|------|------|
| any_ch_play | 0x0F上报, 振荡器使能 |
| all_ch_hiz | 0x0F上报 |
| any_ch_diag | 触发全局 DC FSM |
| any_ch_ac | 触发全局 AC FSM |

global_fault → 所有通道 chip_active=0 → 强制 CH_HIGH_Z

---

## 3. 通道 FSM ×4 (每通道 6 态)

### 3.1 状态定义

```verilog
localparam CH_IDLE          = 3'd0;
localparam CH_HIGH_Z        = 3'd1;  // 默认/0x04=01
localparam CH_PLAY          = 3'd2;  // 0x04=00
localparam CH_MUTE          = 3'd3;  // 0x04=10
localparam CH_DC_DIAG_ENTRY = 3'd4;  // 0x04=11
localparam CH_AC_DIAG_ENTRY = 3'd5;  // 0x15/0x16
```

### 3.2 转换图

```
   IDLE → CH_HIGH_Z
              ├── 0x04=00 → CH_PLAY
              ├── 0x04=10 → CH_MUTE
              ├── 0x04=11 → CH_DC_DIAG_ENTRY (→ ch_diag_done → CH_HIGH_Z)
              └── ac_diag_en → CH_AC_DIAG_ENTRY (→ ch_ac_done → CH_HIGH_Z)

   CH_PLAY ←→ CH_MUTE  (0x04切换 / 硬件MUTE)
   CH_PLAY → CH_DC_DIAG_ENTRY (0x04=11)
   CH_MUTE → CH_DC_DIAG_ENTRY (0x04=11)
   任意态 → CH_HIGH_Z (chip_active=0 / 故障 / global_fault)
```

### 3.3 输出

```verilog
ch_en         = (state==CH_PLAY) | (state==CH_MUTE)
ch_mute_mode  = (state==CH_MUTE)
ch_diag_active = (state==CH_DC_DIAG_ENTRY)
ch_ac_active   = (state==CH_AC_DIAG_ENTRY)
```

---

## 4. DC 诊断 FSM (15 态)

```verilog
IDLE → OBSERVATION → CH1_S2GP → CH2_S2GP → CH3_S2GP → CH4_S2GP
→ CH1_SLICK → CH2_SLICK → CH3_SLICK → CH4_SLICK
→ CH1_LO → CH2_LO → CH3_LO → CH4_LO → DONE → IDLE
```

触发: any_ch_diag=1 | 完成通知: ch_diag_done[i]=1 直接回通道 FSM

---

## 5. AC 诊断 FSM (6 态)

```verilog
IDLE → CH1_AC → CH2_AC → CH3_AC → CH4_AC → DONE → IDLE
```

触发: any_ch_ac=1 | 完成通知: ch_ac_done[i]=1 直接回通道 FSM
