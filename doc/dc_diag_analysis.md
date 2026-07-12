# DC诊断深度分析与模块集成决策文档

> **版本**: v2.1.0  
> **日期**: 2026-07-11  
> **状态**: 待审核  
> **类型**: 纯架构分析，不涉及代码生成  
> **前置文档**: `architecture_refinement.md`（v2架构优化方案）

---

## 1. DC诊断定位深度分析

### 1.1 datasheet关键证据

#### 证据1：0x09寄存器bit0 `LDG BYPASS`（决定性证据）

**datasheet 9.6.7表9-16原文**：

| Bit | Field | Reset | Description |
|-----|-------|-------|-------------|
| 0 | LDG BYPASS | 0 | **0: Automatic diagnostics when leaving Hi-Z and after channel fault** |
|   |         |   | **1: Diagnostics are not run automatically** |

**结论**：DC诊断的自动触发是**寄存器可配**的，默认值0=自动触发。

#### 证据2：9.3.8节描述

> "The DC diagnostics **are turned on by default**, but if a fast startup without diagnostics is required, the DC diagnostics can be **bypassed through I2C**."

> "The DC diagnostics **runs when any channel is directed to leave the Hi-Z state and enter the MUTE or PLAY state**."

> "DC Diagnostics can be started from any operating condition, but if the channel is in PLAY state, then the time to complete the diagnostic is longer because the device must **ramp down the audio signal** of that channel before transitioning to the Hi-Z state."

#### 证据3：0x09寄存器完整位定义

| Bit | Field | Reset | Description |
|-----|-------|-------|-------------|
| 7 | DC LDG ABORT | 0 | 1: 中止进行中的诊断 |
| 6 | 2x_RAMP | 0 | 1: 双倍ramp时间 |
| 5 | 2x_SETTLE | 0 | 1: 双倍稳定时间 |
| 4-2 | RESERVED | 000 | - |
| 1 | LDG LO ENABLE | 0 | 1: 线路输出诊断使能 |
| 0 | LDG BYPASS | 0 | 0: 自动诊断; 1: 不自动诊断 |

### 1.2 DC诊断的四种触发场景（修正后）

| 场景 | 触发条件 | LDG_BYPASS要求 | datasheet依据 |
|------|---------|---------------|--------------|
| ① **启动诊断** | 上电后首次离开Hi-Z | =0（自动） | 9.3.8 "turned on by default" |
| ② **状态转换诊断** | 0x04从Hi-Z→MUTE/PLAY | =0（自动） | 9.3.8 + 0x09 bit0=0 |
| ③ **手动诊断** | 0x04=DC_DIAG(11) | 任意 | 9.3.8 "can also be enabled manually" |
| ④ **故障恢复诊断** | OC/DC故障CLEAR_FAULT后 | =0（自动） | 0x09 bit0 "after channel fault" |

### 1.3 DC诊断与状态机的关系（核心分析）

**问题**：DC诊断是独立的全局状态（CHIP_DIAG），还是状态转换的中间步骤？

**datasheet行为分析**：

```
场景②状态转换诊断的真实行为：

  当前状态: HI_Z
  MCU写0x04: CH1=PLAY
       │
       ▼
  芯片检测到: 通道请求离开Hi-Z进入PLAY
       │
       ▼
  [自动DC诊断开始]  ← 这是中间步骤，不是独立工作态
       │
       │  诊断期间:
       │  - 通道仍处于Hi-Z（FETs高阻）
       │  - 0x0F状态报告显示什么？→ 应显示DC_DIAG(11)
       │  - 如果在PLAY态触发诊断：先ramp down音频
       │
       ▼
  诊断完成
       │
       ├── 诊断通过 → 进入PLAY态
       │
       └── 诊断失败 → 保持Hi-Z，报告故障
```

**关键推论**：

1. **0x0F状态报告寄存器**会显示`11`(DC_DIAG)——这是通道级状态，不是芯片级状态
2. **芯片全局状态**在诊断期间可能仍在HI_Z（因为FETs高阻）
3. **通道状态**在诊断期间为DC_DIAG(11)
4. **手动诊断**（场景③）时0x04=DC_DIAG，通道状态也为11

**结论**：DC诊断是**通道级状态**，不是芯片级独立状态。

### 1.4 DC诊断定位方案对比

#### 方案A：通道级诊断（推荐——最符合datasheet）

```
主状态机: STANDBY / HI_Z / MUTE / PLAY（4态，无CHIP_DIAG）

通道状态机:
├── CH_PLAY (00)
├── CH_HI_Z (01)
├── CH_MUTE (10)
├── CH_DC_DIAG (11)  ← 诊断在通道级处理
├── CH_DIAG_PENDING (内部子状态)  ← 自动诊断中间态
└── CH_HICCUP_WAIT (内部子状态)  ← 故障恢复1秒等待

通道状态转换:
  CH_HI_Z ──(0x04=PLAY, LDG_BYPASS=0)──► CH_DIAG_PENDING ──(pass)──► CH_PLAY
                                               │
                                               └──(fail)──► CH_HI_Z

  CH_HI_Z ──(0x04=DC_DIAG)──► CH_DC_DIAG ──(done)──► CH_HI_Z

  CH_PLAY ──(OC fault)──► CH_HI_Z ──(CLEAR_FAULT, LDG_BYPASS=0)──► CH_DIAG_PENDING
                                                                              │
                                                                   ┌──────────┘
                                                                   │
                                                              诊断通过 → CH_PLAY
                                                              诊断失败 → CH_HICCUP_WAIT(1s) → 重试
```

**优点**：
- ✅ 完全符合datasheet（0x0F报告通道级DC_DIAG状态）
- ✅ 4通道可独立诊断（不同通道可同时处于不同状态）
- ✅ 主状态机简化为4态
- ✅ 支持自动诊断+手动诊断统一处理

**缺点**：
- ⚠️ channel_fsm复杂度增加（新增子状态）
- ⚠️ 需要diagnostic_ctrl支持通道级独立诊断

---

#### 方案B：全局诊断态（当前实现——简化）

```
主状态机: STANDBY / HI_Z / MUTE / PLAY / CHIP_DIAG（5态）

通道状态机: CH_PLAY / CH_HI_Z / CH_MUTE / CH_DC_DIAG（4态，无子状态）

全局转换:
  HI_Z ──(any_ch_diag)──► CHIP_DIAG ──(diag_done)──► HI_Z
```

**优点**：
- ✅ 实现简单
- ✅ 当前RTL已实现

**缺点**：
- ❌ 不符合datasheet（诊断应是转换中间步骤，不是独立全局态）
- ❌ 4通道不能同时独立诊断（一个通道诊断时全局都在DIAG态）
- ❌ 缺少自动诊断触发
- ❌ 缺少故障恢复诊断

---

#### 方案C：混合方案（主状态机无DIAG态，通道级处理诊断）

```
主状态机: STANDBY / HI_Z / MUTE / PLAY（4态）

通道状态机:
├── CH_PLAY / CH_HI_Z / CH_MUTE / CH_DC_DIAG
└── 诊断由diagnostic_ctrl独立处理，通道状态跟随

主状态机根据通道状态汇总:
  - 所有通道Hi-Z → HI_Z
  - 任意通道PLAY → PLAY
  - 任意通道MUTE → MUTE
  - 任意通道DC_DIAG → HI_Z（诊断期间全局处于HI_Z）
```

**优点**：
- ✅ 主状态机简化
- ✅ 通道可独立诊断

**缺点**：
- ⚠️ 主状态机与通道状态需要协调逻辑
- ⚠️ 诊断期间全局状态为HI_Z可能不够精确

---

### 1.5 DC诊断定位推荐

**推荐方案A（通道级诊断）**，理由：

1. **datasheet一致性**：0x0F寄存器报告通道级状态，DC_DIAG(11)是通道状态
2. **功能正确性**：支持4种触发场景
3. **架构清晰性**：主状态机仅管理工作态（4态），诊断是通道级行为
4. **可扩展性**：4通道独立诊断互不干扰

**方案A下的模块修改**：

| 模块 | 修改内容 |
|------|---------|
| `state_machine` | 移除CHIP_DIAG态，仅保留4态；根据通道状态汇总全局状态 |
| `channel_fsm` | 新增CH_DIAG_PENDING和CH_HICCUP_WAIT子状态；支持自动诊断请求 |
| `diagnostic_ctrl` | 支持4通道独立诊断；接收通道级诊断请求 |
| `tas6424e_defines` | 移除CHIP_DIAG定义；新增CH_DIAG_PENDING等子状态编码 |

---

## 2. 模块集成决策（独立vs集成）

### 2.1 决策原则

| 原则 | 说明 |
|------|------|
| **功能内聚** | 功能紧密耦合的模块应集成 |
| **接口最小化** | 模块间接口信号少的可独立 |
| **可复用性** | 通用功能独立成模块 |
| **可测试性** | 独立模块便于单元测试 |
| **datasheet对应** | 模块划分应与datasheet功能块对应 |

### 2.2 新增模块的集成决策

#### 决策1：ramp_ctrl — 集成到audio_interface（推荐）

**分析**：
- ramp功能作用于音频数据流
- ramp_ctrl与audio_interface接口信号多（audio_data×4, fsync, ramp_req）
- datasheet中ramp是音频通路的一部分（9.3.3音量ramp、9.3.8诊断ramp）

**决策**：**集成到audio_interface**，在模块内增加ramp逻辑

**理由**：
- ✅ 功能内聚：ramp是音频数据处理的一部分
- ✅ 接口最小化：避免audio_data×4在模块间传递
- ✅ datasheet对应：ramp在音频数据通路中

**audio_interface新增接口**：
```
input  wire        ramp_down_req    // 来自state_machine的ramp请求
output wire        ramp_down_done   // ramp完成信号
input  wire [1:0]  vol_ramp_rate    // 来自0x01寄存器
```

---

#### 决策2：volume_ctrl — 集成到audio_interface（推荐）

**分析**：
- 音量控制作用于音频数据流
- volume_ctrl与audio_interface接口信号多（audio_data×4, vol_reg×4, fsync）
- datasheet中音量控制在音频通路中（9.3.3）

**决策**：**集成到audio_interface**

**理由**：
- ✅ 功能内聚：音量是音频数据处理的一部分
- ✅ 接口最小化：避免audio_data×4在模块间传递
- ✅ 与ramp_ctrl共享fsync和ramp逻辑

**audio_interface新增接口**：
```
input  wire [7:0]  ch1_vol ~ ch4_vol    // 来自0x05-0x08寄存器
input  wire [1:0]  gain_setting         // 来自0x01寄存器bit1-0
```

---

#### 决策3：HPF — 集成到audio_interface（推荐）

**分析**：
- HPF作用于音频数据流
- datasheet 9.3.2明确HPF在数据通路中

**决策**：**集成到audio_interface**

**理由**：
- ✅ 功能内聚：HPF是音频数据预处理
- ✅ datasheet对应：9.3.2 DC Blocking

**audio_interface新增接口**：
```
input  wire [3:0]  hpf_fc           // 来自0x26寄存器bit3-0
input  wire        hpf_bypass       // 来自0x01寄存器bit7
```

---

#### 决策4：通道级OTSD — 集成到protection + fault_monitor

**分析**：
- 通道级OTSD是保护功能的一部分
- protection已处理全局OTSD去毛刺

**决策**：**集成到现有protection和fault_monitor**

**理由**：
- ✅ 功能内聚：OTSD是保护电路功能
- ✅ 避免新增模块

**修改**：
- `protection`新增4个通道级OTSD输入
- `fault_monitor`将通道级OTSD分类为通道故障（非全局故障）

---

#### 决策5：0x14故障屏蔽 — 集成到pin_control

**分析**：
- 0x14寄存器已输出到pin_control
- 屏蔽逻辑在FAULT/WARN引脚驱动处实现

**决策**：**集成到现有pin_control**

---

#### 决策6：0x21新增位 — 集成到register_file

**分析**：
- pbtl_ch_sel和mask_ilimit_warning是寄存器位解码

**决策**：**集成到现有register_file**，新增2个输出信号

---

### 2.3 集成决策汇总

| 功能 | 决策 | 目标模块 | 理由 |
|------|------|---------|------|
| ramp_ctrl | 集成 | audio_interface | 音频数据通路内聚 |
| volume_ctrl | 集成 | audio_interface | 音频数据通路内聚 |
| HPF | 集成 | audio_interface | 音频数据通路内聚 |
| 通道级OTSD | 集成 | protection + fault_monitor | 保护功能内聚 |
| 0x14屏蔽 | 集成 | pin_control | 引脚控制内聚 |
| 0x21新增位 | 集成 | register_file | 寄存器解码内聚 |

**结论**：**不新增任何独立模块**，所有优化功能集成到现有模块中。

**优势**：
- ✅ 模块数量不变（仍为12个+顶层=13个文件）
- ✅ 接口复杂度最低
- ✅ 符合datasheet功能块划分

---

## 3. 优化后audio_interface架构

### 3.1 audio_interface内部数据通路（优化后）

```
┌──────────────────────────────────────────────────────────┐
│ audio_interface (优化后)                                 │
│                                                          │
│  MCLK/SCLK/FSYNC/SDIN1/SDIN2                            │
│       │                                                  │
│       ▼                                                  │
│  ┌──────────┐                                            │
│  │ 时钟同步  │ 2级DFF同步到clk域                         │
│  │ + 边沿检测│                                            │
│  └────┬─────┘                                            │
│       │                                                  │
│       ▼                                                  │
│  ┌──────────┐                                            │
│  │ 模式解码  │ I2S/LJ/DSP/TDM 8种模式                    │
│  │ + 移位寄存│ 24bit×4通道数据锁存                        │
│  └────┬─────┘                                            │
│       │ raw_audio_data_ch1~4 [23:0]                      │
│       ▼                                                  │
│  ┌──────────┐                                            │
│  │ HPF滤波器 │ 一阶IIR，4/8/15/30Hz可选  ← 0x26寄存器    │
│  │ (DC阻断)  │ hpf_bypass控制旁路       ← 0x01 bit7      │
│  └────┬─────┘                                            │
│       │ hpf_audio_data_ch1~4 [23:0]                      │
│       ▼                                                  │
│  ┌──────────┐                                            │
│  │ 音量控制  │ 4通道独立音量              ← 0x05-0x08     │
│  │ + 增益ramp│ -100~+24dB, 0.5dB步进     ← 0x01 bit1-0   │
│  │           │ ramp速率1/2/4/8 FSYNC     ← 0x01 bit3-2   │
│  └────┬─────┘                                            │
│       │ vol_audio_data_ch1~4 [23:0]                      │
│       ▼                                                  │
│  ┌──────────┐                                            │
│  │ Ramp控制  │ 状态转换ramp down/up                      │
│  │ (防pop)   │ PLAY→Hi-Z前ramp到0                        │
│  │           │ STANDBY前5ms ramp到0                      │
│  └────┬─────┘                                            │
│       │ audio_data_ch1~4 [23:0] (最终输出)               │
│       ▼                                                  │
│  输出到pwm_generator                                     │
│                                                          │
│  新增控制接口:                                            │
│  - ramp_down_req (input, 来自state_machine)              │
│  - ramp_down_done (output, 到state_machine)              │
│  - ch1~4_vol (input, 来自0x05-0x08)                      │
│  - gain_setting[1:0] (input, 来自0x01 bit1-0)            │
│  - vol_ramp_rate[1:0] (input, 来自0x01 bit3-2)           │
│  - hpf_fc[3:0] (input, 来自0x26 bit3-0)                  │
│  - hpf_bypass (input, 来自0x01 bit7)                     │
└──────────────────────────────────────────────────────────┘
```

### 3.2 audio_interface优化后接口

```verilog
module audio_interface (
    input  wire        clk,
    input  wire        rst_n,
    
    // 音频总线输入（原有）
    input  wire        mclk,
    input  wire        sclk,
    input  wire        fsync,
    input  wire        sdin1,
    input  wire        sdin2,
    
    // 配置（原有+新增）
    input  wire [2:0]  sap_mode,           // 0x03 [2:0] 音频模式
    input  wire [3:0]  hpf_fc,             // 0x26 [3:0] HPF截止频率（新增）
    input  wire        hpf_bypass,         // 0x01 [7]   HPF旁路（新增）
    input  wire [7:0]  ch1_vol,            // 0x05 音量（新增）
    input  wire [7:0]  ch2_vol,            // 0x06（新增）
    input  wire [7:0]  ch3_vol,            // 0x07（新增）
    input  wire [7:0]  ch4_vol,            // 0x08（新增）
    input  wire [1:0]  gain_setting,       // 0x01 [1:0] 增益（新增）
    input  wire [1:0]  vol_ramp_rate,      // 0x01 [3:2] ramp速率（新增）
    
    // Ramp控制（新增）
    input  wire        ramp_down_req,      // 来自state_machine
    output wire        ramp_down_done,     // 到state_machine
    
    // 音频数据输出（原有）
    output reg  [23:0] audio_data_ch1,     // 最终处理后的音频数据
    output reg  [23:0] audio_data_ch2,
    output reg  [23:0] audio_data_ch3,
    output reg  [23:0] audio_data_ch4,
    output reg         audio_valid
);
```

---

## 4. 优化后状态机完整设计

### 4.1 主状态机（优化后——4态）

```
状态集合（移除CHIP_DIAG）：
├── STANDBY  (3'd0)  待机：FETs高阻，振荡器关闭
├── HI_Z     (3'd1)  高阻：FETs高阻，振荡器工作
├── MUTE     (3'd2)  静音：FETs 50%占空比
├── PLAY     (3'd3)  播放：FETs音频调制

全局状态由通道状态汇总:
  all_ch_hiz  → HI_Z
  any_ch_play → PLAY
  any_ch_mute → MUTE
  诊断期间通道为DC_DIAG → 全局HI_Z（FETs高阻）
```

**状态转换（优化后）**：

```
STANDBY:
  └── standby_n=1 → HI_Z

HI_Z:
  ├── !standby_n → STANDBY
  ├── global_fault → HI_Z（保持，记录pre_fault_state）
  ├── clock_recovered → pre_fault_state（自动恢复）
  ├── any_ch_play (诊断通过后) → PLAY
  ├── any_ch_mute (诊断通过后) → MUTE
  └── all_ch_hiz → HI_Z（保持）

MUTE:
  ├── !standby_n → [ramp_down] → STANDBY
  ├── global_fault → HI_Z
  ├── clock_lost → HI_Z（记录pre_fault=MUTE）
  ├── any_ch_play → PLAY
  └── all_ch_hiz → HI_Z

PLAY:
  ├── !standby_n → [ramp_down] → STANDBY
  ├── global_fault → HI_Z
  ├── clock_lost → HI_Z（记录pre_fault=PLAY）
  ├── any_ch_mute → MUTE
  └── all_ch_hiz → HI_Z
```

### 4.2 通道状态机（优化后——含诊断子状态）

```
通道状态集合:
├── CH_PLAY        (2'd0)  播放
├── CH_HI_Z        (2'd1)  高阻
├── CH_MUTE        (2'd2)  静音
├── CH_DC_DIAG     (2'd3)  DC诊断（0x04=11时，手动诊断）
├── CH_DIAG_PENDING (内部)  自动诊断中间态（不通过0x04配置）
└── CH_HICCUP_WAIT  (内部)  故障恢复1秒等待
```

**通道状态转换（优化后）**：

```
CH_HI_Z:
  ├── 0x04=PLAY, LDG_BYPASS=0 → CH_DIAG_PENDING(自动诊断)
  ├── 0x04=PLAY, LDG_BYPASS=1 → CH_PLAY(跳过诊断)
  ├── 0x04=MUTE, LDG_BYPASS=0 → CH_DIAG_PENDING(自动诊断)
  ├── 0x04=MUTE, LDG_BYPASS=1 → CH_MUTE(跳过诊断)
  ├── 0x04=DC_DIAG → CH_DC_DIAG(手动诊断)
  └── ch_fault_latched → CH_HI_Z(保持)

CH_DIAG_PENDING (自动诊断中间态):
  ├── diag_pass → CH_PLAY/CH_MUTE(进入目标态)
  └── diag_fail → CH_HI_Z(诊断失败保持高阻)

CH_DC_DIAG (手动诊断):
  └── diag_done → CH_HI_Z

CH_PLAY/CH_MUTE:
  ├── ch_fault(OC/DC) → CH_HI_Z(故障锁存)
  ├── 0x04=HI_Z → CH_HI_Z
  ├── 0x04=DC_DIAG → CH_DC_DIAG
  └── !standby_n → CH_HI_Z

CH_HI_Z(故障锁存):
  ├── CLEAR_FAULT, LDG_BYPASS=0 → CH_DIAG_PENDING(故障恢复诊断)
  └── CLEAR_FAULT, LDG_BYPASS=1 → CH_HI_Z(清除锁存，等待0x04配置)

CH_HICCUP_WAIT (故障恢复诊断失败):
  ├── 1秒定时器到 → CH_DIAG_PENDING(重试诊断)
  └── 持续重试直到诊断通过
```

---

## 5. 寄存器映射修正

### 5.1 DC诊断寄存器完整映射（修正）

#### 0x09 - DC Load Diagnostics Control 1 [默认=0x00]

| Bit | Field | 描述 |
|-----|-------|------|
| 7 | DC LDG ABORT | 1: 中止进行中的诊断 |
| 6 | 2x_RAMP | 1: 双倍ramp时间 |
| 5 | 2x_SETTLE | 1: 双倍稳定时间 |
| 4-2 | RESERVED | - |
| 1 | LDG LO ENABLE | 1: 线路输出诊断使能 |
| 0 | LDG BYPASS | 0: 自动诊断(离开Hi-Z+故障后); 1: 不自动 |

#### 0x0A - DC Load Diagnostics Control 2 [默认=0x11]

| Bit | Field | 描述 |
|-----|-------|------|
| 7-4 | CH1 DC LDG SL | CH1短路负载阈值(0.5~5Ω) |
| 3-0 | CH2 DC LDG SL | CH2短路负载阈值 |

#### 0x0B - DC Load Diagnostics Control 3 [默认=0x11]

| Bit | Field | 描述 |
|-----|-------|------|
| 7-4 | CH3 DC LDG SL | CH3短路负载阈值 |
| 3-0 | CH4 DC LDG SL | CH4短路负载阈值 |

#### 0x0C - DC Load Diagnostics Report 1 [默认=0x00]

| Bit | Field | 描述 |
|-----|-------|------|
| 7 | CH1 S2G | CH1短路到地 |
| 6 | CH1 S2P | CH1短路到电源 |
| 5 | CH1 OL | CH1开路 |
| 4 | CH1 SL | CH1短路负载 |
| 3 | CH2 S2G | CH2短路到地 |
| 2 | CH2 S2P | CH2短路到电源 |
| 1 | CH2 OL | CH2开路 |
| 0 | CH2 SL | CH2短路负载 |

#### 0x0D - DC Load Diagnostics Report 2 [默认=0x00]

| Bit | Field | 描述 |
|-----|-------|------|
| 7 | CH3 S2G | CH3短路到地 |
| 6 | CH3 S2P | CH3短路到电源 |
| 5 | CH3 OL | CH3开路 |
| 4 | CH3 SL | CH3短路负载 |
| 3 | CH4 S2G | CH4短路到地 |
| 2 | CH4 S2P | CH4短路到电源 |
| 1 | CH4 OL | CH4开路 |
| 0 | CH4 SL | CH4短路负载 |

#### 0x0E - DC Load Diagnostics Report 3 Line Output [默认=0x00]

| Bit | Field | 描述 |
|-----|-------|------|
| 7-4 | RESERVED | - |
| 3 | CH1 LO LDG | CH1线路输出检测 |
| 2 | CH2 LO LDG | CH2线路输出检测 |
| 1 | CH3 LO LDG | CH3线路输出检测 |
| 0 | CH4 LO LDG | CH4线路输出检测 |

### 5.2 音量寄存器映射修正

#### 0x05-0x08 - Channel Volume [默认=0xCF]

| 值 | dB |
|-----|-----|
| 0xFF | +24 dB |
| 0xCF | 0 dB（默认） |
| 0x07 | -100 dB |
| <0x07 | MUTE |

### 5.3 0x01寄存器位定义（完整修正）

| Bit | Field | 描述 |
|-----|-------|------|
| 7 | HPF_BYPASS | 1: HPF旁路 |
| 6-5 | OTW_CTRL[1:0] | 过温警告阈值 |
| 4 | OC_CTRL | 过流限制级别 |
| 3-2 | VOL_RATE[1:0] | 音量ramp速率(1/2/4/8 FSYNC) |
| 1-0 | GAIN[1:0] | 输出增益(7.5/15/21/29V) |

---

## 6. 优化后模块修改清单（仅文档）

### 6.1 需修改的模块（10个）

| 模块 | 修改内容 | 新增接口 |
|------|---------|---------|
| `tas6424e_defines.v` | 移除CHIP_DIAG；新增CH_DIAG_PENDING/HICCUP编码；新增0x09位域定义 | - |
| `register_file.v` | 新增0x09位域输出(ldg_bypass/ldg_lo_enable等)；新增0x21位输出(pbtl_ch_sel/mask_ilimit) | +6个输出 |
| `state_machine.v` | 移除CHIP_DIAG态(4态)；新增pre_fault_state；新增clock_recovered处理；优先级调整 | +2输入, +1输出 |
| `channel_fsm.v` | 新增CH_DIAG_PENDING/HICCUP_WAIT子状态；自动诊断请求；hiccup定时器 | +3输入, +2输出 |
| `audio_interface.v` | 集成HPF+音量+ramp；新增大量控制接口 | +10输入, +1输出 |
| `pwm_generator.v` | 无重大修改（接收处理后的音频数据） | - |
| `diagnostic_ctrl.v` | 支持4通道独立诊断；支持自动/手动/故障恢复三种模式 | +4输入 |
| `clock_monitor.v` | 新增clock_recovered输出 | +1输出 |
| `protection.v` | 新增4通道级OTSD输入 | +4输入, +4输出 |
| `fault_monitor.v` | 通道级OTSD分类；0x14屏蔽位输出到pin_control | +4输入, +7输出 |
| `pin_control.v` | 0x14寄存器7个屏蔽位实现 | +7输入 |
| `tas6424e_top.v` | 连接新增信号；通道级OTSD信号 | +4引脚 |

### 6.2 不新增模块

**所有优化功能集成到现有12个模块中，不新增独立模块。**

---

## 7. 待确认决策点（更新）

### 决策1：DC诊断定位

**推荐**：方案A（通道级诊断，移除CHIP_DIAG全局态）

- [ ] 同意方案A
- [ ] 保留方案B（当前CHIP_DIAG实现）
- [ ] 选择方案C（混合方案）

### 决策2：模块集成

**推荐**：全部集成到现有模块，不新增独立模块

- [ ] 同意全部集成
- [ ] 部分独立（请指定）

### 决策3：后续工作

- [ ] 继续完善文档（补充verification_plan.md）
- [ ] 开始修改RTL代码
- [ ] 更新plan.md计划
- [ ] 其他（请说明）

---

## 8. 总结

### 8.1 DC诊断定位结论

DC诊断是**通道级行为**，不是芯片级独立状态。推荐：
- 主状态机简化为4态（STANDBY/HI_Z/MUTE/PLAY）
- 通道状态机新增CH_DIAG_PENDING和CH_HICCUP_WAIT子状态
- diagnostic_ctrl支持4通道独立诊断

### 8.2 模块集成结论

所有优化功能集成到现有模块，**不新增独立模块**：
- HPF + 音量 + ramp → 集成到audio_interface
- 通道级OTSD → 集成到protection + fault_monitor
- 0x14屏蔽 → 集成到pin_control
- 0x21新增位 → 集成到register_file

### 8.3 寄存器映射修正

DC诊断报告寄存器0x0C-0x0E的位定义与之前文档不同：
- **之前（错误）**：每通道2位编码（00正常/01开路/10短路地/11短路电源）
- **实际（正确）**：每通道4个独立bit（S2G/S2P/OL/SL）+ 0x0E线路输出各1bit

> **请审核本文档后告知决策结果。**
