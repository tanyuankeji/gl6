# TAS6424E-Q1 第三次架构纠正 (v5.0 → v6.0)

> **版本**: C3.0.0  
> **日期**: 2026-07-27  
> **状态**: 芯片主状态机精简——Hi-Z/Play/Mute是通道级状态，不是芯片级状态  
> **核心主张**: 
> - Hi-Z / Play / Mute 是 **4 个通道的独立状态**，不是芯片主状态机的状态
> - 不存在"芯片在 Play 态"——只有当至少一个通道在 Play 时，才表现为"芯片在 Play"
> - 芯片级状态只有: PowerOn → 上电过渡, ACT → 激活, STANDBY → 待机

---

## 0. 核心认知纠正

### 0.1 错误模型 (v5.0 及之前)

```
芯片主状态机 (5态):
├── Hi_Z         ← 错误: 芯片不需要 Hi_Z 状态, 通道各自管理
├── Play         ← 错误: 芯片不需要 Play 状态
├── Mute         ← 错误: 芯片不需要 Mute 状态
├── Single_Diag
└── Auto_Diag
```

### 0.2 正确模型 (v6.0)

```
芯片级控制 (2态):
├── ACT                    ← 激活: 通道自由管理自身状态
└── STANDBY                ← 待机: 强制所有通道 Hi-Z + 振荡器关闭

通道FSM ×4 (每通道 6态):
├── IDLE → CH_HIGH_Z
├── CH_PLAY               ← 通道在播放 (0x04[i*2+:2]=00)
├── CH_MUTE               ← 通道在静音 (0x04[i*2+:2]=10)
├── CH_HIGH_Z             ← 通道高阻 (0x04[i*2+:2]=01 或 默认)
├── CH_DC_DIAG_ENTRY      ← DC诊断桥接
└── CH_AC_DIAG_ENTRY      ← AC诊断桥接
```

### 0.3 关键论据

1. **寄存器硬件**: 0x04 寄存器为 4 通道×2bit 独立编码，芯片级没有全局 Hi-Z/Play/Mute 位
2. **实际场景**: 4 通道可以 CH1=Play, CH2=Mute, CH3=Hi-Z, CH4=Play —— 不存在单一的"芯片状态"
3. **聚合逻辑**: any_ch_play / all_ch_hiz 是组合派生信号，不需要状态机存储
4. **诊断触发**: 通道 FSM 直接通过 CH_DC_DIAG_ENTRY 与全局 DC FSM 交互，不需要主 FSM 中介

---

## 1. 正确的简化架构 (v6.0)

### 1.1 状态机层次 (3 层, 去掉了芯片主状态机层)

```
顶层状态机 (3 态)
├── PowerOn (上电过渡)
├── STANDBY (待机: 强制所有通道 Hi-Z + 振荡器关闭)
└── ACT (激活: 通道自由运行, 振荡器工作)

     │  (以下均在 ACT 内部)
     │
     ├── 通道 FSM ×4 (每通道 6 态)  — 独立管理 Hi-Z/Play/Mute/ENTRY
     │
     ├── DC 诊断 FSM (15 态) — 通过 ENTRY 桥接驱动通道诊断
     └── AC 诊断 FSM (6 态)  — 通过 ENTRY 桥接驱动通道诊断
```

### 1.2 芯片级状态: 只有 STANDBY vs ACT

| 芯片状态 | 行为 |
|---------|------|
| PowerOn | 上电过渡 (POR等待, I2C初始化) |
| STANDBY | 振荡器停止, 所有通道强制 Hi-Z, 电流 <6µA |
| ACT | 振荡器工作, **通道按 0x04 独立配置** |

### 1.3 聚合信号 (纯组合, 无状态机)

```verilog
// 这些信号是组合派生, 不是状态机输出!
assign any_ch_play   = (ch_state[0] == CH_PLAY) || (ch_state[1] == CH_PLAY)
                     || (ch_state[2] == CH_PLAY) || (ch_state[3] == CH_PLAY);
assign any_ch_mute   = (ch_state[0] == CH_MUTE) || (ch_state[1] == CH_MUTE)
                     || (ch_state[2] == CH_MUTE) || (ch_state[3] == CH_MUTE);
assign all_ch_hiz     = (ch_state[0] == CH_HIGH_Z) && (ch_state[1] == CH_HIGH_Z)
                     && (ch_state[2] == CH_HIGH_Z) && (ch_state[3] == CH_HIGH_Z);
assign any_ch_diag   = (ch_state[0] == CH_DC_DIAG_ENTRY) || ...
```

### 1.4 STANDBY含义变更

```
旧理解 (v5.0):
  STANDBY 是芯片级 FSM 的一个状态, 切换到 STANDBY 需要走 FSM 逻辑

新理解 (v6.0):
  STANDBY_N=0 → 硬件直接控制: 振荡器关 + 所有通道强制 Hi-Z
  这是一个异步硬件控制信号, 不是 FSM 状态
```

---

## 2. 模块精简效果

| 项目 | v5.0 | v6.0 | 改善 |
|------|------|------|------|
| 芯片级 FSM | 5 态 + 3 态顶层 | **3 态顶层** (去除芯片主FSM) | -50% |
| 主 FSM 状态数 | 8 (5+3) | **3** | -63% |
| channel_fsm | 4 (每通道 6 态) | 4 (每通道 6 态) | 不变 |
| DC FSM | 15 态 | 15 态 | 不变 |
| AC FSM | 6 态 | 6 态 | 不变 |
| state_machine.v | ~250 行 | **~100 行** | -60% |
| 总代码行 | ~4800 | **~4500** | -6% |

### 2.1 state_machine 功能简化

```
v5.0 state_machine 功能:
- 5 态 FSM
- 状态转换组合逻辑
- any_ch_diag/all_ch_hiz 检测
- 诊断触发/完成处理
- STANDBY_N处理

v6.0 功能:
- PowerOn 过渡
- STANDBY_N 去抖后控制 → ACT/STANDBY 切换
- any_ch_diag/all_ch_hiz 等聚合信号生成 (组合逻辑, 非状态机状态)
- 无状态转换逻辑 (除 PowerOn→(STANDBY/ACT) 的初始转换)
```

实际上 state_machine 可以完全简化为:
```verilog
module chip_controller (
    input  clk, rst_n,
    input  standby_n,        // 去抖后的 STANDBY
    input  por_done,         // 上电完成
    output reg chip_active   // 芯片是否激活 (1=ACT, 0=STANDBY)
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            chip_active <= 0;
        else if (!por_done)
            chip_active <= 0;
        else
            chip_active <= standby_n;  // STANDBY_N=1 → ACT
endmodule
```

---

## 3. 通道 FSM 触发信号重定义

取消芯片主状态机后，通道 FSM 的触发源变更为:

| 触发信号 | 来源 | 作用 |
|---------|------|------|
| ch_state_req[i] | 0x04 寄存器 | 用户配置 (PLAY/Hi-Z/MUTE/DC_DIAG) |
| ch_dc_diag_en | 0x04=11 → 启动 DC 诊断 | 全局 DC FSM 检测 ch_diag_active[i] |
| ch_ac_diag_en | 0x15/0x16 → 启动 AC 诊断 | 全局 AC FSM 检测 ch_ac_active[i] |
| ch_diag_done[i] | 全局 DC FSM → 通道 i | 该通道 DC 诊断完成 |
| ch_ac_done[i] | 全局 AC FSM → 通道 i | 该通道 AC 诊断完成 |
| ch_fault[i] | fault_monitor | 通道故障强制回 CH_HIGH_Z |
| chip_active | 芯片顶层 | =0 → 强制 CH_HIGH_Z (STANDBY) |

### 3.1 诊断触发逻辑变更

```
v5.0:
  MCU 写 0x04=11 → chip FSM 检测 any_ch_diag → chip FSM 进入 DIAG
                → chip FSM 发 diag_trigger → 全局 DC/AC FSM 运行

v6.0 (简化):
  MCU 写 0x04=11 → channel FSM 进入 CH_DC_DIAG_ENTRY → ch_diag_active[i]=1
                → 全局 DC FSM 直接检测哪个通道在 CH_DC_DIAG_ENTRY
                → 全局 DC FSM 运行, 测试该通道
                → 完成时发 ch_diag_done[i] → channel FSM 退出 ENTRY
```

**不需要 chip 主 FSM 中介诊断触发!**

---

## 4. 更新计划

| 文件 | 更新内容 |
|------|---------|
| architecture_correction_v3.md | **新增** (本文档) |
| state_machine_detailed_design.md | 去除芯片主FSM节, 简化顶层为3态, 通道FSM触发逻辑更新 |
| fsm_design.md | 同步简化 |
| architecture_design_v2.md | 模块树简化 (去除芯片主FSM) |
| module_interface_design.md | state_machine 接口简化 |
| module_functional_design.md | 同步 |
