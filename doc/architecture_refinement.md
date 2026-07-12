# TAS6424E-Q1 架构优化方案（基于datasheet重新思考）

> **版本**: v2.0.0  
> **日期**: 2026-07-11  
> **状态**: 待审核  
> **类型**: 纯架构分析与优化方案，不涉及代码生成  
> **前置文档**: `architecture_analysis.md`（v1架构分析）

---

## 0. 文档目的

本文档基于**重新精读datasheet 9.3-9.4节**后的新发现，对当前RTL架构提出**优化和细化方案**。

与v1架构分析文档的差异：
- v1文档中"STANDBY态I2C关闭"的结论**有误**（datasheet表9-5明确STANDBY态I2C=Active）
- v1文档未涵盖ramp机制、HPF、音量增益ramp等datasheet明确描述的功能
- 本文档补充**10项新发现**，提出**架构优化矩阵**

---

## 1. datasheet精读后的10项新发现

### 发现1：STANDBY态I2C是Active（纠正v1文档错误）

**datasheet表9-5原文**：

| STATE | OUTPUT FETS | OSCILLATOR | I2C |
|-------|------------|-----------|-----|
| STANDBY | Hi-Z | Stopped | **Active** |
| Hi-Z | Hi-Z | Active | Active |
| MUTE | Switching at 50% | Active | Active |
| PLAY | Switching with audio | Active | Active |

**结论**：STANDBY态I2C**保持活跃**，MCU可在待机态读写寄存器。  
**v1文档错误**：architecture_analysis.md第3.1节称"STANDBY态I2C关闭"——**需要更正**。

**影响**：当前RTL实现（STANDBY态I2C仍可访问）**是正确的**，无需修改。

---

### 发现2：时钟错误自动恢复（无需CLEAR_FAULT）

**datasheet 9.3.1.6原文**：
> "When any kind of clock error... is detected, the device puts all channels into the Hi-Z state. **When all audio clocks are within the expected range, the device automatically returns to the state it was in.**"

**结论**：时钟错误是**唯一**不需要CLEAR_FAULT即可自动恢复的故障。时钟恢复后芯片自动回到原状态。

**当前RTL**：clock_lost → global_fault_irq → 进HI_Z → 需CLEAR_FAULT才能恢复。  
**差异**：当前实现**不符合datasheet**，时钟恢复后应自动回到PLAY/MUTE。

**优化**：clock_monitor输出`clock_recovered`信号，state_machine检测后自动恢复到故障前状态。

---

### 发现3：DC诊断自动触发（三种触发场景）

**datasheet 9.3.8原文**：
> "The DC diagnostics **runs when any channel is directed to leave the Hi-Z state and enter the MUTE or PLAY state**. The DC diagnostics can also be enabled manually."

**三种DC诊断触发场景**：

| 场景 | 触发条件 | datasheet描述 |
|------|---------|--------------|
| ① 状态转换诊断 | 0x04从Hi-Z改MUTE/PLAY | "runs when any channel is directed to leave Hi-Z" |
| ② 手动诊断 | 0x04=DC_DIAG(11) | "can also be enabled manually" |
| ③ 故障恢复诊断 | OC故障CLEAR_FAULT后 | "automatically starts diagnostics on the channel" |

**当前RTL**：仅实现场景②（手动诊断）。  
**缺失**：场景①和③未实现。

**优化**：
- 场景①：state_machine在`HI_Z→MUTE/PLAY`转换前插入`DIAG_PENDING`子状态
- 场景③：channel_fsm在CLEAR_FAULT后自动请求诊断

---

### 发现4：ramp down/up机制（防止pop/click噪声）

**datasheet多处描述**：

| 位置 | 原文 | 场景 |
|------|------|------|
| 9.3.8 | "the device must **ramp down** the audio signal of that channel before transitioning to the Hi-Z state" | PLAY→诊断前 |
| 9.3.8.3.1 | "The device **ramps the signal up and down automatically** to prevent pops and clicks" | AC诊断 |
| 9.3.11.4 | "The outputs are **ramped down in less than 5 ms** if the device is not already in the Hi-Z state" | STANDBY引脚 |
| 9.3.3 | "The gain-ramp rate is programmable... **one step every 1, 2, 4, or 8 FSYNC cycles**" | 音量变化 |

**结论**：芯片有多级ramp机制：
1. 音量增益ramp（0x01寄存器配置速率）
2. 状态转换ramp（PLAY→Hi-Z前ramp down音频）
3. STANDBY ramp（5ms内ramp down）

**当前RTL**：无任何ramp机制。  
**优化**：在audio_interface和pwm_generator之间增加`ramp_ctrl`模块。

---

### 发现5：通道级OTSD（每通道独立过温关断）

**datasheet 9.3.9.6原文**：
> "Each output channel also has an individual overtemperature warning and shutdown. If the channel temperature exceeds the OTSD(i) threshold then **the channel goes to the Hi-Z state** and either remains there or auto-recovers."

**结论**：
- 不仅有全局OTSD（0x12 bit4），还有**每通道OTSD**（0x12 bit3-0）
- 通道级OTSD可自动恢复（0x21 bit3=1时）
- 通道级OTSD仅影响对应通道，不是全局故障

**当前RTL**：
- `protection.v`仅有全局OTSD输入`otsd_raw`
- `fault_monitor.v`的0x12寄存器定义了CH1-4 OTSD位，但**无通道级OTSD输入信号**

**优化**：增加`otsd_ch1~4_raw`输入信号，通道级OTSD作为通道故障（非全局故障）。

---

### 发现6：HPF直流阻断滤波器（0x26寄存器控制）

**datasheet 9.3.2原文**：
> "The data path has a high-pass filter to remove any DC from the input signal. The corner frequency is selectable from **4 Hz, 8 Hz, 15 Hz, or 30 Hz** with bits 0 through 3 in Miscellaneous Control 4 Register (address = 0x26)."

**结论**：音频数据通路上有HPF，由0x26寄存器bit0-3配置截止频率。

**当前RTL**：`reg_misc_ctrl4`已从register_file输出，但audio_interface未使用。  
**优化**：在audio_interface中增加HPF滤波器（一阶IIR）。

---

### 发现7：音量控制与增益ramp（0x05-0x08 + 0x01）

**datasheet 9.3.3原文**：
> "Each channel has an independent digital-volume control with a range from **–100 dB to +24 dB** with **0.5-dB steps**. The gain-ramp rate is programmable through I2C to take **one step every 1, 2, 4, or 8 FSYNC cycles**."

> "The peak output-voltage swing is also configurable... The four gain settings are **7.5 V, 15 V, 21 V, and 29 V**."

**结论**：
- 4通道独立音量控制（0x05-0x08），范围-100~+24dB，0.5dB步进
- 增益ramp速率可配（0x01寄存器bit3-2：1/2/4/8 FSYNC周期一步）
- 输出电压幅度可配（0x01寄存器bit1-0：7.5/15/21/29V）

**当前RTL**：音量寄存器已输出但pwm_generator未使用。  
**优化**：在PWM比较前增加音量衰减乘法器+增益ramp逻辑。

---

### 发现8：0x14寄存器故障屏蔽位（7个屏蔽位）

**datasheet 9.6.18表9-27原文**：

| Bit | Field | 屏蔽对象 | 目标引脚 |
|-----|-------|---------|---------|
| 7 | MASK OC | 过流故障 | FAULT |
| 6 | MASK OTSD | 过温关断 | FAULT |
| 5 | MASK UV | 欠压 | FAULT |
| 4 | MASK OV | 过压 | FAULT |
| 3 | MASK DC | 直流检测 | FAULT |
| 2 | RESERVED | - | - |
| 1 | MASK CLIP | 削波 | WARN |
| 0 | MASK OTW | 过温警告 | WARN |

**结论**：0x14寄存器可按故障类别屏蔽FAULT/WARN引脚输出（不影响寄存器报告）。

**当前RTL**：`reg_pin_ctrl`已输出到pin_control，但pin_control的FAULT/WARN逻辑未使用屏蔽位。  
**优化**：pin_control按0x14寄存器位分别屏蔽各类故障。

---

### 发现9：0x21寄存器完整位定义（4个功能位）

**datasheet 9.6.26表9-35原文**：

| Bit | Field | 功能 |
|-----|-------|------|
| 7 | CLEAR FAULT | 清除故障锁存 |
| 6 | PBTL_CH_SEL | PBTL信号源翻转 |
| 5 | MASK ILIMIT WARNING | 屏蔽限流警告到WARN引脚 |
| 3 | OTSD AUTO RECOVERY | OTSD自动恢复使能 |

**当前RTL**：仅使用了bit7(CLEAR_FAULT)和bit3(OTSD_AUTO_RCV)。  
**缺失**：bit6(PBTL_CH_SEL)和bit5(MASK_ILIMIT)未使用。

**优化**：register_file增加`pbtl_ch_sel`和`mask_ilimit_warning`输出。

---

### 发现10：I2C地址精确值（表9-8）

**datasheet表9-8原文**：

| Device | ADDR1 | ADDR0 | I2C Write | I2C Read |
|--------|-------|-------|-----------|----------|
| 0 | 0 | 0 | **0xD4** | **0xD5** |
| 1 | 0 | 1 | **0xD6** | **0xD7** |
| 2 | 1 | 0 | **0xD8** | **0xD9** |
| 3 | 1 | 1 | **0xDA** | **0xDB** |

**结论**：7位地址为0x6A/0x6B/0x6C/0x6D（写地址右移1位 = 0x6A~0x6D）。

**当前RTL**：`` `define I2C_BASE_ADDR 7'b1101010 ``（0x6A），基地址正确。  
**需确认**：i2c_slave.v中`{i2c_addr1, i2c_addr0}`如何叠加到基地址——应为`base_addr + {addr1,addr0}`。

---

## 2. 架构优化矩阵

### 2.1 优化项总览

| ID | 优化项 | 优先级 | 影响模块 | datasheet依据 | 工作量 |
|----|--------|--------|---------|--------------|--------|
| OPT-01 | 时钟错误自动恢复 | P0 | state_machine, clock_monitor | 9.3.1.6 | 中 |
| OPT-02 | DC诊断自动触发（场景①③） | P0 | state_machine, channel_fsm, diagnostic_ctrl | 9.3.8 | 大 |
| OPT-03 | ramp down/up机制 | P0 | 新增ramp_ctrl模块 | 9.3.8/9.3.11.4 | 大 |
| OPT-04 | 通道级OTSD | P1 | protection, fault_monitor | 9.3.9.6 | 中 |
| OPT-05 | HPF直流阻断 | P1 | audio_interface | 9.3.2 | 中 |
| OPT-06 | 音量控制+增益ramp | P1 | 新增volume_ctrl模块 | 9.3.3 | 中 |
| OPT-07 | 0x14故障屏蔽位 | P1 | pin_control | 9.6.18 | 小 |
| OPT-08 | 0x21完整位定义 | P2 | register_file | 9.6.26 | 小 |
| OPT-09 | 状态转换优先级修正 | P1 | state_machine | 9.4.1 | 小 |
| OPT-10 | OC故障hiccup模式 | P2 | channel_fsm, diagnostic_ctrl | 9.3.9.2 | 中 |

### 2.2 优化详细方案

#### OPT-01：时钟错误自动恢复

**当前行为**：
```
clock_lost → global_fault_irq → HI_Z → [需CLEAR_FAULT] → 恢复
```

**优化后行为**：
```
clock_lost → global_fault_irq → HI_Z（记录故障前状态）
                                    │
                 时钟恢复            │
                    ▼                │
              clock_recovered ──────►│
                                    ▼
                         自动回到故障前状态(PLAY/MUTE)
```

**实现要点**：
- `clock_monitor`新增`clock_recovered`输出
- `state_machine`新增`pre_fault_state`寄存器，记录故障前状态
- 时钟恢复时：`state_next = pre_fault_state`（仅当无其他故障时）

---

#### OPT-02：DC诊断自动触发

**三种触发场景的实现**：

```
场景①：状态转换诊断
  HI_Z ──(0x04=PLAY/MUTE)──► DIAG_PENDING ──(diag_done)──► PLAY/MUTE
                                │
                                │ (诊断失败)
                                ▼
                              HI_Z

场景②：手动诊断（当前已实现）
  HI_Z ──(0x04=DC_DIAG)──► DIAG ──(diag_done)──► HI_Z

场景③：故障恢复诊断
  CH_HI_Z(故障锁存) ──(CLEAR_FAULT)──► DIAG_PENDING ──(diag_done)──► CH_PLAY/CH_MUTE
                                         │
                                         │ (诊断失败)
                                         ▼
                                    CH_HI_Z (1秒后重试)
```

**实现要点**：
- `state_machine`新增`DIAG_PENDING`子状态（不是独立的chip_state，而是转换中间态）
- `channel_fsm`在CLEAR_FAULT后自动请求诊断
- `diagnostic_ctrl`支持"快速诊断"（场景①）和"完整诊断"（场景②③）

---

#### OPT-03：ramp down/up机制

**新增模块：`ramp_ctrl`**

```
audio_interface ──► ramp_ctrl ──► pwm_generator
                      │
                      │ 控制信号：
                      │ - ramp_down_req（来自state_machine）
                      │ - ramp_down_done（到state_machine）
                      │ - vol_ramp_rate（来自0x01寄存器）
                      │ - fsync（用于ramp速率计数）
```

**ramp_ctrl功能**：
1. 音量增益ramp：每次音量寄存器变化时，按vol_ramp_rate逐步过渡
2. 状态转换ramp：PLAY→Hi-Z前，音频数据从当前值ramp到0（防止pop噪声）
3. STANDBY ramp：STANDBY引脚拉低后，5ms内ramp到0

**ramp算法**：
```
if (ramp_down_req) begin
    if (audio_data > 0)
        audio_data_ramped <= audio_data - STEP;  // 逐步减小
    else if (audio_data < 0)
        audio_data_ramped <= audio_data + STEP;
    else
        ramp_down_done <= 1;  // ramp完成
end
```

---

#### OPT-04：通道级OTSD

**当前protection接口**：
```verilog
input wire otsd_raw;  // 仅全局OTSD
```

**优化后protection接口**：
```verilog
input wire otsd_raw;        // 全局OTSD
input wire otsd_ch1_raw;    // 通道1 OTSD
input wire otsd_ch2_raw;    // 通道2 OTSD
input wire otsd_ch3_raw;    // 通道3 OTSD
input wire otsd_ch4_raw;    // 通道4 OTSD
```

**故障分类**：
- 全局OTSD → global_fault_irq → 全局HI_Z
- 通道OTSD → chN_fault → 仅对应通道HI_Z（可自动恢复）

---

#### OPT-05：HPF直流阻断

**在audio_interface中增加一阶IIR HPF**：

```
HPF方程：y[n] = α × (y[n-1] + x[n] - x[n-1])
α = RC / (RC + dt)
RC = 1 / (2π × fc)
fc = 4Hz/8Hz/15Hz/30Hz（由0x26寄存器bit0-3选择）
```

**实现要点**：
- 24位音频数据通路
- 4个截止频率选项（4/8/15/30Hz）
- HPF在audio_interface输出前应用

---

#### OPT-06：音量控制+增益ramp

**新增模块：`volume_ctrl`**

```
audio_interface ──► volume_ctrl ──► pwm_generator
                      │
                      │ 输入：
                      │ - audio_data_ch1~4
                      │ - ch1~4_vol（0x05-0x08，-100~+24dB）
                      │ - vol_ramp_rate（0x01 bit3-2）
                      │ - gain_setting（0x01 bit1-0，7.5/15/21/29V）
                      │ - fsync（ramp速率基准）
```

**音量计算**：
```
dB = (vol_reg - 200) × 0.5    // 0x00=-100dB, 0xC8=0dB, 0xFF=+27.5dB
gain = 10^(dB/20)
audio_out = audio_in × gain × voltage_scale
```

**增益ramp**：
- 音量寄存器变化时，不立即跳变
- 按1/2/4/8 FSYNC周期一步，逐步过渡到目标值

---

#### OPT-07：0x14故障屏蔽位

**pin_control优化**：

```verilog
// 当前实现
always @(*) begin
    if (global_fault_irq || any_ch_fault)
        fault_n = 1'b0;
end

// 优化后
always @(*) begin
    fault_n = 1'b1;  // 默认释放
    if (global_fault_irq) begin
        // 按类别屏蔽
        if (otw_fault && !pin_ctrl_reg[0]) fault_n = 1'b0;  // MASK OTW
        if (clip_fault && !pin_ctrl_reg[1]) warn_n = 1'b0;  // MASK CLIP
        if (dc_fault && !pin_ctrl_reg[3]) fault_n = 1'b0;   // MASK DC
        if (ov_fault && !pin_ctrl_reg[4]) fault_n = 1'b0;   // MASK OV
        if (uv_fault && !pin_ctrl_reg[5]) fault_n = 1'b0;   // MASK UV
        if (otsd_fault && !pin_ctrl_reg[6]) fault_n = 1'b0; // MASK OTSD
        if (oc_fault && !pin_ctrl_reg[7]) fault_n = 1'b0;   // MASK OC
    end
end
```

---

#### OPT-08：0x21完整位定义

**register_file新增输出**：

```verilog
output wire pbtl_ch_sel,           // 0x21 bit6
output wire mask_ilimit_warning    // 0x21 bit5
```

---

#### OPT-09：状态转换优先级修正

**当前优先级**：
```
1. global_fault → HI_Z
2. !standby_n → STANDBY
3. any_ch_diag → DIAG
4. any_ch_play → PLAY
5. any_ch_mute → MUTE
```

**优化后优先级**（standby_n最高）：
```
1. !standby_n → STANDBY（强制待机，最高优先级）
2. global_fault → HI_Z（故障处理）
3. clock_recovered → 恢复故障前状态（时钟恢复自动恢复）
4. any_ch_diag → DIAG
5. any_ch_play → PLAY
6. any_ch_mute → MUTE
```

---

#### OPT-10：OC故障hiccup模式

**datasheet 9.3.9.2原文**：
> "After clearing this bit and if the diagnostics are enabled, the device **automatically starts diagnostics** on the channel and, if no load failure is found, the device restarts. If a load fault is found the device **continues to rerun the diagnostics once per second**."

**hiccup模式实现**：

```
CH_PLAY ──(OC)──► CH_HI_Z(故障锁存)
                        │
                        │ CLEAR_FAULT
                        ▼
                   自动诊断(diag_pending)
                        │
                   ┌────┴────┐
                   │         │
                无故障    有故障
                   │         │
                   │    1秒定时器
                   │         │
                   ▼         ▼
                CH_PLAY   重试诊断
```

**实现要点**：
- `channel_fsm`新增`HICCUP_WAIT`状态（1秒定时器）
- `diagnostic_ctrl`支持"故障恢复诊断"模式
- 诊断通过 → 恢复PLAY；诊断失败 → 1秒后重试

---

## 3. 优化后的架构总览

### 3.1 新增模块

| 模块 | 功能 | 依赖 |
|------|------|------|
| `ramp_ctrl` | 音频ramp down/up + 音量增益ramp | audio_interface, pwm_generator |
| `volume_ctrl` | 4通道音量控制 + 增益ramp | audio_interface, pwm_generator |

> 注：ramp_ctrl和volume_ctrl可合并为`audio_processing`模块

### 3.2 修改的模块

| 模块 | 修改内容 |
|------|---------|
| `state_machine` | 新增DIAG_PENDING子状态、时钟自动恢复、优先级调整 |
| `channel_fsm` | 新增hiccup模式、自动诊断请求 |
| `clock_monitor` | 新增clock_recovered输出 |
| `diagnostic_ctrl` | 支持三种诊断触发场景 |
| `protection` | 新增通道级OTSD输入 |
| `fault_monitor` | 通道级OTSD故障分类 |
| `pin_control` | 0x14寄存器故障屏蔽位实现 |
| `register_file` | 0x21新增pbtl_ch_sel/mask_ilimit输出 |
| `audio_interface` | 增加HPF滤波器 |
| `tas6424e_top` | 新增ramp_ctrl/volume_ctrl模块例化、通道级OTSD信号 |

### 3.3 优化后数据流

```
控制流：
  I2C → register_file → state_machine（含DIAG_PENDING子状态）
                       → channel_fsm（含hiccup模式）
                       → volume_ctrl（音量+增益ramp）

音频流：
  SDIN → audio_interface → [HPF] → volume_ctrl → [ramp] → pwm_generator → OUT
                                              ↑
                                   ramp_down_req（来自state_machine）

故障流：
  模拟前端 → protection（含通道级OTSD）→ fault_monitor → register_file + state_machine
  clock_monitor → clock_lost + clock_recovered → state_machine（自动恢复）

诊断流：
  state_machine → DIAG_PENDING → diagnostic_ctrl → diag_done → state_machine
  channel_fsm → CLEAR_FAULT后自动诊断 → diagnostic_ctrl → diag_done → channel_fsm
```

---

## 4. 优化后的状态机设计

### 4.1 主状态机（优化后）

```
状态集合：
├── STANDBY       (待机)
├── HI_Z          (高阻)
├── MUTE          (静音)
├── PLAY          (播放)
└── DIAG_PENDING  (诊断进行中——转换中间态，非独立工作态)
```

**状态转换（优化后）**：

```
STANDBY ──standby_n=1──► HI_Z

HI_Z ──0x04=PLAY/MUTE──► DIAG_PENDING ──diag_pass──► PLAY/MUTE
 │                                          │
 │                              diag_fail──► HI_Z
 │
 ├──0x04=DC_DIAG──► DIAG_PENDING ──diag_done──► HI_Z
 │
 ├──global_fault──► HI_Z（记录pre_fault_state）
 │
 └──clock_recovered──► pre_fault_state（自动恢复）

PLAY/MUTE ──global_fault──► HI_Z
         ──!standby_n──► [ramp_down] ──► STANDBY
         ──0x04=DC_DIAG──► DIAG_PENDING
         ──clock_lost──► HI_Z（记录pre_fault_state=PLAY/MUTE）
```

### 4.2 通道状态机（优化后，含hiccup）

```
通道状态集合：
├── CH_PLAY
├── CH_HI_Z
├── CH_MUTE
├── CH_DC_DIAG
├── CH_HICCUP_WAIT    (新增：hiccup等待，1秒定时器)
└── CH_DIAG_PENDING   (新增：诊断进行中)
```

**通道故障恢复流程（优化后）**：

```
CH_PLAY ──(OC/DC)──► CH_HI_Z (ch_fault_latched=1)
                          │
                          │ CLEAR_FAULT
                          ▼
                    CH_DIAG_PENDING (自动诊断)
                          │
                    ┌─────┴─────┐
                    │           │
                 诊断通过    诊断失败
                    │           │
                    │      CH_HICCUP_WAIT (1秒)
                    │           │
                    │      CH_DIAG_PENDING (重试)
                    ▼
               CH_PLAY/MUTE (恢复)
```

---

## 5. 优化后的寄存器映射补充

### 5.1 0x01寄存器位定义（补充）

| Bit | Field | 描述 |
|-----|-------|------|
| 7 | HPF_BYPASS | HPF旁路（当前未使用） |
| 6-5 | OTW_CTRL | 过温警告阈值 |
| 4 | OC_CTRL | 过流限制级别 |
| 3-2 | VOL_RATE | 音量ramp速率（1/2/4/8 FSYNC） |
| 1-0 | GAIN | 输出增益（7.5/15/21/29V） |

### 5.2 0x14寄存器位定义（完整）

| Bit | Field | 屏蔽对象 | 目标引脚 |
|-----|-------|---------|---------|
| 7 | MASK_OC | 过流 | FAULT |
| 6 | MASK_OTSD | 过温关断 | FAULT |
| 5 | MASK_UV | 欠压 | FAULT |
| 4 | MASK_OV | 过压 | FAULT |
| 3 | MASK_DC | 直流 | FAULT |
| 2 | RESERVED | - | - |
| 1 | MASK_CLIP | 削波 | WARN |
| 0 | MASK_OTW | 过温警告 | WARN |

### 5.3 0x21寄存器位定义（完整）

| Bit | Field | 描述 |
|-----|-------|------|
| 7 | CLEAR_FAULT | 清除故障锁存 |
| 6 | PBTL_CH_SEL | PBTL信号源翻转 |
| 5 | MASK_ILIMIT_WARNING | 屏蔽限流警告 |
| 4 | RESERVED | - |
| 3 | OTSD_AUTO_RECOVERY | OTSD自动恢复 |
| 2-0 | RESERVED | - |

### 5.4 0x26寄存器位定义（HPF控制）

| Bit | Field | 描述 |
|-----|-------|------|
| 3-0 | HPF_FC | HPF截止频率（4/8/15/30Hz） |

---

## 6. 优化实施路线图

### 阶段1：高优先级修复（P0）

| 优化项 | 工作量 | 预期效果 |
|--------|--------|---------|
| OPT-01 时钟自动恢复 | 中 | 时钟恢复后无需MCU干预 |
| OPT-02 DC诊断自动触发 | 大 | 符合datasheet核心行为 |
| OPT-03 ramp机制 | 大 | 防止pop/click噪声 |
| OPT-09 优先级修正 | 小 | standby_n强制待机 |

### 阶段2：功能完善（P1）

| 优化项 | 工作量 | 预期效果 |
|--------|--------|---------|
| OPT-04 通道级OTSD | 中 | 完整过温保护 |
| OPT-05 HPF | 中 | DC阻断 |
| OPT-06 音量控制 | 中 | 完整音量功能 |
| OPT-07 故障屏蔽 | 小 | 0x14寄存器功能 |

### 阶段3：功能扩展（P2）

| 优化项 | 工作量 | 预期效果 |
|--------|--------|---------|
| OPT-08 0x21完整位 | 小 | PBTL/ILIMIT功能 |
| OPT-10 hiccup模式 | 中 | OC故障自动恢复 |

---

## 7. v1文档更正

### 7.1 architecture_analysis.md更正

| 章节 | v1错误 | 更正 |
|------|--------|------|
| 3.1 差异表 | "STANDBY态I2C关闭" | **STANDBY态I2C=Active**（表9-5） |
| 3.1 差异表 | "当前RTL STANDBY态I2C仍可访问是错误" | **当前RTL是正确的**，无需修改 |
| 6.1 高优先级改进 | "STANDBY态I2C关闭" | **删除此项**，不需要修改 |

### 7.2 新增发现

v1文档**遗漏**的datasheet功能：
- ramp down/up机制（9.3.8, 9.3.11.4）
- HPF直流阻断（9.3.2）
- 音量增益ramp（9.3.3）
- 通道级OTSD（9.3.9.6）
- 时钟自动恢复（9.3.1.6）
- DC诊断三种触发场景（9.3.8）
- hiccup模式（9.3.9.2）
- 0x14完整屏蔽位（9.6.18）
- 0x21完整位定义（9.6.26）

---

## 8. 补充发现（DC诊断报告寄存器位定义修正）

### 8.1 DC诊断报告寄存器（0x0C-0x0E）位定义修正

**之前文档（错误）**：每通道2位编码

| 编码 | 含义 |
|------|------|
| 00 | 正常 |
| 01 | 开路 |
| 10 | 短路到地 |
| 11 | 短路到电池 |

**datasheet实际（正确）**：每通道4个独立bit

#### 0x0C - DC诊断报告1（CH1+CH2）

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

#### 0x0D - DC诊断报告2（CH3+CH4）

同0x0C结构，CH3在bit7-4，CH4在bit3-0。

#### 0x0E - DC诊断报告3 线路输出

| Bit | Field | 描述 |
|-----|-------|------|
| 7-4 | RESERVED | - |
| 3 | CH1 LO LDG | CH1线路输出检测 |
| 2 | CH2 LO LDG | CH2线路输出检测 |
| 1 | CH3 LO LDG | CH3线路输出检测 |
| 0 | CH4 LO LDG | CH4线路输出检测 |

### 8.2 0x09寄存器完整位定义（LDG BYPASS——决定性发现）

| Bit | Field | Reset | 描述 |
|-----|-------|-------|------|
| 7 | DC LDG ABORT | 0 | 1: 中止进行中的诊断 |
| 6 | 2x_RAMP | 0 | 1: 双倍ramp时间 |
| 5 | 2x_SETTLE | 0 | 1: 双倍稳定时间 |
| 4-2 | RESERVED | 000 | - |
| 1 | LDG LO ENABLE | 0 | 1: 线路输出诊断使能 |
| 0 | **LDG BYPASS** | **0** | **0: 自动诊断(离开Hi-Z+故障后); 1: 不自动** |

**关键结论**：0x09 bit0 `LDG BYPASS` 默认值=0，意味着**DC诊断默认自动触发**。这证实了架构优化方案OPT-02的必要性。

### 8.3 音量寄存器映射修正

| 值 | dB | 说明 |
|-----|-----|------|
| 0xFF | +24 dB | 最大增益 |
| 0xCF | 0 dB | 默认值 |
| 0x07 | -100 dB | 最小音量 |
| <0x07 | MUTE | 静音 |

### 8.4 0x0A/0x0B寄存器（短路负载阈值）

每通道4bit，可配置0.5~5Ω短路负载检测阈值：
- 0000: 0.5Ω
- 0001: 1Ω（默认）
- 0010: 1.5Ω
- ...
- 1001: 5Ω

> **详细分析见 `dc_diag_analysis.md`**

---

## 9. 更新后的待确认决策点

### 决策1：DC诊断定位（详见dc_diag_analysis.md）

- **选项A（推荐）**：通道级诊断，移除CHIP_DIAG全局态，主状态机4态
- **选项B**：保留CHIP_DIAG全局态（当前实现）
- **选项C**：混合方案

### 决策2：模块集成（详见dc_diag_analysis.md）

- **选项A（推荐）**：全部集成到现有模块，不新增独立模块
- **选项B**：部分新增独立模块

### 决策3：优化范围

- **选项A**：仅P0（4项）
- **选项B**：P0+P1（8项）
- **选项C**：全部P0+P1+P2（10项）
- **选项D**：仅文档不修改代码

### 决策4：后续工作

- **选项A**：继续完善文档
- **选项B**：开始修改RTL代码
- **选项C**：更新plan.md计划

---

## 9. 总结

### 9.1 核心发现

通过重新精读datasheet 9.3-9.4节，发现当前RTL架构存在**10项可优化点**：

**高优先级（P0）**——影响核心功能正确性：
1. 时钟错误应自动恢复（9.3.1.6）
2. DC诊断应自动触发（9.3.8）
3. 缺少ramp down/up机制（9.3.8/9.3.11.4）
4. 状态转换优先级需调整

**中优先级（P1）**——影响功能完整性：
5. 缺少通道级OTSD（9.3.9.6）
6. 缺少HPF直流阻断（9.3.2）
7. 缺少音量控制+增益ramp（9.3.3）
8. 0x14故障屏蔽位未实现

**低优先级（P2）**——功能扩展：
9. 0x21寄存器完整位定义
10. OC故障hiccup模式

### 9.2 v1文档更正

v1架构分析文档（`architecture_analysis.md`）中**"STANDBY态I2C关闭"的结论有误**。datasheet表9-5明确STANDBY态I2C=Active。当前RTL实现是正确的，无需修改。

### 9.3 优化后的架构亮点

优化后的架构将：
- **完全符合datasheet**的状态转换行为
- **支持自动诊断**（三种触发场景）
- **支持自动恢复**（时钟错误、OTSD、OC hiccup）
- **完整音频处理链**（HPF → 音量 → ramp → PWM）
- **完整故障屏蔽**（0x14寄存器7个屏蔽位）

### 9.4 工作量评估

| 优化范围 | 新增模块 | 修改模块 | 预计工作量 |
|---------|---------|---------|-----------|
| 仅P0（4项） | ramp_ctrl | 4个 | 中 |
| P0+P1（8项） | ramp_ctrl + volume_ctrl | 8个 | 大 |
| 全部（10项） | ramp_ctrl + volume_ctrl | 10个 | 很大 |

> **请审核本文档后告知：**
> 1. 选择哪个优化范围（决策1）
> 2. 新增模块方案（决策2）
> 3. DC诊断定位方案（决策3）
> 4. 后续工作方向（决策4）