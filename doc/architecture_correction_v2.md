# TAS6424E-Q1 第二次架构纠正分析 (v4.0 → v5.0)

> **版本**: C2.0.0  
> **日期**: 2026-07-27  
> **状态**: 二次纠正 - 恢复4通道独立FSM，添加ENTRY桥接子状态  
> **新增原始图**: 
> - `四个通道顶层状态图.jpg`
> - `修改后的四个通道的状态跳转.jpg`

---

## 0. 纠正的原因

v4.0 的架构纠正走得太远，错误地认为通道状态可以用纯组合逻辑派生。这在 Verilog 实际实现中会丢失重要功能。

### 关键缺陷

1. **诊断状态序列需要时序跟踪**: 每通道进入 DC_DIAG_ENTRY 后需要等待全局诊断 FSM 完成，这必须有时序逻辑
2. **故障状态需要锁存**: 通道发生过流、OTSD 等故障后必须锁存故障状态
3. **多通道并发**: 实际场景下 4 通道必须能并发运行在不同状态
4. **ENTRY 桥接子状态**: 新图揭示需要 CH_DC_DIAG_ENTRY / CH_AC_DIAG_ENTRY 作为到全局诊断 FSM 的过渡

### 用户明确指示

> "verilog的实现，和实际使用场景时，涉及到4个通道的跳转，可能需要状态机同时使用，因此必须使用四个子状态机实现通道状态跳转实现"

---

## 1. 两张新图的关键信息

### 1.1 四个通道顶层状态图

展示了一个**层次化状态机**结构：

```
                 CH_AC_DIAG (顶层全局态)
                       │ entry/exit
                       ↓
   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
   │   CH1   │  │   CH2   │  │   CH3   │  │   CH4   │
   └─────────┘  └─────────┘  └─────────┘  └─────────┘
                       │ entry/exit
                       ↓
                 CH_DC_DIAG (顶层全局态)
```

**关键解读**:
- CH_AC_DIAG 和 CH_DC_DIAG 是**顶层共享态**，由全局状态机管理
- 每个通道 (CH1-CH4) 都通过 entry/exit 与这些顶层态交互
- 这不是简单的 4 个独立 FSM，而是**4 个独立子状态机 + 全局共享诊断态**的层次结构

### 1.2 修改后的四个通道的状态跳转图

显示每个通道的实际状态机包含 **5-6 个状态**：

```
┌──────────────────────────────────────────────────────┐
│  顶层共享诊断态入口 (独立通道 FSM 进入这些入口)        │
│   ├── CH_DC_DIAG_ENTRY   ── 全局 DC FSM 桥接         │
│   └── CH_AC_DIAG_ENTRY   ── 全局 AC FSM 桥接         │
├──────────────────────────────────────────────────────┤
│  独立通道状态机 (×4, 每通道一个 FSM)                  │
│   ├── IDLE              ── 初始化态                  │
│   ├── CH_HIGH_Z         ── 默认/复位态                │
│   ├── CH_PLAY           ── 播放                      │
│   ├── CH_MUTE           ── 静音                      │
│   └── (self loop transitions)                         │
└──────────────────────────────────────────────────────┘
```

### 1.3 新图中的转换条件

| 触发条件 | 下一态 |
|---------|--------|
| 0x04配置停止诊断 | CH_HIGH_Z |
| 0x04配置诊断态 (0x04=11) | CH_DC_DIAG_ENTRY |
| 0x04配置CH_HIGH_Z | CH_HIGH_Z |
| 0x04配置CH_PLAY / 硬件引脚播放 | CH_PLAY |
| 0x04配置CH_MUTE / 硬件MUTE引脚 | CH_MUTE |
| 配置了AC诊断 (0x15/0x16) | CH_AC_DIAG_ENTRY |
| **当配置通道完成所有DC诊断** | CH_DC_DIAG_ENTRY (退出) |
| **完成单次诊断** | CH_HIGH_Z (回到) |
| **完成AC诊断** | CH_HIGH_Z (回到) |

### 1.4 关键设计注释 (来自新图)

1. **AC诊断不能从CH_HIGH_Z进入** (实际: 从任意态可被 AC诊断触发器拉入)
2. **播放的诊断通道全部进入CH_MUTE态** (这意味着进入诊断前需先静音)
3. **播放配置好过渡时, 可能会进入CH_MUTE态, 全部进入MUTE, 静音后被拉回到CH_PLAY**
4. **PLAY/MUTE做单次诊断, 全部都是诊断完成时, 通道从CH_PLAY/CH_MUTE 转换到CH_DIAG_ENTRY 后, 检测记...**
5. **CH_PLAY存在时溢载(过流)后状态是控制输出的** (通道故障强制回 CH_HIGH_Z)
6. **否则配置为禁止诊断时, 0x04诊断配置改为0x15/16配置**
7. **未配置禁止诊断且配置为播放/静音** (0x04=00 or 10)
8. **STANDBY_N 取消配置会让任何0x04配置都会进入配置状态** (顶层强制)
9. **完成单次诊断后, 0x04配置任态**

---

## 2. 正确的架构模型 (v5.0)

### 2.1 状态机层次 (5 层)

```
顶层包装 (3态)         PowerOn / STANDBY / ACT
  │
  └── 芯片主状态机 (5态)   Hi-Z / Play / Mute / Single_Diag / Auto_Diag
       │
       ├── 通道 FSM ×4 (每通道 6 态)  ★ 本次重新引入 ★
       │     ├── IDLE
       │     ├── CH_HIGH_Z
       │     ├── CH_PLAY
       │     ├── CH_MUTE
       │     ├── CH_DC_DIAG_ENTRY  ★ 桥接到全局 DC FSM ★
       │     └── CH_AC_DIAG_ENTRY  ★ 桥接到全局 AC FSM ★
       │
       └── 诊断 FSM 层
              ├── DC诊断FSM (15态) - 全局共享, 通过 CH_DC_DIAG_ENTRY 触发通道
              └── AC诊断FSM (6态)  - 全局共享, 通过 CH_AC_DIAG_ENTRY 触发通道
```

### 2.2 工作原理

```
通道 FSM 操作流程:
1. 通道 i 的 FSM 在 [CH_HIGH_Z / CH_PLAY / CH_MUTE] 之间由 0x04 配置独立切换
2. 当芯片主状态机进入 [SINGLE_DIAG/AUTO_DIAG] 且 0x04[i*2+:2] = 2'b11
   → 通道 i 的 FSM 进入 CH_DC_DIAG_ENTRY
3. 通道 i 在 CH_DC_DIAG_ENTRY 等待全局 DC FSM 完成该通道的诊断项
4. 全局 DC FSM 通过 chN_en/chN_ol/chN_lo 信号驱动通道 i 的诊断进程
5. 当该通道所有 DC 诊断完成后 → 通道 FSM 退出 CH_DC_DIAG_ENTRY → CH_HIGH_Z
6. AC 诊断流程类似, 通过 CH_AC_DIAG_ENTRY 桥接
```

### 2.3 通道 FSM 状态详解

| 状态 | 含义 | PWM行为 | ch_en | ch_mute | ch_diag |
|------|------|---------|-------|---------|---------|
| IDLE | 上电初始 | Hi-Z | 0 | 0 | 0 |
| CH_HIGH_Z | 默认/复位 | Hi-Z | 0 | 0 | 0 |
| CH_PLAY | 播放 | 音频调制 PWM | 1 | 0 | 0 |
| CH_MUTE | 静音 | 50%占空比方波 | 1 | 1 | 0 |
| CH_DC_DIAG_ENTRY | DC诊断桥接 | Hi-Z | 0 | 0 | **1** |
| CH_AC_DIAG_ENTRY | AC诊断桥接 | Hi-Z | 0 | 0 | 0 (触发ch_ac_active) |

### 2.4 与全局状态机的交互

```
【关键】通道 FSM 是独立的, 但受全局状态机约束

例子 1: PLAY → DIAG 流程
- 芯片主状态: PLAY
- 通道 i FSM: CH_PLAY (0x04=00)
- 0x04 改为 11 (DC_DIAG) → 通道 i 进入 CH_DC_DIAG_ENTRY
- 同时 芯片主状态进入 SINGLE_DIAG
- 全局 DC FSM 运行, 驱动通道 i 测试项
- 完成 → 通道 i 回 CH_HIGH_Z
- 芯片主状态回 Hi-Z (0x04 仍是 11 时)

例子 2: 自动诊断触发
- 芯片主状态: PLAY
- 通道 i FSM: CH_PLAY
- 通道 i 发生过流 → 故障中断 → global_fault
- 通道 i FSM 立即强制回 CH_HIGH_Z
- 芯片主状态进入 AUTO_DIAG
- 0x04 立即拉高某通道为 DC_DIAG (硬件或软件)
- 通道 i 进入 CH_DC_DIAG_ENTRY
```

### 2.5 触发信号汇总

| 信号 | 方向 | 作用 |
|------|------|------|
| ch_dc_diag_en[i] | 主状态机 → 通道 FSM | 启动 DC 诊断桥接 |
| ch_ac_diag_en[i] | 主状态机 → 通道 FSM | 启动 AC 诊断桥接 |
| ch_diag_done[i] | 全局 DC FSM → 通道 FSM | 单通道 DC 诊断完成 |
| ch_ac_done[i] | 全局 AC FSM → 通道 FSM | 单通道 AC 诊断完成 |
| ch_fault[i] | fault_monitor → 通道 FSM | 通道故障锁存 |
| ch_fault_latched[i] | 通道 FSM → 0x0F | 通道故障状态上报 |
| global_fault | fault_monitor → 主状态机 | 全局故障 |
| ch_state_req[i] | 0x04 → 通道 FSM | 用户配置的状态请求 |
| chip_state | 主状态机 → 通道 FSM | 全局状态约束 |

---

## 3. RTL 实现要点

### 3.1 channel_fsm 模块恢复

恢复 v3.0 的 channel_fsm 模块设计, 但增加 ENTRY 桥接态:

```verilog
module channel_fsm (
    // ... 原有接口
    output reg [2:0] ch_state,  // 6 态需 3 bit
    // ... 新增 ENTRY 相关信号
    output wire      in_dc_entry,  // 在 CH_DC_DIAG_ENTRY 态
    output wire      in_ac_entry   // 在 CH_AC_DIAG_ENTRY 态
);
```

### 3.2 通道状态编码

```verilog
localparam CH_IDLE         = 3'd0;  // 上电初始
localparam CH_HIGH_Z       = 3'd1;  // 默认/复位
localparam CH_PLAY         = 3'd2;  // 播放
localparam CH_MUTE         = 3'd3;  // 静音
localparam CH_DC_DIAG_ENTRY = 3'd4;  // DC诊断桥接
localparam CH_AC_DIAG_ENTRY = 3'd5;  // AC诊断桥接
```

### 3.3 桥接状态机行为

```verilog
// 在 CH_DC_DIAG_ENTRY 状态, 等待全局 DC FSM 完成该通道的所有测试项
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ch_state <= CH_IDLE;
        ch_fault_latched <= 1'b0;
    end else if (clear_fault) begin
        ch_fault_latched <= 1'b0;
    end else begin
        case (ch_state)
            CH_IDLE: begin
                ch_state <= CH_HIGH_Z;  // 初始化到 Hi-Z
            end
            CH_HIGH_Z: begin
                if (ch_dc_diag_en[i]) begin
                    ch_state <= CH_DC_DIAG_ENTRY;
                end else if (ch_ac_diag_en[i]) begin
                    ch_state <= CH_AC_DIAG_ENTRY;
                end else if (ch_state_req == PLAY) begin
                    ch_state <= CH_PLAY;
                end
            end
            CH_PLAY: begin
                if (ch_dc_diag_en[i])
                    ch_state <= CH_DC_DIAG_ENTRY;
                else if (ch_state_req == MUTE)
                    ch_state <= CH_MUTE;
                else if (ch_fault)
                    ch_state <= CH_HIGH_Z;
            end
            CH_MUTE: begin
                if (ch_dc_diag_en[i])
                    ch_state <= CH_DC_DIAG_ENTRY;
                else if (ch_state_req == PLAY)
                    ch_state <= CH_PLAY;
            end
            CH_DC_DIAG_ENTRY: begin
                // 等待全局 DC FSM 通过 chN_en/chN_ol/chN_lo 完成所有测试项
                if (ch_diag_done[i])  // 全局 DC FSM 通知该通道完成
                    ch_state <= CH_HIGH_Z;
            end
            CH_AC_DIAG_ENTRY: begin
                if (ch_ac_done[i])  // 全局 AC FSM 通知该通道完成
                    ch_state <= CH_HIGH_Z;
            end
        endcase
    end
end
```

### 3.4 桥接信号

```verilog
assign in_dc_entry = (ch_state == CH_DC_DIAG_ENTRY);
assign in_ac_entry = (ch_state == CH_AC_DIAG_ENTRY);

// 通道使能信号 (组合逻辑)
assign ch_en          = (ch_state == CH_PLAY) || (ch_state == CH_MUTE);
assign ch_mute_mode   = (ch_state == CH_MUTE);
assign ch_diag_active = (ch_state == CH_DC_DIAG_ENTRY);
assign ch_ac_active   = (ch_state == CH_AC_DIAG_ENTRY);
```

---

## 4. 与之前版本的对比

| 项目 | v3.0 | v4.0 (错) | **v5.0 (当前)** |
|------|------|------------|------------------|
| 通道 FSM 数 | 4 | 0 (组合逻辑) | **4 (恢复)** |
| 每通道状态数 | 5 | 0 | **6 (含 ENTRY)** |
| ch_state 位宽 | 2bit | 2bit | **3bit** |
| 全局诊断桥接 | 部分 | 否 | **完整 (ENTRY 子状态)** |
| 通道故障锁存 | 是 | 否 | **是** |
| Verilog 综合 | 12 文件 ~4400 行 | 11 文件 ~3600 行 | **12 文件 ~4800 行** |

---

## 5. 模块规模重新估算

| 模块 | 状态数 | 预估行数 |
|------|--------|----------|
| channel_fsm ×4 | 6 (每通道) | ~250 ×4 = 1000 |
| channel_state_decoder | - (取消) | 0 |
| **新增行数** | | **+1000** |

最终合计: ~3600 + ~1000 = **~4600 行**, 12 个文件

---

## 6. 行动清单

1. ✅ 创建 architecture_correction_v2.md (本文档)
2. ⏳ 重写 state_machine_detailed_design.md 恢复 4 通道 FSM
3. ⏳ 更新 fsm_design.md
4. ⏳ 更新 architecture_design_v2.md
5. ⏳ 更新 module_interface_design.md (恢复 channel_fsm 接口)
6. ⏳ 更新 module_functional_design.md (添加 ENTRY 状态实现)
7. ⏳ 提交 git
