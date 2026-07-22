# TAS6424E-Q1 架构纠正分析

> **版本**: C1.0.0  
> **日期**: 2026-07-22  
> **状态**: 架构纠正 — 通道状态机建模错误修正

---

## 0. 核心发现

对 `四个通道的状态跳转.jpg` 的深入分析揭示了之前架构文档中的**重大建模错误**：

### 错误理解（v3.0之前）

```
通道状态机 ×4  —— 4个独立的状态机实例，各自独立运行
  ├── channel_fsm[0] (CH1)
  ├── channel_fsm[1] (CH2)
  ├── channel_fsm[2] (CH3)
  └── channel_fsm[3] (CH4)
```

### 正确理解（v4.0）

```
四个通道的状态跳转图  —— 一张图描述所有通道，状态重叠表示复合视图
  │
  └── 每个宏状态 (CH_HIGH_Z/CH_PLAY/CH_MUTE/CH_SINGLE_DC_DIAG/CH_AC_DIAG)
      同时包含4个通道的子状态，通过 0x04[7:0] 2bit×4 寄存器字段编码
```

---

## 1. 证据分析

### 1.1 为什么不是4个独立FSM

1. **硬件事实**: 0x04寄存器只有8位（4个通道×2bit），这是一种**共享编码**，不是4个独立控制信号
2. **状态重叠**: `四个通道的状态跳转.jpg` 中 CH_HIGH_Z、CH_PLAY、CH_MUTE 三个区域互相重叠——这意味着它是一个**复合视图**，展示所有通道在同一张图中的行为
3. **datasheet数据**: `四个通道的状态跳转.jpg` 的功能经过提取和分析，比 `系统应用状态图.jpg` 更可靠
4. **芯片行为**: 当 `chip_state == CHIP_HI_Z` 时，**所有4个通道同时强制进入Hi-Z** —— 不存在某个通道在Hi-Z而另一个在PLAY的可能性

### 1.2 为什么系统应用状态图不够可靠

1. **初期定义**: `系统应用状态图.jpg` 是早期的概念定义
2. **缺失细节**: 缺少通道间的协作关系、诊断触发逻辑、故障恢复路径
3. **过于简化**: 很多状态转换条件模糊不清

**因此**: 后续架构定义应以 `四个通道的状态跳转.jpg` 为主要参考，`系统应用状态图.jpg` 仅作为辅助参考。

---

## 2. 正确的通道状态管理模型

### 2.1 通道状态由组合派生（非独立FSM）

每个通道的当前状态由以下三个输入的**组合逻辑**决定：

```verilog
// 通道i (i=0,1,2,3) 的状态派生逻辑
wire [1:0] ch_state_i;

// 输入1: 全局芯片状态
// 输入2: 0x04寄存器 [i*2+1 : i*2] 字段
// 输入3: AC诊断使能 (0x15/0x16)

// HI_Z和STANDBY状态下, 强制所有通道为Hi-Z (无视0x04)
// AC_DIAG/SINGLE_DC_DIAG 状态下, 按0x04配置决定诊断
// PLAY/MUTE 状态下, 按0x04配置决定播放/静音/Hi-Z

assign ch_state_i = (chip_state == CHIP_HI_Z || chip_state == CHIP_STANDBY) 
                    ? CH_HI_Z
                    : (chip_state == CHIP_AC_DIAG && ac_diag_en[i])
                      ? CH_AC_DIAG
                      : (chip_state == CHIP_SINGLE_DIAG && reg_04[i*2+:2] == DC_DIAG)
                        ? CH_SINGLE_DC_DIAG
                        : reg_04[i*2+:2];  // 0x04直接编码: 00=PLAY, 01=HI_Z, 10=MUTE
```

### 2.2 通道使能信号的组合派生

```verilog
// 不需要独立的状态机状态寄存器！
// ch_en/ch_mute_mode/ch_diag_active 全部由组合逻辑派生

assign ch_en[i]         = (ch_state_i == CH_PLAY) || (ch_state_i == CH_MUTE);
assign ch_mute_mode[i]  = (ch_state_i == CH_MUTE);
assign ch_diag_active[i] = (ch_state_i == CH_SINGLE_DC_DIAG);
assign ch_ac_active[i]  = (ch_state_i == CH_AC_DIAG);
```

### 2.3 正确的状态机层次

```
顶层包装 (3态)     PowerOn / STANDBY / ACT
  │
  └── 芯片主状态机 (5态)   Hi-Z / Play / Mute / Single_Diag / Auto_Diag
       │
       ├── 通道状态派生 (组合逻辑) ─ 4通道×2bit 从 reg_04[7:0] 解码
       │
       ├── DC诊断FSM (15态)
       └── AC诊断FSM (6态)

【关键变化】: 取消 4×channel_fsm 独立实例！
  通道状态不再是独立FSM，而是组合派生逻辑。
```

---

## 3. 架构影响

### 3.1 模块精简

| 项目 | 旧架构 (v3.0) | 新架构 (v4.0) |
|------|------------|------------|
| channel_fsm 实例数 | 4 | **0** (取消) |
| 通道状态生成 | 4个FSM, 每个5态 | **组合派生逻辑** |
| RTL文件总数 | 12 | **11** (少1个) |
| 内联信号数 | ~120 | **~70** (少50根) |
| 预估代码行 | ~4400 | **~3800** (少600行) |

### 3.2 顶层模块结构变化

```
tas6424e_top                          # 顶层
├── i2c_slave                         # 不变
├── register_file                     # 不变
├── state_machine                     # 不变
├── [取消] channel_fsm × 4           # 删除！
├── [新增] channel_state_decoder     # 组合逻辑派生模块 (可选, 也可直接放顶层)
├── audio_interface                   # 不变
├── pwm_generator                     # 不变
├── diagnostic_ctrl                   # 不变
├── fault_monitor                     # 不变
├── pin_control                       # 不变
├── clock_monitor                     # 不变
└── protection                        # 不变
```

### 3.3 通道状态信息流

```
                    ┌──────────────────┐
                    │  register_file   │
                    │  reg_04[7:0]     │ (8bit: 4通道×2bit)
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ channel_state    │
                    │ 组合派生逻辑     │ ◄── chip_state, ac_diag_en
                    └──┬───┬───┬───┬───┘
                       │   │   │   │
               ch_state[1:0]×4       ch_en[3:0], ch_mute[3:0]
                       │   │   │   │   ch_diag_active[3:0], ch_ac_active[3:0]
                       │   │   │   │
                 ┌─────┘   │   │   └─────┐
                 ▼         ▼   ▼         ▼
            pwm_generator  diagnostic_ctrl  audio_interface
```

---

## 4. RTL实现建议

### 4.1 方案A: 直接放顶层

```verilog
// 在 tas6424e_top 中直接声明组合逻辑
wire [1:0] ch_state [0:3];
wire [3:0] ch_en, ch_mute_mode, ch_diag_active, ch_ac_active;

genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin : gen_ch_state
        // 通道状态派生 (纯组合逻辑)
        assign ch_state[i] = (chip_state == CHIP_HI_Z || chip_state == CHIP_STANDBY)
            ? 2'b01   // Hi-Z
            : (chip_state == CHIP_AC_DIAG && ac_diag_en[i])
                ? 2'b11  // AC_DIAG (使用3bit编码中的新值)
                : (chip_state == CHIP_SINGLE_DIAG && reg_04[i*2+:2] == 2'b11)
                    ? 2'b11 // DC_DIAG
                    : reg_04[i*2+:2];

        assign ch_en[i]          = (ch_state[i] == 2'b00) || (ch_state[i] == 2'b10);
        assign ch_mute_mode[i]   = (ch_state[i] == 2'b10);
        assign ch_diag_active[i] = (ch_state[i] == 2'b11) && (chip_state != CHIP_AC_DIAG);
        assign ch_ac_active[i]   = (ch_state[i] == 2'b11) && (chip_state == CHIP_AC_DIAG);
    end
endgenerate
```

### 4.2 方案B: 独立的小模块

```verilog
// 封装为 channel_state_decoder 模块 (11个Verilog文件, 符合规范)
module channel_state_decoder (
    input  wire [2:0]   chip_state,
    input  wire [7:0]   reg_04,
    input  wire [3:0]   ac_diag_en,
    output wire [1:0]   ch_state [0:3],
    output wire [3:0]   ch_en,
    output wire [3:0]   ch_mute_mode,
    output wire [3:0]   ch_diag_active,
    output wire [3:0]   ch_ac_active
);
```

**推荐方案B** —— 代码更清晰，符合模块化设计原则。

---

## 5. 后续行动

1. 以 `四个通道的状态跳转.jpg` 为主要参考，`系统应用状态图.jpg` 降级为辅助参考
2. 重写 `state_machine_detailed_design.md` — 移除 ×4 独立FSM概念
3. 重写 `fsm_design.md` — 同步
4. 更新 `architecture_design_v2.md` — 简化模块树
5. 更新 `module_interface_design.md` — 移除 channel_fsm
6. 更新 `module_functional_design.md` — 简化通道管理
7. 提交并同步远程
