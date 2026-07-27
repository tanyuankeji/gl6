# TAS6424E-Q1 状态机详细设计文档 (v6.0 — 去除芯片主FSM层)

> **版本**: v6.0.0  
> **日期**: 2026-07-27  
> **状态**: Hi-Z/Play/Mute 下沉为通道级状态，芯片主FSM取消  
> **核心认知**: Hi-Z/Play/Mute 不是芯片全局状态，是每通道独立FSM的状态

---

## 0. 架构精简 (v6.0)

### 0.1 关键变化

| 项目 | v5.0 | v6.0 |
|------|------|------|
| 芯片主FSM | 5态 (Hi-Z/Play/Mute/Single/Auto) | **取消** |
| 顶层控制 | 3态 (PowerOn/STANDBY/ACT) | **3态** (不变) |
| Hi-Z/Play/Mute | 芯片级FSM状态 | **通道级FSM状态** ★ |
| 聚合信号 | FSM内部 | **组合逻辑派生** |
| 诊断触发 | 通过芯片FSM | **通道FSM直接与诊断FSM交互** |

### 0.2 正确状态机层次 (3层)

```
顶层控制 (3 态)        PowerOn / STANDBY / ACT
  │
  │ (ACT 内部)
  │
  ├── 通道 FSM ×4 (每通道 6 态)
  │     ├── IDLE → CH_HIGH_Z (默认)
  │     ├── CH_PLAY             ← 0x04=00
  │     ├── CH_MUTE             ← 0x04=10
  │     ├── CH_DC_DIAG_ENTRY    ← 0x04=11 + DC FSM 桥接
  │     └── CH_AC_DIAG_ENTRY    ← 0x15/0x16 + AC FSM 桥接
  │
  ├── DC 诊断 FSM (15 态)
  └── AC 诊断 FSM (6 态)
```

**3 个层级, 24 个 FSM 状态** (顶层 3 + 通道 4×6 + DC 15 + AC 6)

---

## 1. 顶层控制 (3 态)

### 1.1 状态定义

```verilog
localparam CHIP_POWERON = 2'd0;  // 上电过渡
localparam CHIP_STANDBY = 2'd1;  // 待机 (振荡器停)
localparam CHIP_ACT     = 2'd2;  // 激活 (振荡器工作)
```

### 1.2 状态转换

```
          ┌──────────┐
          │ POWERON  │
          └────┬─────┘
               │ (POR释放, I2C就绪)
     ┌─────────┴─────────┐
     │                   │
  STANDBY_N=1       STANDBY_N=0
     │                   │
     ▼                   ▼
┌──────────┐       ┌──────────┐
│ STANDBY  │◄─────►│   ACT    │
│ (待机)   │STB_N  │  (激活)  │
└──────────┘ !STB_N└──────────┘
                │
      ┌─────┬───┼───┬─────┐
      ▼     ▼   │   ▼     ▼
     CH1   CH2  │  CH3   CH4   (4通道自由运行)
      FSM   FSM │   FSM   FSM
                │
      ┌─────────┼─────────┐
      ▼         │         ▼
    DC FSM ← ACT内部 → AC FSM
```

### 1.3 状态行为

| 状态 | 振荡器 | 通道 | I2C |
|------|--------|------|-----|
| POWERON | 停 | 全部 Hi-Z | 初始化中 |
| STANDBY | 停 | 全部强制 Hi-Z | 活跃 (可配置寄存器) |
| ACT | 工作 | **4 通道按 0x04 独立运行** | 活跃 |

### 1.4 RTL 实现

```verilog
module chip_top_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       por_done,         // 上电完成
    input  wire       standby_n,        // STANDBY引脚 (经去抖)
    output reg  [1:0] chip_state        // POWERON/STANDBY/ACT
);

localparam CHIP_POWERON = 2'd0;
localparam CHIP_STANDBY = 2'd1;
localparam CHIP_ACT     = 2'd2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        chip_state <= CHIP_POWERON;
    else begin
        case (chip_state)
            CHIP_POWERON:
                if (por_done)
                    chip_state <= standby_n ? CHIP_STANDBY : CHIP_ACT;
            CHIP_STANDBY:
                if (!standby_n)        // STANDBY_N=0 → ACT
                    chip_state <= CHIP_ACT;
            CHIP_ACT:
                if (standby_n)         // STANDBY_N=1 → STANDBY
                    chip_state <= CHIP_STANDBY;
        endcase
    end
end

endmodule
```

---

## 2. 通道状态机 ×4 (每通道 6 态)

### 2.1 状态定义

```verilog
localparam CH_IDLE          = 3'd0;  // 上电初始
localparam CH_HIGH_Z        = 3'd1;  // 默认/复位/0x04=01
localparam CH_PLAY          = 3'd2;  // 播放   /0x04=00
localparam CH_MUTE          = 3'd3;  // 静音   /0x04=10
localparam CH_DC_DIAG_ENTRY = 3'd4;  // DC 诊断桥接 /0x04=11
localparam CH_AC_DIAG_ENTRY = 3'd5;  // AC 诊断桥接 /0x15/0x16
```

### 2.2 状态转换图

```
                 ┌─────────┐
                 │  IDLE   │
                 └────┬────┘
                      │ (init)
                      ▼
                 ┌─────────┐
    ┌────────────┤CH_HIGH_Z│◄────────────── (任何态 + 故障/chip!=ACT)
    │            │ (默认)  │
    │            └──┬──┬───┘
    │               │  │
    │     (0x04=00) │  │ (0x04=10)
    │               ▼  ▼
    │          ┌──────────┐┌──────────┐
    │          │ CH_PLAY  ││ CH_MUTE  │
    │          └────┬─────┘└────┬─────┘
    │               │           │
    │               │ (0x04=11) │ (0x04=11)
    │               │ (互切)    │ (互切)
    │               ▼  ◄─────► ▼
    │          ┌───────────────┐
    │          │ CH_DC_DIAG_   │── ch_diag_done ──►回 CH_HIGH_Z
    │          │   ENTRY       │
    │          └──────┬────────┘
    │                 │ (ac_diag_en)
    │                 ▼
    │          ┌───────────────┐
    │          │ CH_AC_DIAG_   │── ch_ac_done ──► 回 CH_HIGH_Z
    │          │   ENTRY       │
    │          └───────────────┘
    │
    └────────── (chip!=ACT / 故障 / 复位) ──────┘
               (任意态 → CH_HIGH_Z)
```

### 2.3 转换条件表

| 当前态 | 下一态 | 条件 | 备注 |
|--------|--------|------|------|
| IDLE | CH_HIGH_Z | (init, 1clk) | 复位后 |
| CH_HIGH_Z | CH_PLAY | 0x04=00 | |
| CH_HIGH_Z | CH_MUTE | 0x04=10 | |
| CH_HIGH_Z | CH_DC_DIAG_ENTRY | 0x04=11 | chip!=STANDBY时 |
| CH_HIGH_Z | CH_AC_DIAG_ENTRY | ac_diag_en[i]=1 | 见3.4 |
| CH_PLAY | CH_MUTE | 0x04=10 / HW MUTE | |
| CH_PLAY | CH_DC_DIAG_ENTRY | 0x04=11 | |
| CH_MUTE | CH_PLAY | 0x04=00 / HW MUTE释放 | |
| CH_MUTE | CH_DC_DIAG_ENTRY | 0x04=11 | |
| CH_DC_DIAG_ENTRY | CH_HIGH_Z | ch_diag_done[i]=1 | DC FSM通知完成 |
| CH_AC_DIAG_ENTRY | CH_HIGH_Z | ch_ac_done[i]=1 | AC FSM通知完成 |
| **任意态** | **CH_HIGH_Z** | **chip_state!=ACT / ch_fault / global_fault** | 强制 |

> ★ 注意: 这些状态是4通道各自独立的FSM，4个通道可以同时处于不同状态

### 2.4 RTL 实现

```verilog
module channel_fsm (
    input  wire       clk, rst_n,
    input  wire       chip_active,      // chip_state==ACT
    input  wire [1:0] ch_state_req,     // 0x04: 00=PLAY,01=HI_Z,10=MUTE,11=DC_DIAG
    input  wire       ch_diag_done,     // 全局 DC FSM 完成该通道
    input  wire       ch_ac_done,       // 全局 AC FSM 完成该通道
    input  wire       ac_diag_en,       // 0x15/0x16
    input  wire       hw_mute_n,        // 硬件 MUTE 引脚
    input  wire       ch_fault,         // 故障输入
    output reg  [2:0] ch_state,
    output wire       ch_en, ch_mute_mode, ch_diag_active, ch_ac_active,
    output reg        ch_fault_latched
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ch_state <= CH_IDLE;
        ch_fault_latched <= 1'b0;
    end else if (!chip_active) begin
        // STANDBY: 强制 Hi-Z
        ch_state <= CH_HIGH_Z;
    end else begin
        if (ch_fault) ch_fault_latched <= 1'b1;

        case (ch_state)
            CH_IDLE: ch_state <= CH_HIGH_Z;

            CH_HIGH_Z: begin
                if (ch_state_req == 2'b11)   ch_state <= CH_DC_DIAG_ENTRY;
                else if (ac_diag_en)          ch_state <= CH_AC_DIAG_ENTRY;
                else if (ch_state_req == 2'b00) ch_state <= CH_PLAY;
                else if (ch_state_req == 2'b10) ch_state <= CH_MUTE;
            end

            CH_PLAY: begin
                if (ch_state_req == 2'b11)   ch_state <= CH_DC_DIAG_ENTRY;
                else if (ch_state_req == 2'b10) ch_state <= CH_MUTE;
                else if (ch_fault_latched)    ch_state <= CH_HIGH_Z;
            end

            CH_MUTE: begin
                if (ch_state_req == 2'b11)   ch_state <= CH_DC_DIAG_ENTRY;
                else if (ch_state_req == 2'b00) ch_state <= CH_PLAY;
                else if (ch_fault_latched)    ch_state <= CH_HIGH_Z;
            end

            CH_DC_DIAG_ENTRY:
                if (ch_diag_done) ch_state <= CH_HIGH_Z;

            CH_AC_DIAG_ENTRY:
                if (ch_ac_done)   ch_state <= CH_HIGH_Z;
        endcase
    end
end

// 组合派生使能信号
assign ch_en          = (ch_state == CH_PLAY) || (ch_state == CH_MUTE);
assign ch_mute_mode   = (ch_state == CH_MUTE);
assign ch_diag_active = (ch_state == CH_DC_DIAG_ENTRY);
assign ch_ac_active   = (ch_state == CH_AC_DIAG_ENTRY);

endmodule
```

### 2.5 关键特性

- **全独立**: 4 通道各自独立状态机，不依赖"芯片 FSM"
- **由 chip_active 控制**: chip_active=0 → 强制回 CH_HIGH_Z
- **由 0x04 直接驱动**: 通道状态转换直接来自 0x04 寄存器位
- **ENTRY 桥接**: CH_DC_DIAG_ENTRY / CH_AC_DIAG_ENTRY 与全局诊断 FSM 交互

---

## 3. 聚合信号 (纯组合逻辑)

```verilog
// 顶层的聚合信号 (无状态机参与, 纯组合)
assign any_ch_play   = (ch0_state == CH_PLAY) || (ch1_state == CH_PLAY)
                     || (ch2_state == CH_PLAY) || (ch3_state == CH_PLAY);
assign any_ch_mute   = (ch0_state == CH_MUTE) || (ch1_state == CH_MUTE)
                     || (ch2_state == CH_MUTE) || (ch3_state == CH_MUTE);
assign all_ch_hiz     = (ch0_state == CH_HIGH_Z) && (ch1_state == CH_HIGH_Z)
                     && (ch2_state == CH_HIGH_Z) && (ch3_state == CH_HIGH_Z);
assign any_ch_diag   = (ch0_state == CH_DC_DIAG_ENTRY) || (ch1_state == CH_DC_DIAG_ENTRY)
                     || (ch2_state == CH_DC_DIAG_ENTRY) || (ch3_state == CH_DC_DIAG_ENTRY);
assign any_ch_ac     = (ch0_state == CH_AC_DIAG_ENTRY) || (ch1_state == CH_AC_DIAG_ENTRY)
                     || (ch2_state == CH_AC_DIAG_ENTRY) || (ch3_state == CH_AC_DIAG_ENTRY);
```

这些信号用于:
- 0x0F 寄存器状态上报
- FAULT/WARN 引脚控制
- 诊断 FSM 触发检测

---

## 4. DC 诊断状态机 (15 态) —— 全局共享

```verilog
localparam DC_DIAG_IDLE        = 4'd0;
localparam DC_DIAG_OBSERVATION = 4'd1;
localparam DC_DIAG_CH1_S2GP    = 4'd2;
localparam DC_DIAG_CH2_S2GP    = 4'd3;
localparam DC_DIAG_CH3_S2GP    = 4'd4;
localparam DC_DIAG_CH4_S2GP    = 4'd5;
localparam DC_DIAG_CH1_SLICK   = 4'd6;
localparam DC_DIAG_CH2_SLICK   = 4'd7;
localparam DC_DIAG_CH3_SLICK   = 4'd8;
localparam DC_DIAG_CH4_SLICK   = 4'd9;
localparam DC_DIAG_CH1_LO      = 4'd10;
localparam DC_DIAG_CH2_LO      = 4'd11;
localparam DC_DIAG_CH3_LO      = 4'd12;
localparam DC_DIAG_CH4_LO      = 4'd13;
localparam DC_DONE             = 4'd14;
```

**触发条件**: any_ch_diag=1 (某通道进入 CH_DC_DIAG_ENTRY)
**完成通知**: 各 ch_diag_done[i] 信号

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

**触发条件**: any_ch_ac=1 (某通道进入 CH_AC_DIAG_ENTRY)
**完成通知**: 各 ch_ac_done[i] 信号

---

## 6. 设计检查清单

- [ ] 芯片级FTL是否仅有3态 (PowerOn/STANDBY/ACT)
- [ ] Hi-Z/Play/Mute 是否仅在通道 FSM 中实现
- [ ] 4 通道 FSM 是否完全独立
- [ ] 聚合信号是否为组合逻辑 (非状态机)
- [ ] 通道 FSM 是否直接通过 0x04 驱动 (非芯片 FSM 中介)
- [ ] chip_active=0 时是否所有通道立即回 CH_HIGH_Z
- [ ] DC FSM 是否检测 any_ch_diag 启动
- [ ] AC FSM 是否检测 any_ch_ac 启动
- [ ] ch_diag_done/ac_done 是否直接回到通道 FSM
