# TAS6424E-Q1 时钟与复位设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-14  
> **状态**: 待审核  
> **关联文档**: `architecture_design_v2.md` (架构总览)

---

## 1. 时钟架构总览

### 1.1 时钟源

器件接受来自外部SoC/DSP的4个时钟信号：

| 时钟信号 | 引脚 | 频率范围 | 描述 |
|---------|------|---------|------|
| clk (系统主时钟) | — (内部生成) | 10MHz (典型) | RTL仿真/综合用主时钟，不是datasheet引脚 |
| MCLK | pin 12 | 128/256/512 × fs, max 25MHz | 音频主时钟 |
| SCLK (BCLK) | pin 13 | 32/64/128/256 × fs | 音频位时钟 / 串行时钟 |
| FSYNC (LRCLK) | pin 14 | 44.1/48/96 kHz | 帧同步时钟 |

> **注意**: 在实际芯片中，所有数字逻辑由内部时钟驱动（由MCLK经PLL生成）。  
> 在本RTL模型中，为简化设计，使用独立的10MHz主时钟 `clk` 运行所有数字逻辑，  
> MCLK/SCLK/FSYNC仅作为输入采样和时钟监控的观测信号。

### 1.2 时钟域划分

```
┌────────────────────────────────────────────────────────────────┐
│                        时钟域架构图                            │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐     │
│  │                 clk 域 (10MHz)                         │     │
│  │                                                        │     │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────────┐         │     │
│  │  │i2c_slave│  │register  │  │state_machine │         │     │
│  │  │         │  │  _file   │  │              │         │     │
│  │  └─────────┘  └──────────┘  └──────────────┘         │     │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────────┐         │     │
│  │  │channel  │  │pwm_gen   │  │diagnostic    │         │     │
│  │  │  _fsm×4 │  │          │  │   _ctrl      │         │     │
│  │  └─────────┘  └──────────┘  └──────────────┘         │     │
│  │  ┌─────────┐  ┌──────────┐  ┌──────────────┐         │     │
│  │  │fault    │  │pin_ctrl  │  │clock_monitor │         │     │
│  │  │_monitor │  │          │  │              │         │     │
│  │  └─────────┘  └──────────┘  └──────────────┘         │     │
│  │  ┌─────────┐                                          │     │
│  │  │protection│                                         │     │
│  │  └─────────┘                                          │     │
│  └──────────────────────────────────────────────────────┘     │
│         ▲              ▲              ▲              ▲         │
│         │ 同步器        │ 同步器        │ 同步器        │        │
│    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐   │
│    │ SCL/SDA │    │  MCLK   │    │  SCLK   │    │ FSYNC   │   │
│    │ 同步器  │    │  同步器 │    │  同步器 │    │  同步器 │   │
│    └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘   │
│         │              │              │              │         │
│    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐    ┌────┴────┐   │
│    │  I2C    │    │ 音频主  │    │ 音频位  │    │  帧同步  │   │
│    │ 时钟域  │    │ 时钟域  │    │ 时钟域  │    │  时钟域  │   │
│    └─────────┘    └─────────┘    └─────────┘    └─────────┘   │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. 跨时钟域同步 (CDC) 设计

### 2.1 两级DFF同步器（标准方案）

所有异步输入信号均通过2级DFF同步器进入clk域。

```verilog
// 标准2级DFF同步器模块 (可复用)
module cdc_sync_2dff (
    input  wire clk,        // 目标时钟
    input  wire rst_n,      // 异步复位 (低有效)
    input  wire sig_async,  // 异步输入信号
    output wire sig_sync    // 同步后输出 (clk域)
);
    reg sync_ff1, sync_ff2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= sig_async;
            sync_ff2 <= sync_ff1;
        end
    end
    
    assign sig_sync = sync_ff2;
endmodule
```

### 2.2 边沿检测器

在2级DFF同步器之后，添加边沿检测器以捕获上升/下降沿脉冲。

```verilog
// 边沿检测器 (上升沿/下降沿/任意边沿)
module edge_detector (
    input  wire clk,
    input  wire rst_n,
    input  wire sig_sync,       // 已同步的信号
    output wire pos_edge_pulse, // 上升沿脉冲 (1clk宽)
    output wire neg_edge_pulse  // 下降沿脉冲 (1clk宽)
);
    reg sig_d1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sig_d1 <= 1'b0;
        else
            sig_d1 <= sig_sync;
    end
    
    assign pos_edge_pulse = sig_sync && !sig_d1;  // 上升沿检测
    assign neg_edge_pulse = !sig_sync && sig_d1;  // 下降沿检测
endmodule
```

### 2.3 各引脚CDC实现规格

| 信号 | 同步器类型 | MTBF考虑 | 附加处理 |
|------|-----------|---------|---------|
| `scl_i` (I2C SCL) | 2-DFF + 边沿检测 | ≥1us稳定 → MTBF远大于产品寿命 | pos/neg边沿脉冲驱动I2C FSM |
| `sda_i` (I2C SDA) | 2-DFF | 同上 | START/STOP条件检测使用sda_sync和scl_sync |
| `mclk_i` | 2-DFF | 2 clk周期(200ns) << MCLK周期(>40ns) | 时钟监控计数使用mclk_sync |
| `sclk_i` | 2-DFF + 边沿检测 | 同步器延迟远小于SCLK周期 | sclk_falling脉冲用于采样SDIN |
| `fsync_i` | 2-DFF + 边沿检测 | FSYNC周期远大于clk周期 | fsync_rising脉冲用于数据锁存 |
| `sd_in1_i` / `sd_in2_i` | 2-DFF | — | 与sclk_falling同步采样 |
| `standby_n_i` | 去抖动 + 2-DFF | — | 去抖后同步 |
| `mute_n_i` | 去抖动 + 2-DFF | — | 去抖后同步 |
| 模拟前端故障信号 | protection模块内多重周期确认 | — | 参见§2.5去毛刺设计 |

### 2.4 音频时钟同步详解

音频接口的时钟同步是设计中最为关键的CDC路径。

```
SCLK (异步) ──► [DFF1] ──► [DFF2] ──► sclk_sync ──► [边沿检测] ──► sclk_pos/neg_pulse
                                                    │
SDIN (异步) ──► [DFF1] ──► [DFF2] ──► sdin_sync ────┼──► 在sclk_neg_pulse时采样
                                                    │
MCLK (异步) ──► [DFF1] ──► [DFF2] ──► mclk_sync ────┤ (仅用于时钟监控)
                                                    │
FSYNC(异步) ──► [DFF1] ──► [DFF2] ──► fsync_sync ──► [边沿检测] ──► fsync_pos_pulse (帧锁存)
```

**采样策略**：
- SDIN数据在`sclk_sync`的**下降沿**（即`neg_edge_pulse`有效时）采样
- 这是因为在I2S模式下，数据在SCLK上升沿改变，在下降沿稳定
- 同步器引入的2周期延迟确保数据在采样时已经稳定

### 2.5 去毛刺设计

对于低频切换的故障信号（OTW/OTSD/UV/OV），使用去毛刺滤波器：

```
模拟前端信号 ──► [去毛刺计数器] ──► 确认后的信号
                    │
                    │ 信号需连续稳定 = FAULT_DEGLITCH_CYCLES 个clk周期
                    │ 如果信号在计数完成前翻转，计数器复位
                    │
                    └── 参数: FAULT_DEGLITCH_CYCLES = 100 (10us @10MHz)
```

---

## 3. 时钟监控设计

### 3.1 监控目标

时钟监控器检测以下条件：

| 监控对象 | 超时条件 | 动作 |
|---------|---------|------|
| MCLK活动 | 在CLK_TIMEOUT_CYCLES内无MCLK翻转 | `clock_lost=1` → fault_monitor → Hi-Z |
| SCLK活动 | 在CLK_TIMEOUT_CYCLES内无SCLK翻转 | `clock_lost=1` → fault_monitor → Hi-Z |
| FSYNC活动 | 在CLK_TIMEOUT_CYCLES内无FSYNC翻转 | `clock_lost=1` → fault_monitor → Hi-Z |

> 注：datasheet §9.3.1.6 描述时钟错误时所有通道自动进入Hi-Z，时钟恢复后自动返回原状态。

### 3.2 监控实现方式

```
          ┌────────────────────────────────────┐
mclk_sync │  ┌───────────┐                     │
──────────┼─►│ mclk活动    │                    │
          │  │ 检测计数器 │── mclk_ok ──┐       │
          │  └───────────┘              │       │
          │                      ┌──────▼──────┐│
sclk_sync │  ┌───────────┐       │             ││
──────────┼─►│ sclk活动    │──────►│ clock_lost  ├── clock_lost
          │  │ 检测计数器 │       │  生成逻辑   ││
          │  └───────────┘       │             ││
          │                      └──────▲──────┘│
fsync_sync│  ┌───────────┐              │       │
──────────┼─►│ fsync活动   │── fsync_ok ─┘       │
          │  │ 检测计数器 │                     │
          │  └───────────┘                     │
          └────────────────────────────────────┘
```

每个活动检测计数器：
- 在检测到时钟翻转时清零
- 在无翻转时递增
- 达到CLK_TIMEOUT_CYCLES时置位超时标志
- 时钟恢复后自动清零超时标志

### 3.3 时钟监控使能控制

```verilog
// 仅在非STANDBY状态下监控时钟
assign clock_mon_en = (chip_state != CHIP_STANDBY);
```

---

## 4. 复位架构设计

### 4.1 复位源层级

```
                        ┌──────────────────────────────────┐
                        │         rst_n (外部引脚)          │
                        │   异步复位，同步释放              │
                        └──────────────┬───────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
         ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
         │ POR (VDD)    │   │ soft_reset   │   │ clear_fault  │
         │ 0x13 bit5    │   │ 0x00 bit7    │   │ 0x21 bit7    │
         │ 上电复位      │   │ 软件复位      │   │ 清除故障      │
         └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
                │                  │                  │
                ▼                  ▼                  ▼
         ┌──────────────────────────────────────────────────┐
         │              复位作用域                           │
         │                                                  │
         │ rst_n / POR / soft_reset:                        │
         │   → 所有寄存器恢复默认值                          │
         │   → 状态机回到IDLE/Hi-Z                          │
         │   → 计数器归零                                   │
         │   → PWM输出禁止                                  │
         │                                                  │
         │ clear_fault:                                     │
         │   → 故障锁存器清零                               │
         │   → FAULT/WARN引脚释放                           │
         │   → OTSD恢复冷却计数器启动                       │
         │   → 不改变配置寄存器                             │
         └──────────────────────────────────────────────────┘
```

### 4.2 异步复位同步释放电路

```verilog
// 异步复位同步释放模块
module reset_sync (
    input  wire clk,
    input  wire rst_n_async,     // 异步复位输入 (低有效)
    output wire rst_n_sync       // 同步释放复位输出 (低有效)
);
    reg rst_ff1, rst_ff2;
    
    always @(posedge clk or negedge rst_n_async) begin
        if (!rst_n_async) begin
            rst_ff1 <= 1'b0;
            rst_ff2 <= 1'b0;
        end else begin
            rst_ff1 <= 1'b1;         // 异步置位
            rst_ff2 <= rst_ff1;       // 同步释放
        end
    end
    
    assign rst_n_sync = rst_ff2;
endmodule
```

**特性**：
- 复位断言 (rst_n_async=0) 时，rst_n_sync立即异步变低
- 复位释放 (rst_n_async=1) 时，rst_n_sync在2个clk周期后同步变高
- 保证所有触发器在同一clk沿解除复位，避免亚稳态

### 4.3 各模块复位值总表

| 信号/寄存器 | 复位值 | 描述 |
|------------|--------|------|
| chip_state | CHIP_STANDBY (3'd0) | 主状态机初始化 |
| ch_state (per ch) | CH_HI_Z (2'b01) | 通道状态初始化 |
| 所有R/W寄存器 | 各自的默认值 | 参见register_map_design.md |
| 所有R寄存器 | 0x00 | 状态寄存器清空 |
| pwm_carrier | 0 | 载波计数器归零 |
| audio_data | 24'd0 | 音频数据清零 |
| 所有故障锁存 | 0 | 故障清除 |
| fault_n输出 | 1 (不拉低) | 开漏输出高阻 (外加上拉) |
| warn_n输出 | 1 (不拉低) | 开漏输出高阻 (外加上拉) |

### 4.4 上电时序 (datasheet §9.3.10.1)

```
                   ┌─────────────────────────────────────────────────────┐
                   │                上电时序图                            │
                   │                                                     │
VBAT/PVDD ────────┐                                                     │
                   │                                                     │
                   ├─────────────────────────────────────────────────────│
                   │                                                     │
VDD ───────────────┼────┐                                                │
                   │    │                                                │
                   │    │  tSTART (max 12ms)                             │
                   │    │                                                │
I2C 就绪 ──────────┼────┼────┐                                          │
                   │    │    │                                          │
                   │    │    │  STANDBY=0 → 芯片处于STANDBY             │
                   │    │    │                                          │
STANDBY=1 ─────────┼────┼────┼────┐                                     │
                   │    │    │    │                                      │
                   │    │    │    │  I2C可通信                           │
                   │    │    │    │                                      │
                   └────┴────┴────┴─────────────────────────────────────│
```

**关键约束**：
1. VBAT/PVDD应先于VDD上电（或同时）
2. VDD上电后，I2C在最多12ms内就绪
3. STANDBY=0期间，芯片处于低功耗待机，电流<1μA (PVDD), <6μA (VBAT)
4. STANDBY释放(=1)后，芯片进入Hi-Z状态

### 4.5 下电时序 (datasheet §9.3.10.2)

```
STANDBY ───────────┐
                    │ 拉低
                    │
                    ├──── (至少15ms) ────┐
                    │                    │
                    │                    │ 15ms后可以移除电源
                    │                    │
PVDD/VBAT/VDD ─────┼────────────────────┼──── (移除)
                    │                    │
                    └────────────────────┘
```

---

## 5. 功耗管理相关时钟控制

### 5.1 低功耗STANDBY模式

| 模块 | STANDBY态行为 | 功耗节省方式 |
|------|-------------|-------------|
| pwm_generator | 载波计数器停止 | 消除2.1MHz翻转功耗 |
| audio_interface | 移位寄存器停止 | 消除SCLK频率翻转 |
| clock_monitor | 监控暂停（所有时钟OK标志保持） | 减少计数器翻转 |
| diagnostic_ctrl | FSM暂停在IDLE | 减少状态翻转 |
| i2c_slave | 保持活动（响应I2C命令唤醒） | — |
| register_file | 保持活动（维持寄存器值） | — |

### 5.2 Hi-Z态时钟控制

| 模块 | Hi-Z态行为 |
|------|-----------|
| pwm_generator | 载波运行但输出强制为0 (Hi-Z) |
| audio_interface | 正常运行（接收数据但不转发） |
| clock_monitor | 正常运行 |

---

## 6. 参数配置

### 6.1 全局时钟参数

```verilog
// 时钟频率参数
parameter CLK_FREQ               = 10_000_000;   // 系统主时钟: 10MHz
parameter CLK_PERIOD_NS          = 100;           // 主时钟周期: 100ns

// I2C时序参数
parameter I2C_FS_SCL_FREQ        = 400_000;      // Fast-mode SCL: 400kHz
parameter I2C_SS_SCL_FREQ        = 100_000;      // Standard-mode SCL: 100kHz

// 音频时钟参数
parameter MCLK_MAX_FREQ          = 25_000_000;   // MCLK最大频率: 25MHz
parameter FS_TYPICAL             = 48_000;        // 典型采样率: 48kHz
```

### 6.2 CDC相关参数

```verilog
// 同步器级数
parameter CDC_SYNC_STAGES        = 2;             // 2级DFF同步器

// 去抖动/去毛刺参数
parameter DEBOUNCE_CYCLES        = 500;           // STANDBY/MUTE: 50us@10MHz
parameter FAULT_DEGLITCH_CYCLES  = 100;           // 故障去毛刺: 10us@10MHz

// 超时参数
parameter CLK_TIMEOUT_CYCLES     = 24'hFFFFF;     // 时钟丢失: ~100ms@10MHz
parameter OTSD_RECOVERY_CYCLES   = 32'hFFFFFF;    // OTSD恢复: ~16s@10MHz
```

---

## 7. 设计检查清单

- [ ] 所有异步输入信号是否都有2级DFF同步器
- [ ] 边沿检测是否正确生成单周期脉冲
- [ ] 异步复位同步释放电路是否正确实现
- [ ] 各模块复位值是否与datasheet默认值一致
- [ ] 时钟监控器超时后是否正确触发clock_lost
- [ ] 上电时序约束是否在testbench中验证
- [ ] 去毛刺周期是否与datasheet电气特性一致
- [ ] STANDBY模式下的时钟门控是否正确
- [ ] I2C SCL频率是否兼容100kHz和400kHz
