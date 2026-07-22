# TAS6424E-Q1 状态机设计文档（v3.0 — 基于原始图重写）

> **版本**: v3.0.0  
> **日期**: 2026-07-22  
> **状态**: 已重写 - 基于doc_src原始状态机图  
> **基于**: doc_src目录下5张原始状态机图  
> **关联文档**: 
> - `state_machine_detailed_design.md` (本文档的详细版, 包含完整原始图复现)
> - `architecture_design_v2.md` (架构总览)
> - `module_functional_design.md` (模块功能)

---

## 0. 状态机层次总览 (v4.0 纠正)

```
顶层包装 (3态)    - PowerOn / STANDBY / ACT
  │
  └── 芯片主状态机 (5态)   - Hi-Z / Play / Mute / Single_Diag / Auto_Diag
       │
       ├── 通道状态派生 (组合逻辑) - 每通道2bit, 由reg_04[7:0] + chip_state组合派生
       │
       └── 诊断层
              ├── DC诊断FSM (15态) - IDLE/OBSERVATION+3阶段×4通道+DONE
              └── AC诊断FSM (6态)  - IDLE+CH1~4_AC+DONE
```

> **v4.0关键纠正**: 取消4个独立channel_fsm实例。通道状态由 `chip_state` + `reg_04[7:0]` 的组合逻辑直接派生，不是独立FSM。详见 `architecture_correction.md`。

**4个层级, 18个FSM状态 + 组合派生通道编码**

---

## 1. 顶层包装状态机

### 1.1 状态定义

```verilog
localparam TOP_POWERON = 2'd0;  // 上电过渡
localparam TOP_STANDBY = 2'd1;  // 待机 (最低功耗)
localparam TOP_ACT     = 2'd2;  // 激活 (正常工作)
```

### 1.2 状态转换图

```
            ┌──────────┐
            │ PowerOn  │
            └─────┬────┘
                  │ (模拟上电时序完成: DVDDPowerOn + POR_N释放)
        ┌─────────┴─────────┐
        │                   │
   STANDBY_N=1         STANDBY_N=0
        │                   │
        ▼                   ▼
   ┌──────────┐       ┌──────────┐
   │ STANDBY  │◄─────►│   ACT    │
   │ (低功耗) │ STB_N  │  (工作)  │
   └──────────┘ !STB_N └──────────┘
```

### 1.3 转换条件

| 当前态 | 下一态 | 条件 | 优先级 |
|--------|--------|------|--------|
| POWERON | STANDBY | POR_N释放 + STANDBY_N=1 | — |
| POWERON | ACT | POR_N释放 + STANDBY_N=0 | — |
| STANDBY | ACT | STANDBY_N=0 | — |
| ACT | STANDBY | STANDBY_N=1 | 最高 |
| STANDBY | STANDBY | STANDBY_N=1 (自保持) | — |
| ACT | ACT | STANDBY_N=0 (自保持) | — |

### 1.4 POWERON内部行为

- 等待VDD上电稳定
- 等待内部POR释放
- 等待I2C_ADDR引脚建立 (tI2C_ADDR ≥ 300µs)
- 等待I2C就绪 (tSTART ≤ 12ms)
- 完成后根据STANDBY_N引脚决定进入STANDBY或ACT

---

## 2. 芯片主状态机

### 2.1 状态定义

```verilog
localparam CHIP_HI_Z        = 3'd0;  // 高阻态 (默认)
localparam CHIP_PLAY        = 3'd1;  // 播放态
localparam CHIP_MUTE        = 3'd2;  // 静音频
localparam CHIP_SINGLE_DIAG = 3'd3;  // 单次诊断 (MCU触发)
localparam CHIP_AUTO_DIAG   = 3'd4;  // 自动诊断 (故障后)
```

### 2.2 正常态转换图

```
    ┌──────────┐
    │  Hi-Z态  │ ◄────────── (默认入口) ──────────┐
    └────┬─────┘                                    │
         │ 0x04配置停止诊断                          │ 一次诊断完成
         │ 0x04配置诊断态                            │
         ▼                                           │
    ┌────────────┐                                   │
    │ 单次诊断态 │ ──── 一次诊断完成 ───────────────►│
    └────┬───────┘                                   │
         │ 0x04配置Hi-Z                              │
         │ 0x04配置播放/静音                          │
         │ STANDBY_N=0                              │
         ▼                                           │
    ┌──────────┐  0x04配置/硬件引脚静音 ┌──────────┐│
    │ 播放态   │ ◄─────── 切换 ────────►│ 静音频   ││
    │  (Play)  │                       │  (Mute)  │┘
    └────┬─────┘                       └────┬─────┘
         │ 0x04配置诊断态                     │ 0x04配置诊断态
         ▼                                   ▼
    ┌────────────┐ ◄────────────────────── ┐│
    │ 单次诊断态 │                        ││
    └────────────┘ ◄──────────────────────┘│
                                              │
              Hi-Z态 ◄──────────────────────┘
```

### 2.3 故障态转换图（图34 故障发生芯片状态转换图）

```
   ┌────────────┐
   │ 播放态      │
   │ 静动态      │  ── 直流偏置异常/过流关断/时钟错误/其它无效 ──►  ┌──────────────┐
   │ Hi-Z态      │                                              │  自诊断态    │
   └────────────┘                                               │  (Auto Diag) │
                                                                  └──────┬───────┘
                                                                         │
                                                                         │ 0x04指示状态位1
                                                                         │ 异常通道已修复
                                                                         ▼
                                                                    ┌─────────┐
                                                                    │ Hi-Z态  │
                                                                    └────┬────┘
                                                                         │ 清除错误标志位
                                                                         │
                                                                         ▼
                                                                    ┌──────────┐
                                                                    │ Hi-Z态   │
                                                                    │ (复位状态)│
                                                                    └──────────┘
```

### 2.4 状态表 (datasheet 表9-5)

| 模式名称 | 输出级FETs | 内部振荡器 | I2C |
|---------|-----------|-----------|-----|
| 待机 (Standby) | 高阻态 | 关闭 | 关闭 |
| 高阻态 (Hi-Z) | 高阻态 | 工作 | 工作 |
| 静音态 (Mute) | 50%占空比开关 | 工作 | 工作 |
| 播放态 (Play) | 音频调制开关 | 工作 | 工作 |
| 单次诊断态 | 高阻态（诊断中） | 工作 | 工作 |
| 自诊断态 | 高阻态（诊断中） | 工作 | 工作 |

### 2.5 关键设计注释

- **芯片上电复位处于Hi-Z态，且0x13复位标志位置1** ← 重要
- **STANDBY引脚拉低时进入待机**；**拉高时回到原状态**
- **从静音/播放触发待机再唤醒，会触发自动DC诊断**（除非LDG_BYPASS=1）
- **跳过自动诊断可通过0x09 bit0 (LDG_BYPASS) 配置**

### 2.6 故障整体表 (datasheet 表9-6)

| 故障/事件 | 类别 | 监控模式 | 报告方式 | 响应结果 |
|----------|------|---------|---------|---------|
| POR | 电压故障 | all | I2C + WARN引脚 | 待机 |
| VBAT UV / PVDD UV | 电压故障 | Hi-Z, mute, play | I2C + FAULT引脚 | 高阻态 |
| VBAT OV / PVDD OV | 电压故障 | Hi-Z, mute, play | I2C + FAULT引脚 | 高阻态 |
| OTSD | 热关断 | Hi-Z, mute, play | I2C + FAULT引脚 | 高阻态 |
| OTW | 热警告 | Hi-Z, mute, play | I2C + WARN引脚 | 无 |
| 时钟错误 | 时钟 | Hi-Z, mute, play | I2C + FAULT引脚 | 自诊断态 |

### 2.7 状态转换条件详表

| # | 当前态 | 下一态 | 条件 | 优先级 |
|---|--------|--------|------|--------|
| 1 | 任意 | TOP_STANDBY | STANDBY_N=1 (顶层) | 最高 |
| 2 | 任意(非STANDBY) | CHIP_HI_Z | global_fault=1 (PVDD/VBAT UV/OV, OTSD, 直流偏置异常, 过流关断) | 高 |
| 3 | CHIP_HI_Z/PLAY/MUTE | CHIP_AUTO_DIAG | 时钟错误 | — |
| 4 | CHIP_HI_Z/PLAY/MUTE | CHIP_AUTO_DIAG | 直流偏置异常 / 过流关断 / 其它无效 | — |
| 5 | CHIP_HI_Z | CHIP_SINGLE_DIAG | 0x04配置诊断态 | — |
| 6 | CHIP_HI_Z | CHIP_MUTE | 0x04配置静音 / 硬件引脚静音 | — |
| 7 | CHIP_HI_Z | CHIP_PLAY | 0x04配置播放 / 硬件引脚释放 | — |
| 8 | CHIP_PLAY | CHIP_MUTE | 0x04配置静音 / 硬件引脚静音 | — |
| 9 | CHIP_MUTE | CHIP_PLAY | 0x04配置播放 / 硬件引脚释放 | — |
| 10 | CHIP_PLAY/MUTE | CHIP_HI_Z | 0x04配置Hi-Z | — |
| 11 | CHIP_PLAY/MUTE | CHIP_SINGLE_DIAG | 0x04配置诊断态 | — |
| 12 | CHIP_SINGLE_DIAG | CHIP_HI_Z | 一次诊断完成 | — |
| 13 | CHIP_SINGLE_DIAG | CHIP_HI_Z | 0x04配置Hi-Z (中断) | — |
| 14 | CHIP_SINGLE_DIAG | CHIP_PLAY/MUTE | 0x04配置播放/静音 (中断) | — |
| 15 | CHIP_AUTO_DIAG | CHIP_HI_Z | 异常通道已修复 / 0x04指示状态位1 | — |
| 16 | CHIP_HI_Z (故障保持) | CHIP_HI_Z (复位状态) | 清除错误标志位 + 0x04指示状态位 | — |

---

## 3. 通道状态组合派生逻辑 (v4.0 纠正)

> **关键纠正**: 通道状态不是4个独立FSM，而是由 `chip_state` + `reg_04[7:0]` + `ac_diag_en[3:0]` 组合派生。

### 3.1 派生算法

```verilog
// 通道 i (i=0,1,2,3) 状态由组合逻辑派生
// 0x04编码: 00=PLAY, 01=HI_Z, 10=MUTE, 11=DC_DIAG

wire [1:0] ch_state [0:3];

assign ch_state[i] = (chip_state == CHIP_HI_Z || chip_state == CHIP_STANDBY)
    ? 2'b01  // 强制Hi-Z
    : (chip_state == CHIP_AC_DIAG && ac_diag_en[i])
        ? 2'b11  // AC诊断
        : ((chip_state == CHIP_SINGLE_DIAG || chip_state == CHIP_AUTO_DIAG)
           && reg_04_ch[i] == 2'b11)
            ? 2'b11  // DC诊断
            : reg_04_ch[i];  // 直接使用0x04: 00=PLAY,01=HI_Z,10=MUTE
```

### 3.2 使能信号派生

```verilog
assign ch_en[i]          = (ch_state[i] == 2'b00) || (ch_state[i] == 2'b10);
assign ch_mute_mode[i]   = (ch_state[i] == 2'b10);
assign ch_diag_active[i] = (ch_state[i] == 2'b11) && (chip_state != CHIP_AC_DIAG);
assign ch_ac_active[i]   = (ch_state[i] == 2'b11) && (chip_state == CHIP_AC_DIAG);
```

### 3.3 各主状态下的通道行为表

| chip_state | 通道行为 |
|-----------|---------|
| CHIP_HI_Z | **强制所有通道Hi-Z (无视0x04)** |
| CHIP_STANDBY | 强制所有通道Hi-Z |
| CHIP_PLAY | 通道按0x04独立: 00=PLAY, 01=HI_Z, 10=MUTE |
| CHIP_MUTE | 通道按0x04独立: 00=PLAY, 01=HI_Z, 10=MUTE |
| CHIP_SINGLE_DIAG | 0x04=11的通道→DC_DIAG; 其余→HI_Z |
| CHIP_AUTO_DIAG | 故障通道→DC_DIAG; 其余→HI_Z |
| CHIP_AC_DIAG | ac_diag_en=1的通道→AC_DIAG; 其余→HI_Z |

### 3.4 通道使能编码表

| ch_state[1:0] | 条件 | ch_en | ch_mute | ch_diag | ch_ac | PWM |
|--------------|------|-------|---------|---------|-------|-----|
| 00 (PLAY) | chip_state in {PLAY, MUTE} | 1 | 0 | 0 | 0 | 音频调制 |
| 01 (HI_Z) | 任意 | 0 | 0 | 0 | 0 | 高阻 |
| 10 (MUTE) | chip_state in {PLAY, MUTE} | 1 | 1 | 0 | 0 | 50%方波 |
| 11 (DC_DIAG) | chip_state in {SINGLE_DIAG, AUTO_DIAG} | 0 | 0 | 1 | 0 | 高阻(诊断) |
| 11 (AC_DIAG) | chip_state == CHIP_AC_DIAG | 0 | 0 | 0 | 1 | 高阻(诊断) |

> **说明**: 编码 2'b11 在不同 chip_state 下含义不同，通过 chip_state 区分 DC_DIAG 和 AC_DIAG。

### 3.5 与四个通道的状态跳转图的对应

图中 CH_HIGH_Z / CH_PLAY / CH_MUTE 重叠区域表示：
- 每个宏状态同时包含4个通道的子状态
- 通道子状态由 0x04[7:0] 的 2bit×4 编码字段决定
- 不是4个独立的FSM，而是一张图中复合展示所有通道的行为

```
芯片主状态       通道可进入状态
─────────────────────────────────────
CHIP_HI_Z        只能CH_HIGH_Z (即使0x04配置其他)
CHIP_PLAY        CH_PLAY / CH_MUTE / CH_HIGH_Z
CHIP_MUTE        CH_PLAY / CH_MUTE / CH_HIGH_Z
CHIP_SINGLE_DIAG CH_HIGH_Z / CH_SINGLE_DC_DIAG / CH_AC_DIAG
CHIP_AUTO_DIAG   CH_HIGH_Z / CH_SINGLE_DC_DIAG / CH_AC_DIAG
```

### 3.6 关键设计注释

1. **STANDBY_N取消信号会让任何0x04重新进入配置状态**
2. **不会根据0x04进入AC诊断**（AC诊断需要0x15/0x16显式配置）
3. **AC诊断只能在CH_HIGH_Z态进入**
4. **CH_PLAY存在时溢载（过流）后状态是控制输出的**（强制回Hi-Z）

---

## 4. DC诊断状态机

### 4.1 状态定义（15个）

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

### 4.2 状态转换图

```
IDLE ──► OBSERVATION ──► CH1_S2GP ──► CH2_S2GP ──► CH3_S2GP ──► CH4_S2GP
                                                              │
                                                              ▼
                CH1_SLICK ◄── CH2_SLICK ◄── CH3_SLICK ◄── CH4_SLICK
                  │             │             │             │
                  └─────────────┴─────────────┴─────────────┘
                                      │
                                      ▼
                CH1_LO  ◄──  CH2_LO  ◄──  CH3_LO  ◄──  CH4_LO
                                                              │
                                                              ▼
                                                          DONE ──► IDLE
```

### 4.3 转换条件表

| 当前态 | 下一态 | 触发信号 | 含义 |
|--------|--------|---------|------|
| IDLE | OBSERVATION | ch_diagnostic | 启动诊断 |
| OBSERVATION | CH1_S2GP | ch1_en | 启动CH1 S2G+S2P测试 |
| CH1_S2GP | CH2_S2GP | ch2_en | CH1完成, 启动CH2 |
| CH2_S2GP | CH3_S2GP | ch3_en | CH2完成, 启动CH3 |
| CH3_S2GP | CH4_S2GP | ch4_en | CH3完成, 启动CH4 |
| CH4_S2GP | CH1_SLICK | ch1_ol | CH4完成, 启动CH1 SL测试 |
| CH1_SLICK | CH2_SLICK | ch2_ol | CH1完成, 启动CH2 |
| CH2_SLICK | CH3_SLICK | ch3_ol | CH2完成, 启动CH3 |
| CH3_SLICK | CH4_SLICK | ch4_ol | CH3完成, 启动CH4 |
| CH4_SLICK | CH1_LO | ch1_lo | CH4完成, 启动CH1 LO测试 |
| CH1_LO | CH2_LO | ch2_lo | CH1完成, 启动CH2 |
| CH2_LO | CH3_LO | ch3_lo | CH2完成, 启动CH3 |
| CH3_LO | CH4_LO | ch3_lo | CH3完成, 启动CH4 |
| CH4_LO | DONE | done | 全部完成 |
| DONE | IDLE | (自动) | 1clk后返回 |
| 任意 | IDLE | abort (0x09 bit7) | 中止 |

### 4.4 关键设计注释

1. **启动chN_diagnostic完成时，可重新开始**（IDLE可接收新触发）
2. **SL_G包含了S2G, SL_P, S2P的诊断**（S2GP阶段实际测试3项）
3. **可同时启动SL_G测试**
4. **OL不检查短到电源的诊断, S2P不检查SL**
5. **自动情况则SL_G/OL**（自动诊断时执行SL_G和OL）

### 4.5 测试阶段划分

| 阶段 | 状态 | 测试项 | 寄存器报告位 |
|------|------|--------|-------------|
| 1 (S2GP) | CH1_S2GP~CH4_S2GP | S2G (对地短路) + S2P (对电源短路) | 0x0C/0x0D bit7,6,3,2 |
| 2 (SLICK) | CH1_SLICK~CH4_SLICK | SL (短路负载) + OL (开路) | 0x0C/0x0D bit5,4,1,0 |
| 3 (LO) | CH1_LO~CH4_LO | LO (线路输出) | 0x0E bit3,2,1,0 |

---

## 5. AC诊断状态机

### 5.1 状态定义（6个）

```verilog
localparam AC_DIAG_IDLE = 3'd0;
localparam CH1_AC       = 3'd1;
localparam CH2_AC       = 3'd2;
localparam CH3_AC       = 3'd3;
localparam CH4_AC       = 3'd4;
localparam AC_DONE      = 3'd5;
```

### 5.2 状态转换图

```
IDLE ──► CH1_AC ──► CH2_AC ──► CH3_AC ──► CH4_AC ──► DONE ──► IDLE
```

### 5.3 转换条件表

| 当前态 | 下一态 | 触发信号 |
|--------|--------|---------|
| IDLE | CH1_AC | ch1_en |
| CH1_AC | CH2_AC | ch2_en |
| CH2_AC | CH3_AC | ch3_en |
| CH3_AC | CH4_AC | ch4_en |
| CH4_AC | AC_DONE | done |
| AC_DONE | IDLE | (自动) |
| 任意 | IDLE | abort |

### 5.4 AC诊断特点

- 顺序执行：CH1→CH2→CH3→CH4
- 每通道独立测量阻抗/相位
- 总时间：~520ms (typ)
- 单通道时间：~130ms (typ)

---

## 6. 状态机间交互关系

### 6.1 层级关系

```
TOP ──► 芯片主 ──► 通道 ──► DC/AC诊断
 │
 │   强制STANDBY
 │
 └─► 所有FSM都冻结

芯片主 ──► 通道
 │   强制CH_HIGH_Z
 │
 └─► 通道必须配合

通道 ──► DC/AC诊断
 │   启动ch_diagnostic
 │
 └─► DC/AC FSM开始运行
```

### 6.2 关键信号

| 信号 | 源 | 目标 | 作用 |
|------|-----|------|------|
| STANDBY_N | 引脚(经去抖) | 顶层/主状态机/通道 | 强制STANDBY |
| chip_state[2:0] | 主状态机 | 通道状态机 | 全局模式 |
| ch_state_req[7:0] | 寄存器0x04 | 通道状态机 | 用户配置 |
| ch_state[1:0] ×4 | 通道状态机 | 寄存器0x0F | 状态报告 |
| ch_diagnostic[3:0] | 主状态机/0x04 | DC诊断FSM | 启动DC诊断 |
| ch_ac_diagnostic[3:0] | 0x15/0x16 | AC诊断FSM | 启动AC诊断 |
| diag_done | DC/AC FSM | 主状态机 | 诊断完成 |
| chN_en | DC/AC FSM | DC/AC FSM内部 | 通道间顺序触发 |

---

## 7. 设计检查清单

- [ ] 顶层3态FSM (PowerOn/Standby/Act) 是否与上电时序匹配
- [ ] 芯片主状态机5态是否完整（Hi-Z/Play/Mute/Single_Diag/Auto_Diag）
- [ ] 通道状态机5态是否完整（High_Z/Mute/Play/Single_DC_Diag/AC_Diag）
- [ ] 通道CH_AC_DIAG是否仅从CH_HIGH_Z进入
- [ ] DC诊断FSM是否15态顺序正确
- [ ] DC诊断的S2GP/SLICK/LO三个阶段是否正确
- [ ] AC诊断FSM是否6态顺序正确
- [ ] 各FSM的abort机制是否正确
- [ ] STANDBY_N=0的全局强制是否覆盖所有FSM
- [ ] 主FSM与通道FSM的协作关系是否清晰
- [ ] diag_done信号是否正确触发主状态机退出诊断态
- [ ] 自动诊断(Single_Diag vs Auto_Diag)的区分是否清晰
- [ ] 故障后从PLAY/MUTE回Hi-Z的路径是否覆盖
- [ ] 异常通道完成DC后回Hi-Z的条件是否正确
