# TAS6424E-Q1 状态机详细设计文档（基于原始状态机图重写）

> **版本**: v3.0.0  
> **日期**: 2026-07-22  
> **状态**: 重构中 - 基于doc_src原始状态机图重写  
> **来源**: doc_src目录下5张原始状态机图  
> **关联文档**: 
> - `fsm_design.md` (将被本文档取代/合并)
> - `architecture_design_v2.md` (架构总览)
> - `module_functional_design.md` (模块功能)

---

## 0. 状态机层次结构（基于doc_src原始图）

本项目包含**5个层级的状态机**，根据doc_src目录下的5张原始状态机图整理：

```
顶层包装 (顶层)         - 系统图 (2状态: PowerOn/ACT/STANDBY)
  │                            ↑
  └── 芯片主状态机 (系统应用状态图) - 正常态4状态 + 故障态图
       │                            ↑
       └── 通道状态机 ×4 (四个通道的状态跳转图) - 5状态
            │                       ↑
            ├── DC诊断FSM (DC诊断的状态跳转) - 15状态
            └── AC诊断FSM (AC诊断的状态跳转) - 6状态
```

---

## 1. 顶层包装状态机 — 系统图（系统图.jpg）

### 1.1 状态定义

```verilog
localparam TOP_POWERON   = 2'd0;  // 上电过渡: 模拟上电时序
localparam TOP_STANDBY   = 2'd1;  // 待机: 最低功耗, I2C可用
localparam TOP_ACT       = 2'd2;  // 激活: 正常工作的主状态
```

### 1.2 状态转换图（原始图复现）

```
                    ┌──────────┐
                    │ PowerOn  │
                    └─────┬────┘
                          │
                          │ (模拟上电时序完成)
                          │ - DVDDPowerOn
                          │ - POR_N释放
                          ▼
                ┌──────────────────────┐
                │                      │
        STANDBY_N=1              STANDBY_N=0
                │                      │
                ▼                      ▼
         ┌──────────┐           ┌──────────┐
         │ STANDBY  │◄─────────►│   ACT    │
         │ (低功耗) │ STANDBY_N  │  (工作)  │
         └──────────┘  !STANDBY_N└──────────┘
         
标注:
- PowerOn: POR_N释放后进入的过渡态
- STANDBY: 待机(可写I2C), 复位源是STANDBY_N
- ACT: 包含Hi-Z/Play/Mute/单次诊断的所有子状态
```

### 1.3 转换条件

| 编号 | 当前态 | 下一态 | 条件 | 优先级 |
|------|--------|--------|------|--------|
| T1 | POWERON | STANDBY | DVDDPowerOn完成 + POR_N释放 + STANDBY_N=1 | — |
| T2 | POWERON | ACT | DVDDPowerOn完成 + POR_N释放 + STANDBY_N=0 | — |
| T3 | STANDBY | ACT | STANDBY_N=0 | — |
| T4 | ACT | STANDBY | STANDBY_N=1 | 最高 |
| T5 | STANDBY | STANDBY | STANDBY_N=1 (自保持) | — |
| T6 | ACT | ACT | STANDBY_N=0 (自保持) | — |

### 1.4 POWERON内部行为

POWERON态执行模拟上电时序：
- VDD上电稳定
- 内部POR释放
- I2C_ADDR引脚建立（tI2C_ADDR ≥ 300µs）
- I2C初始化就绪（tSTART ≤ 12ms）
- 完成后根据STANDBY_N引脚决定进入STANDBY或ACT

---

## 2. 芯片主状态机 — 系统应用状态图（系统应用状态图.jpg）

### 2.1 状态定义

芯片主状态机是ACT状态下的内部细分，**5个状态**：

```verilog
localparam CHIP_HI_Z        = 3'd0;  // 高阻态: 默认/安全状态
localparam CHIP_PLAY        = 3'd1;  // 播放态: 音频调制开关
localparam CHIP_MUTE        = 3'd2;  // 静音频: 50%占空比开关
localparam CHIP_SINGLE_DIAG = 3'd3;  // 单次诊断: MCU触发的DC/AC诊断
localparam CHIP_AUTO_DIAG   = 3'd4;  // 自动诊断: 故障后自动进入
```

### 2.2 正常态转换图（原始图左侧复现）

```
         ┌────────────────────────────────────────────────────────────┐
         │                                                            │
         ▼                                                            │
    ┌──────────┐                                                      │
    │  Hi-Z态  │◄────────── (进入此态) ──────────┐                   │
    │ (默认)   │                                  │                   │
    └──┬───────┘                                  │                   │
       │                                          │                   │
       │ 0x04配置停止诊断                          │ 一次诊断完成      │
       │ (进入诊断前配置)                          │                   │
       │                                          │                   │
       ▼                                          │                   │
    ┌──────────┐         0x04配置/硬件引脚          │                   │
    │ 单次诊断 │         配置播放                   │                   │
    │ 态       │◄────── ┌──────────────────┐       │                   │
    │ (单次)   │        │                  ▼       │                   │
    └──┬───────┘        │            ┌──────────┐  │                   │
       │                │            │ 播放态   │  │                   │
       │ 一次诊断完成   │            │  (Play)  │──┘                   │
       │                │            └─────┬────┘                      │
       │                │                  │ 0x04配置静音              │
       │                │                  │ 硬件引脚静音              │
       │                │                  ▼                           │
       │                │            ┌──────────┐                      │
       │                │            │ 静音频   │                      │
       │                │            │  (Mute)  │── 0x04配置/硬件引脚 ──┘
       │                │            └─────┬────┘                       │
       │                │                  │ 0x04配置诊断态            │
       │                │                  │                           │
       │                │                  └────► 单次诊断态           │
       │                │                                              │
       │                └────────────────► 0x04配置/硬件引脚 ──► 播放态│
       │                                                               │
       └────────────────────────────── (Hi-Z态自身) ──────────────────┘
```

### 2.3 关键转换规则

#### 2.3.1 从Hi-Z态出发

| 触发条件 | 下一态 | 备注 |
|---------|--------|------|
| 0x04配置停止诊断 | CHIP_SINGLE_DIAG | MCU主动配置 |
| 0x04配置/硬件引脚配置静音 | CHIP_MUTE | 含0x04和MUTE引脚 |
| 0x04配置/硬件引脚配置播放 | CHIP_PLAY | 含0x04和MUTE引脚（释放时进入PLAY） |
| 0x04配置诊断态 | CHIP_SINGLE_DIAG | 配置0x04为DC_DIAG |
| 0x04配置Hi-Z | CHIP_HI_Z | 自循环 |

#### 2.3.2 从单次诊断态出发

| 触发条件 | 下一态 | 备注 |
|---------|--------|------|
| 一次诊断完成 | CHIP_HI_Z | 诊断结束后回到Hi-Z |
| 0x04配置Hi-Z | CHIP_HI_Z | 中断诊断 |
| 0x04配置播放/静音 | CHIP_PLAY/CHIP_MUTE | 中断诊断 |
| STANDBY_N=0 | TOP_STANDBY | 顶层强制 |

#### 2.3.3 从播放态/静音频出发

| 触发条件 | 下一态 | 备注 |
|---------|--------|------|
| 0x04配置静音 | CHIP_MUTE | 播放→静音 |
| 0x04配置播放 | CHIP_PLAY | 静音→播放 |
| 硬件引脚静音/释放 | CHIP_PLAY/CHIP_MUTE | 取决于引脚 |
| 0x04配置诊断态 | CHIP_SINGLE_DIAG | 触发单次诊断 |
| 0x04配置Hi-Z | CHIP_HI_Z | 退出 |

### 2.4 故障态转换图（原始图右侧复现 — 图34 故障发生芯片状态转换图）

```
   ┌────────────┐  直流偏置异常/过流关断/其它无效/时钟错误  ┌──────────────┐
   │ 播放态      │ ──────────────────────────────────────► │  自诊断态    │
   │ 静动态      │                                          │  (Auto Diag) │
   │ Hi-Z态      │                                          └──────┬───────┘
   └────────────┘                                                 │
                                                                   │ 0x04指示状态
                                                                   │ 位1
                                                                   ▼
                                                              ┌─────────┐
                                                              │ Hi-Z态  │
                                                              └────┬────┘
                                                                   │ 0x04配置状态位
                                                                   │
                                                                   ▼
                                                              ┌──────────┐
                                                              │ Hi-Z态   │
                                                              │ 复位状态 │
                                                              └──────────┘
```

**故障转换规则**:

| 当前态 | 触发条件 | 下一态 |
|--------|---------|--------|
| 播放态/静动态/Hi-Z态 | 直流偏置异常/过流关断/其它无效/时钟错误 | 自诊断态 |
| 自诊断态 | 异常通道（已修复） | Hi-Z态 |
| 自诊断态 | 0x04指示状态位1 | Hi-Z态 |
| Hi-Z态 (故障保持) | 清除错误标志位 + 0x04指示状态位 | Hi-Z态 (复位状态) |
| Hi-Z态 | DVDD电压/PVDD 0v07A故障 | 复位状态 |

### 2.5 状态表（datasheet 表9-5 — 表5 芯片状态表）

| 模式名称 | 输出级FETs | 内部振荡器 | I2C |
|---------|-----------|-----------|-----|
| 待机 (Standby) | 高阻态 | 关闭 | 关闭 |
| 高阻态 (Hi-Z) | 高阻态 | 工作 | 工作 |
| 静音态 (Mute) | 50%占空比开关 | 工作 | 工作 |
| 播放态 (Play) | 音频调制开关 | 工作 | 工作 |
| 单次诊断态 | 高阻态（诊断中） | 工作 | 工作 |
| 自诊断态 | 高阻态（诊断中） | 工作 | 工作 |

### 2.6 关键设计注释（来自datasheet §9.4.1注释）

- **芯片上电复位处于Hi-Z态，且0x13复位标志位置1** ← 重要！
- **芯片在任何状态，当STANDBY引脚拉低时，都会进入待机状态**。拉高时将回到原状态。如果状态为静音或播放态，则会触发自动DC诊断
- **跳过自动诊断可在寄存器配置"禁止一次/次"完成"**（注：原文有缺字，理解为配置LDG_BYPASS=1可跳过）
- **具体状态表**：见上节2.5

### 2.7 故障整体表（表6 芯片整体故障表）

| 故障/事件 | 故障/事件类别 | 监控模式 | 报告方式 | 响应结果 |
|----------|--------------|---------|---------|---------|
| POR | 电压故障 | all | I2C + WARN引脚 | 待机 |
| VBAT UV / AVCC UV / VBAT or PVDD | 电压故障 | Hi-Z, mute, play | I2C + FAULT引脚 | 高阻态 |

---

## 3. 通道状态机 — 四个通道的状态跳转图（四个通道的状态跳转.jpg）

### 3.1 状态定义

每通道独立运行的状态机，**5个状态**：

```verilog
localparam CH_HIGH_Z          = 3'd0;  // 高阻态
localparam CH_MUTE            = 3'd1;  // 静音频
localparam CH_PLAY            = 3'd2;  // 播放态
localparam CH_SINGLE_DC_DIAG  = 3'd3;  // 单次DC诊断（仅本通道）
localparam CH_AC_DIAG         = 3'd4;  // AC诊断
```

### 3.2 状态转换图（原始图复现）

```
              ┌──────────────────────────────────────────────────────┐
              │                                                      │
              ▼                                                      │
       ┌──────────────┐                                             │
       │  CH_HIGH_Z   │  ◄──── 配置禁止诊断 (回Hi-Z) ──────────┐   │
       │ (CH_HIGH_Z)  │                                         │   │
       └──┬────┬──┬────┘                                        │   │
          │    │  │                                              │   │
          │    │  └─── 配置了AC诊断 ──► CH_AC_DIAG                │   │
          │    │                                                 │   │
          │    └──── 0x04配置/CH_HIGH_Z态 ──► CH_HIGH_Z (自环)   │   │
          │                                                       │   │
          └── 配置禁止诊断 ────► CH_SINGLE_DC_DIAG                 │   │
                                                                   │   │
              ┌──────────────┐                                     │   │
              │CH_SINGLE_    │ ── 0x04配置CH_PLAY ──► CH_PLAY     │   │
              │ DC_DIAG      │                                     │   │
              │ (单次DC)     │ ── 0x04配置CH_MUTE ──► CH_MUTE     │   │
              │              │                                     │   │
              │              │ ── 0x04配置CH_HIGH_Z ──► CH_HIGH_Z ┘   │
              │              │                                         │
              │              │ ── 0x04配置AC诊断 ──► CH_AC_DIAG         │
              │              │                                         │
              │              │ ── 一次单通道完成所有DC诊断              │
              │              │    通道通常完成所有DC诊断                │
              │              │                                         │
              │              │ ── 异常通道完成所有DC诊断               │
              │              │                                         │
              └── 完成单次诊断 ──────────────────────────────────────┘
                1. STANDBY_N取消信号会让任何0x04重新进入配置状态
                2. 不会根据0x04进入AC诊断
                3. AC诊断只能在CH_HIGH_Z态进入
                4. 播放/静音时，关闭功能，进入AC诊断
                5. CH_PLAY存在时溢载后状态是控制输出的
              
       ┌──────────────┐
       │  CH_MUTE     │  ◄── 0x04配置/CH_MUTE态 / 硬件引脚静音 / 配置为静
       │  (Mute)      │
       └──────┬───────┘
              │ 0x04配置诊断态 ──► CH_SINGLE_DC_DIAG
              │ 0x04配置CH_PLAY ──► CH_PLAY
              │ 0x04配置CH_HIGH_Z ──► CH_HIGH_Z
              │
       ┌──────────────┐
       │  CH_PLAY     │  ◄── 0x04配置/CH_PLAY态 / 配置为播放 / 硬件引脚播放
       │  (Play)      │
       └──────┬───────┘
              │ 0x04配置诊断态 ──► CH_SINGLE_DC_DIAG
              │ 0x04配置CH_MUTE ──► CH_MUTE
              │ 0x04配置CH_HIGH_Z ──► CH_HIGH_Z
              │
       ┌──────────────┐
       │  CH_AC_DIAG  │  ◄── 只能从CH_HIGH_Z进入
       │  (AC诊断)    │
       └──────┬───────┘
              │ 完成AC诊断 ──► CH_HIGH_Z
```

### 3.3 完整转换条件表

| 当前态 | 下一态 | 触发条件 | 备注 |
|--------|--------|---------|------|
| CH_HIGH_Z | CH_SINGLE_DC_DIAG | 0x04配置诊断态 + 芯片实际状态配合 | 全局diag_trigger启动 |
| CH_HIGH_Z | CH_AC_DIAG | 0x15/0x16配置了AC诊断 | 仅能从Hi-Z进入 |
| CH_HIGH_Z | CH_HIGH_Z | 0x04配置CH_HIGH_Z | 自环 |
| CH_HIGH_Z | CH_MUTE | 未配置禁止诊断 && 0x04配置静音 && 芯片实际状态=PLAY/MUTE | 条件成立时持续尝试 |
| CH_HIGH_Z | CH_PLAY | 未配置禁止诊断 && 0x04配置播放 && 芯片实际状态=PLAY/MUTE | 条件成立时持续尝试 |
| CH_SINGLE_DC_DIAG | CH_HIGH_Z | 一次单通道完成所有DC诊断 | 正常退出 |
| CH_SINGLE_DC_DIAG | CH_HIGH_Z | 异常通道完成所有DC诊断 | 异常修复后 |
| CH_SINGLE_DC_DIAG | CH_PLAY | 0x04配置CH_PLAY | 中断诊断 |
| CH_SINGLE_DC_DIAG | CH_MUTE | 0x04配置CH_MUTE | 中断诊断 |
| CH_SINGLE_DC_DIAG | CH_HIGH_Z | 0x04配置CH_HIGH_Z | 中断诊断 |
| CH_SINGLE_DC_DIAG | CH_AC_DIAG | 0x04配置AC诊断 | 切换诊断类型 |
| CH_MUTE | CH_PLAY | 0x04配置CH_PLAY / 硬件引脚释放 | 正常切换 |
| CH_MUTE | CH_SINGLE_DC_DIAG | 0x04配置诊断态 | 触发诊断 |
| CH_MUTE | CH_HIGH_Z | 0x04配置CH_HIGH_Z | 退出 |
| CH_PLAY | CH_MUTE | 0x04配置CH_MUTE / 硬件引脚拉低 | 正常切换 |
| CH_PLAY | CH_SINGLE_DC_DIAG | 0x04配置诊断态 | 触发诊断 |
| CH_PLAY | CH_HIGH_Z | 0x04配置CH_HIGH_Z | 退出 |
| CH_AC_DIAG | CH_HIGH_Z | 完成AC诊断 | 正常退出 |
| 任意状态 | CH_HIGH_Z | STANDBY_N=0 / 全局故障 | 顶层强制 |

### 3.4 关键设计注释（来自原始图）

1. **STANDBY_N取消信号会让任何0x04重新进入配置状态**（即全局STANDBY会复位通道状态机）
2. **不会根据0x04进入AC诊断**（AC诊断需要0x15/0x16显式配置）
3. **AC诊断只能在CH_HIGH_Z态进入**
4. **播放/静音时，关闭功能，进入AC诊断**（这里"关闭"是描述错误：应该是播放/静音时不允许进入AC诊断，必须先回Hi-Z）
5. **CH_PLAY存在时溢载后状态是控制输出的**（过流等通道故障时，CH_PLAY会回CH_HIGH_Z）

### 3.5 通道使能信号逻辑

| ch_state | ch_en | ch_mute_mode | ch_diag_active | ch_ac_diag_active | PWM输出 |
|----------|-------|-------------|---------------|------------------|---------|
| CH_PLAY (3'd2) | 1 | 0 | 0 | 0 | 音频调制PWM |
| CH_HIGH_Z (3'd0) | 0 | 0 | 0 | 0 | 高阻（输出0） |
| CH_MUTE (3'd1) | 1 | 1 | 0 | 0 | 50%占空比方波 |
| CH_SINGLE_DC_DIAG (3'd3) | 0 | 0 | 1 | 0 | 高阻（诊断模式） |
| CH_AC_DIAG (3'd4) | 0 | 0 | 0 | 1 | 高阻（AC诊断） |

### 3.6 与芯片主状态机的关系

通道状态机的运行受芯片主状态机控制：

```
芯片主状态 | 通道可进入状态
----------|----------------
CHIP_HI_Z | CH_HIGH_Z (必须)
CHIP_PLAY | CH_HIGH_Z / CH_PLAY / CH_MUTE
CHIP_MUTE | CH_HIGH_Z / CH_PLAY / CH_MUTE
CHIP_SINGLE_DIAG | CH_HIGH_Z / CH_SINGLE_DC_DIAG / CH_AC_DIAG
CHIP_AUTO_DIAG | CH_HIGH_Z / CH_SINGLE_DC_DIAG / CH_AC_DIAG
```

---

## 4. DC诊断状态机 — DC诊断的状态跳转图（DC诊断的状态跳转.jpg）

### 4.1 状态定义

**15个状态**，按4个测试项 × 4通道 + IDLE/OBSERVATION/DONE：

```verilog
// DC诊断FSM状态编码 (4位)
localparam DC_DIAG_IDLE         = 4'd0;   // 空闲，等待触发
localparam DC_DIAG_OBSERVATION  = 4'd1;   // 启动准备
localparam DC_DIAG_CH1_S2GP     = 4'd2;   // CH1 S2G+S2P测试
localparam DC_DIAG_CH2_S2GP     = 4'd3;   // CH2 S2G+S2P测试
localparam DC_DIAG_CH3_S2GP     = 4'd4;   // CH3 S2G+S2P测试
localparam DC_DIAG_CH4_S2GP     = 4'd5;   // CH4 S2G+S2P测试
localparam DC_DIAG_CH1_SLICK    = 4'd6;   // CH1 SL测试 (短路负载)
localparam DC_DIAG_CH2_SLICK    = 4'd7;   // CH2 SL测试
localparam DC_DIAG_CH3_SLICK    = 4'd8;   // CH3 SL测试
localparam DC_DIAG_CH4_SLICK    = 4'd9;   // CH4 SL测试
localparam DC_DIAG_CH1_LO       = 4'd10;  // CH1 LO测试 (线路输出)
localparam DC_DIAG_CH2_LO       = 4'd11;  // CH2 LO测试
localparam DC_DIAG_CH3_LO       = 4'd12;  // CH3 LO测试
localparam DC_DIAG_CH4_LO       = 4'd13;  // CH4 LO测试
localparam DC_DONE              = 4'd14;  // 完成
```

### 4.2 状态转换图（原始图复现）

```
   ┌──────────────────┐
   │  DC_DIAG_IDLE    │  ◄─── 启动ch_diagnostic完成时,可重新开始
   │   (空闲)         │  ◄─── 完成(从DONE回来)
   └────────┬─────────┘
            │ 启动准备好 ch_diagnostic
            ▼
   ┌──────────────────┐
   │DC_DIAG_          │  启动观察
   │OBSERVATION       │  (测量准备)
   └────────┬─────────┘
            │ ch1_en
            ▼
   ┌──────────────────┐  ch2_en
   │ CH1_S2G+S2G      │ ─────►  CH2_S2P+S2G ──── ch3_en ────►  CH3_S2P+S2G
   │ (CH1 S2G+S2P测试)│                                    (CH3 S2G+S2P测试)
   └──────────────────┘                                            │
                                                                   │ ch4_en
                                                                   ▼
                                                            ┌──────────────────┐
                                                            │ CH4_S2P+S2G      │
                                                            │ (CH4 S2G+S2P测试)│
                                                            └────────┬─────────┘
                                                                     │ ch1_ol
                                                                     ▼
                                                            ┌──────────────────┐  ch2_ol
                                                            │ CH1_SLICK        │ ──► CH2_SLICK
                                                            │ (CH1 SL测试)     │     (CH2 SL测试)
                                                            └──────────────────┘     │
                                                                                       │ ch3_ol
                                                                                       ▼
                                                                              ┌──────────────────┐
                                                                              │ CH3_SLICK        │
                                                                              │ (CH3 SL测试)     │
                                                                              └────────┬─────────┘
                                                                                       │ ch4_ol
                                                                                       ▼
                                                                              ┌──────────────────┐
                                                                              │ CH4_SLICK        │
                                                                              │ (CH4 SL测试)     │
                                                                              └────────┬─────────┘
                                                                                       │ ch1_lo
                                                                                       ▼
                                                                              ┌──────────────────┐  ch2_lo
                                                                              │ CH1_LO           │ ──► CH2_LO
                                                                              │ (CH1 LO测试)     │     (CH2 LO测试)
                                                                              └──────────────────┘     │
                                                                                                       │ ch3_lo
                                                                                                       ▼
                                                                                              ┌──────────────────┐
                                                                                              │ CH3_LO           │
                                                                                              │ (CH3 LO测试)     │
                                                                                              └────────┬─────────┘
                                                                                                       │ ch4_lo
                                                                                                       ▼
                                                                                              ┌──────────────────┐
                                                                                              │ CH4_LO           │
                                                                                              │ (CH4 LO测试)     │
                                                                                              └────────┬─────────┘
                                                                                                       │ done
                                                                                                       ▼
                                                                                              ┌──────────────────┐
                                                                                              │ DONE             │ ──► DC_DIAG_IDLE
                                                                                              └──────────────────┘
```

### 4.3 完整转换条件表

| 当前态 | 下一态 | 触发条件 | 备注 |
|--------|--------|---------|------|
| DC_DIAG_IDLE | DC_DIAG_OBSERVATION | ch_diagnostic (启动信号) | 启动诊断 |
| DC_DIAG_OBSERVATION | DC_DIAG_CH1_S2GP | ch1_en (CH1使能) | 启动CH1测试 |
| DC_DIAG_CH1_S2GP | DC_DIAG_CH2_S2GP | ch2_en | 顺序执行CH2 |
| DC_DIAG_CH2_S2GP | DC_DIAG_CH3_S2GP | ch3_en | 顺序执行CH3 |
| DC_DIAG_CH3_S2GP | DC_DIAG_CH4_S2GP | ch4_en | 顺序执行CH4 |
| DC_DIAG_CH4_S2GP | DC_DIAG_CH1_SLICK | ch1_ol (CH1 OL/SL) | 进入SL测试阶段 |
| DC_DIAG_CH1_SLICK | DC_DIAG_CH2_SLICK | ch2_ol | 顺序执行CH2 |
| DC_DIAG_CH2_SLICK | DC_DIAG_CH3_SLICK | ch3_ol | 顺序执行CH3 |
| DC_DIAG_CH3_SLICK | DC_DIAG_CH4_SLICK | ch4_ol | 顺序执行CH4 |
| DC_DIAG_CH4_SLICK | DC_DIAG_CH1_LO | ch1_lo (CH1 LO) | 进入LO测试阶段 |
| DC_DIAG_CH1_LO | DC_DIAG_CH2_LO | ch2_lo | 顺序执行CH2 |
| DC_DIAG_CH2_LO | DC_DIAG_CH3_LO | ch3_lo | 顺序执行CH3 |
| DC_DIAG_CH3_LO | DC_DIAG_CH4_LO | ch4_lo | 顺序执行CH4 |
| DC_DIAG_CH4_LO | DONE | done | 全部完成 |
| DONE | DC_DIAG_IDLE | (自动) | 1clk后返回IDLE |
| 任意状态 | DC_DIAG_IDLE | abort (0x09 bit7) | 中止诊断 |

### 4.4 关键设计注释（来自原始图）

1. **启动chN_diagnostic完成时，可重新开始**（说明IDLE可以接受新触发）
2. **自检DC_SL_G不检查短到电源的诊断**（实际SL_G包含了S2G, SL_P, S2P的诊断）
3. **可同时启动SL_G测试**（SL_G = S2G + S2P + SL 复合测试）
4. **自检OL不检查短到电源的诊断, S2P不检查SL**
5. **自动情况则SL_G/OL**（自动诊断时执行SL_G和OL测试）

### 4.5 测试项与寄存器报告映射

| 测试类型 | 测试项 | 寄存器报告位 (0x0C-0x0D) |
|---------|--------|-------------------------|
| S2G (对地短路) | S2G_CH1~4 | bit7/3 (CH1/CH2), bit7/3 (CH3/CH4) |
| S2P (对电源短路) | S2P_CH1~4 | bit6/2 (CH1/CH2), bit6/2 (CH3/CH4) |
| SL (短路负载) | SL_CH1~4 | bit4/0 (CH1/CH2), bit4/0 (CH3/CH4) |
| OL (开路) | OL_CH1~4 | bit5/1 (CH1/CH2), bit5/1 (CH3/CH4) |
| LO (线路输出) | LO_CH1~4 | 0x0E bit3~0 |

### 4.6 诊断时序

| 阶段 | 触发信号 | 持续时间 | 说明 |
|------|---------|---------|------|
| IDLE→OBSERVATION | ch_diagnostic | <1ms | 启动准备 |
| OBSERVATION→CH1 | ch1_en | 测量时间 | CH1 S2G+S2P测试 |
| CH1→CH2 | ch2_en | 测量时间 | CH2 S2G+S2P测试 |
| ... | ... | ... | 顺序执行 |
| CH4_S2GP→CH1_SLICK | ch1_ol | 测量时间 | CH1 SL测试 |
| CH1_SLICK→CH2_SLICK | ch2_ol | 测量时间 | ... |
| ... | ... | ... | ... |
| CH4_SLICK→CH1_LO | ch1_lo | 测量时间 | CH1 LO测试 |
| ... | ... | ... | ... |
| CH4_LO→DONE | done | ~230ms 总 | 完成 |
| DONE→IDLE | (自动) | 1clk | 返回空闲 |

**单通道总诊断时间**: 230ms / 4 = 57.5ms（每通道约3个测试项）

---

## 5. AC诊断状态机 — AC诊断的状态跳转图（AC诊断的状态跳转.jpg）

### 5.1 状态定义

**6个状态**，按4通道顺序诊断：

```verilog
localparam AC_DIAG_IDLE  = 3'd0;  // 空闲
localparam CH1_AC        = 3'd1;  // CH1 AC诊断
localparam CH2_AC        = 3'd2;  // CH2 AC诊断
localparam CH3_AC        = 3'd3;  // CH3 AC诊断
localparam CH4_AC        = 3'd4;  // CH4 AC诊断
localparam AC_DONE       = 3'd5;  // 完成
```

### 5.2 状态转换图（原始图复现）

```
                ┌─────────────┐
                │ AC_Diag_IDLE│ ◄──── 完成(DONE回来)
                │  (空闲)     │ ◄──── 任何状态
                └──────┬──────┘
                       │ ch1_en
                       ▼
                ┌─────────────┐
                │   CH1_AC    │
                │ (CH1 AC诊断)│
                └──────┬──────┘
                       │ ch2_en
                       ▼
                ┌─────────────┐
                │   CH2_AC    │
                │ (CH2 AC诊断)│
                └──────┬──────┘
                       │ ch3_en
                       ▼
                ┌─────────────┐
                │   CH3_AC    │
                │ (CH3 AC诊断)│
                └──────┬──────┘
                       │ ch4_en
                       ▼
                ┌─────────────┐
                │   CH4_AC    │
                │ (CH4 AC诊断)│
                └──────┬──────┘
                       │ done
                       ▼
                ┌─────────────┐
                │   DONE      │ ──► AC_Diag_IDLE
                └─────────────┘
```

### 5.3 完整转换条件表

| 当前态 | 下一态 | 触发条件 | 备注 |
|--------|--------|---------|------|
| AC_DIAG_IDLE | CH1_AC | ch1_en | CH1使能，开始AC诊断 |
| CH1_AC | CH2_AC | ch2_en | CH2使能 |
| CH2_AC | CH3_AC | ch3_en | CH3使能 |
| CH3_AC | CH4_AC | ch4_en | CH4使能 |
| CH4_AC | AC_DONE | done | 全部完成 |
| AC_DONE | AC_DIAG_IDLE | (自动) | 1clk后返回 |
| 任意 | AC_DIAG_IDLE | abort | 中止 |

### 5.4 AC诊断特点

- **顺序执行**：CH1→CH2→CH3→CH4
- **每通道独立测量**：每通道单独测量阻抗/相位
- **总时间**：~520ms (typ, datasheet)
- **单通道时间**：~130ms (typ)

---

## 6. 状态机间的交互关系

### 6.1 顶层包装 ↔ 芯片主状态机

```
TOP状态        内部激活的主状态机
─────────────────────────────────────
TOP_POWERON    (等待POR完成, 不激活主FSM)
TOP_STANDBY    (主FSM冻结, 保持原状态)
TOP_ACT        主FSM自由运行
```

### 6.2 芯片主状态机 ↔ 通道状态机

```
芯片主状态   通道状态机行为
─────────────────────────────────────
CHIP_HI_Z    所有通道必须进入CH_HIGH_Z
             (即使0x04配置PLAY/MUTE, 通道也会尝试)
CHIP_PLAY    通道可进入CH_PLAY/CH_MUTE/CH_HIGH_Z
CHIP_MUTE    通道可进入CH_PLAY/CH_MUTE/CH_HIGH_Z
CHIP_SINGLE_DIAG  通道可进入CH_SINGLE_DC_DIAG/CH_AC_DIAG/CH_HIGH_Z
CHIP_AUTO_DIAG    通道可进入CH_SINGLE_DC_DIAG/CH_AC_DIAG/CH_HIGH_Z
```

### 6.3 芯片主状态机 ↔ DC/AC诊断FSM

```
芯片主状态    DC/AC诊断FSM行为
─────────────────────────────────────
CHIP_HI_Z    DC/AC FSM保持IDLE
CHIP_PLAY    DC/AC FSM保持IDLE
CHIP_MUTE    DC/AC FSM保持IDLE
CHIP_SINGLE_DIAG  DC FSM运行 (MCU触发的单次诊断)
             AC FSM可被0x15/0x16配置触发
CHIP_AUTO_DIAG    DC FSM运行 (故障后的自动诊断)
             AC FSM可被0x15/0x16配置触发
```

### 6.4 通道状态机 ↔ DC/AC诊断FSM

```
通道状态      DC/AC FSM子状态
─────────────────────────────────────
CH_HIGH_Z          (DC/AC FSM不针对该通道)
CH_MUTE            (DC/AC FSM不针对该通道)
CH_PLAY            (DC/AC FSM不针对该通道)
CH_SINGLE_DC_DIAG  DC FSM正在诊断该通道
CH_AC_DIAG         AC FSM正在诊断该通道
```

---

## 7. 关键设计要点总结

### 7.1 状态机层级

1. **顶层 (2态)**: PowerOn/STANDBY/ACT — 控制芯片最低功耗
2. **芯片主 (5态)**: Hi-Z/Play/Mute/Single_Diag/Auto_Diag — 控制全局工作模式
3. **通道 (5态)**: High_Z/Play/Mute/Single_DC_Diag/AC_Diag — 控制每通道
4. **DC诊断 (15态)**: 4阶段 × 4通道 + IDLE/OBSERVATION/DONE
5. **AC诊断 (6态)**: 4通道顺序 + IDLE/DONE

### 7.2 关键转换优先级

1. **STANDBY_N=0**: 顶层强制回STANDBY（最高优先级）
2. **全局故障**: 主状态机强制回Hi-Z
3. **0x04配置Hi-Z**: 用户配置回Hi-Z
4. **0x04配置其他状态**: 用户配置

### 7.3 诊断触发条件

- **自动诊断触发**: 故障时芯片自动进入AUTO_DIAG
- **单次诊断触发**: 0x04配置诊断态，触发SINGLE_DIAG
- **AC诊断触发**: 0x15/0x16配置（仅从CH_HIGH_Z进入）

### 7.4 异常处理

- **DC诊断异常**: 异常通道完成DC后回到CH_HIGH_Z
- **AC诊断异常**: 异常通道完成AC后回到CH_HIGH_Z
- **诊断中止**: 0x09 bit7 (DC_LDG_ABORT) 中止DC诊断
- **全局复位**: STANDBY_N=0 强制所有FSM回Hi-Z

---

## 8. 设计检查清单

- [ ] 顶层2态FSM是否与上电时序匹配
- [ ] 芯片主状态机是否覆盖正常态+故障态
- [ ] 通道状态机是否5态完整
- [ ] 通道CH_AC_DIAG是否仅从CH_HIGH_Z进入
- [ ] DC诊断FSM是否15态顺序正确
- [ ] DC诊断的S2GP/SLICK/LO三个阶段是否正确
- [ ] AC诊断FSM是否6态顺序正确
- [ ] 各FSM的abort机制是否正确
- [ ] STANDBY_N=0的全局强制是否覆盖所有FSM
- [ ] 主FSM与通道FSM的协作关系是否清晰
