# TAS6424E-Q1 模块接口设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-14  
> **状态**: 待审核  
> **关联文档**: `architecture_design_v2.md`、`fsm_design.md`

---

## 1. 顶层模块接口 (tas6424e_top)

### 1.1 端口定义

```verilog
module tas6424e_top (
    // ==========================================
    // 系统信号
    // ==========================================
    input  wire         clk,                // 系统主时钟 10MHz
    input  wire         rst_n,              // 异步复位 (低有效)

    // ==========================================
    // I2C 接口
    // ==========================================
    input  wire         scl_i,              // I2C 串行时钟
    inout  wire         sda_io,             // I2C 双向数据
    input  wire [1:0]   i2c_addr_i,         // I2C 地址选择

    // ==========================================
    // 音频接口
    // ==========================================
    input  wire         mclk_i,             // 音频主时钟
    input  wire         sclk_i,             // 音频位时钟 (BCLK)
    input  wire         fsync_i,            // 帧同步 (LRCLK)
    input  wire         sd_in1_i,           // TDM数据 / I2S CH1+2
    input  wire         sd_in2_i,           // I2S CH3+4

    // ==========================================
    // 硬件控制引脚
    // ==========================================
    input  wire         standby_n_i,        // 待机 (低有效, 带下拉)
    input  wire         mute_n_i,           // 硬件静音 (低有效, 带下拉)
    output wire         fault_n_o,          // 故障输出 (开漏, 低有效)
    output wire         warn_n_o,           // 警告输出 (开漏, 低有效)

    // ==========================================
    // PWM输出 (4通道 BTL)
    // ==========================================
    output wire         out_1p_o,           // CH1 正相输出
    output wire         out_1m_o,           // CH1 反相输出
    output wire         out_2p_o,           // CH2 正相输出
    output wire         out_2m_o,           // CH2 反相输出
    output wire         out_3p_o,           // CH3 正相输出
    output wire         out_3m_o,           // CH3 反相输出
    output wire         out_4p_o,           // CH4 正相输出
    output wire         out_4m_o,           // CH4 反相输出

    // ==========================================
    // 模拟前端输入 (保护/诊断信号)
    // ==========================================
    // 过温
    input  wire         otw_raw_i,          // 全局过温警告 (原始)
    input  wire         otsd_raw_i,         // 全局过温关断 (原始)
    input  wire [3:0]   otw_ch_raw_i,       // CH1~4 通道过温警告
    input  wire [3:0]   otsd_ch_raw_i,      // CH1~4 通道过温关断
    // 电压
    input  wire         vbat_uv_raw_i,      // VBAT欠压 (原始)
    input  wire         vbat_ov_raw_i,      // VBAT过压 (原始)
    input  wire         pvdd_uv_raw_i,      // PVDD欠压 (原始)
    input  wire         pvdd_ov_raw_i,      // PVDD过压 (原始)
    // 通道故障
    input  wire [3:0]   oc_ch_i,            // CH1~4 过流检测
    input  wire [3:0]   dc_ch_i,            // CH1~4 DC偏移检测
    // POR
    input  wire         por_vdd_i           // VDD上电复位指示
);
```

### 1.2 模块例化结构

```
tas6424e_top
├── i2c_slave          inst_i2c (.scl_i, .sda_io, ...)
├── register_file      inst_reg  (.reg_wr_en, .reg_wr_data, ...)
├── state_machine      inst_sm   (.chip_state, .diag_trigger, ...)
├── channel_fsm × 4    gen_ch[0:3] (.ch_state_req, .ch_state, ...)
├── audio_interface    inst_audio (.sclk_i, .fsync_i, ...)
├── pwm_generator      inst_pwm  (.audio_data, .out_1p_o, ...)
├── diagnostic_ctrl    inst_diag (.diag_trigger, .diag_done, ...)
├── fault_monitor      inst_fault (.otw_int, .hw_ch_faults, ...)
├── pin_control        inst_pin  (.standby_n_i, .fault_n_o, ...)
├── clock_monitor      inst_clkm (.mclk_i, .clock_lost, ...)
└── protection         inst_prot (.otw_raw_i, .otw_int, ...)
```

---

## 2. 各模块接口详细定义

### 2.1 i2c_slave

```verilog
module i2c_slave (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // I2C 物理接口
    input  wire         scl_i,
    inout  wire         sda_io,
    input  wire [1:0]   i2c_addr_i,
    // 寄存器文件接口 (控制)
    output reg          reg_wr_en,          // 写使能脉冲
    output reg  [7:0]   reg_wr_addr,        // 写地址
    output reg  [7:0]   reg_wr_data,        // 写数据
    output reg          reg_rd_en,          // 读使能脉冲
    output reg  [7:0]   reg_rd_addr,        // 读地址
    input  wire [7:0]   reg_rd_data,        // 读数据返回
    // 状态输出
    output wire         i2c_active          // I2C传输进行中
);
```

**接口说明**:

| 信号 | 行为 |
|------|------|
| `reg_wr_en` | 1 clk脉冲, 在收到完整写入字节并发送ACK后产生 |
| `reg_wr_data` | 与`reg_wr_en`同时有效 |
| `reg_rd_en` | 1 clk脉冲, 在收到读命令子地址后产生 |
| `reg_rd_data` | 在`reg_rd_en`后下一周期被采样发送 |

---

### 2.2 register_file

```verilog
module register_file (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // I2C读写接口
    input  wire         reg_wr_en,
    input  wire [7:0]   reg_wr_addr,
    input  wire [7:0]   reg_wr_data,
    input  wire         reg_rd_en,
    input  wire [7:0]   reg_rd_addr,
    output reg  [7:0]   reg_rd_data,
    // 硬件写入接口 (来自内部模块)
    input  wire         hw_wr_en,
    input  wire [7:0]   hw_wr_addr,
    input  wire [7:0]   hw_wr_data,
    // ===== 模块配置输出 =====
    // 0x00 模式控制
    output wire         soft_reset,         // bit7 自清除脉冲
    output wire         pbtl_ch12,          // bit4
    output wire         pbtl_ch34,          // bit5
    output wire [3:0]   lo_mode,            // bit3:0 线路输出模式
    // 0x01 杂项控制1
    output wire         hpf_bypass,         // bit7
    output wire [1:0]   otw_threshold,      // bit6:5
    output wire         oc_level,           // bit4 (0=Lev1,1=Lev2)
    output wire [1:0]   volume_rate,        // bit3:2
    output wire [1:0]   gain_level,         // bit1:0
    // 0x02 杂项控制2
    output wire [2:0]   pwm_freq,           // bit6:4
    output wire         sdm_osr,            // bit2
    output wire [1:0]   output_phase_lsb,   // bit1:0
    // 0x03 SAP控制
    output wire [1:0]   fs_sample,          // bit7:6
    output wire         tdm_slot_sel,       // bit5
    output wire         tdm_slot_size,      // bit4
    output wire         tdm_swap,           // bit3
    output wire [2:0]   sap_mode,           // bit2:0
    // 0x04 通道状态控制
    output wire [7:0]   ch_state_ctrl,      // bit7:0 (CH1~4 × 2bit)
    // 0x05-0x08 通道音量
    output wire [7:0]   ch_vol_ch1, ch_vol_ch2, ch_vol_ch3, ch_vol_ch4,
    // 0x09-0x0B DC诊断控制
    output wire [7:0]   dc_diag_ctrl1, dc_diag_ctrl2, dc_diag_ctrl3,
    // 0x14 引脚控制
    output wire [7:0]   pin_ctrl,
    // 0x15-0x16 AC诊断控制
    output wire [7:0]   ac_diag_ctrl1, ac_diag_ctrl2,
    // 0x21 杂项控制3
    output wire         clear_fault_pulse,  // bit7 自清除脉冲
    output wire         otsd_auto_recovery, // bit3
    // 0x22-0x24 削波控制
    output wire [7:0]   clip_ctrl, clip_window,
    output wire [7:0]   clip_warn_clear,
    // 0x26 杂项控制4
    output wire [3:0]   hpf_corner,         // bit3:0
    // 0x28 杂项控制5
    output wire         phase_sel_msb,      // bit5
    // 0x77-0x79 扩频
    output wire [7:0]   ss_ctrl1, ss_ctrl2, ss_ctrl3
);
```

**硬件写入接口连接**:
- fault_monitor → hw_wr (0x0F, 0x10, 0x11, 0x12, 0x13)
- diagnostic_ctrl → hw_wr (0x0C, 0x0D, 0x0E, 0x17~0x1E)
- channel_fsm × 4 → 顶层组装 → hw_wr (0x0F)

---

### 2.3 state_machine

```verilog
module state_machine (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 控制输入
    input  wire         standby_n,          // 去抖后的STANDBY
    input  wire         global_fault_irq,   // 全局故障中断
    input  wire         clear_fault,        // 清除故障
    // 通道状态请求 (来自reg 0x04)
    input  wire [7:0]   ch_state_req,       // CH1~4 × 2bit
    // 诊断接口
    input  wire         diag_done,          // 诊断完成
    output reg          diag_trigger,       // 诊断触发脉冲
    // 状态输出
    output reg  [2:0]   chip_state          // 当前芯片状态 (3bit)
);
```

---

### 2.4 channel_fsm

```verilog
module channel_fsm (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 全局状态
    input  wire [2:0]   chip_state,         // 芯片主状态
    input  wire         clear_fault,        // 清除故障
    // 通道请求 (2bit, 来自reg 0x04对应位)
    input  wire [1:0]   ch_state_req,       // 通道状态请求
    // 故障输入
    input  wire         ch_fault,           // 通道故障 (来自fault_monitor)
    // 诊断
    input  wire         diag_done,          // 诊断完成
    // 通道控制输出
    output reg  [1:0]   ch_state,           // 通道当前状态
    output reg          ch_en,              // 通道使能 (PWM)
    output reg          ch_mute_mode,       // 静音模式
    output reg          ch_diag_active,     // 诊断进行中
    // 故障锁存输出 (用于0x0F寄存器组装)
    output wire         ch_fault_latched
);
```

**每通道信号宽度**: 输入8个信号, 输出6个信号  
**4实例总信号**: 顶层需管理 4 × 14 = 56 根互联信号

---

### 2.5 audio_interface

```verilog
module audio_interface (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 音频时钟 (异步, 经内部同步)
    input  wire         mclk_i,             // MCLK (仅用于时钟监控)
    input  wire         sclk_i,             // SCLK/BCLK
    input  wire         fsync_i,            // FSYNC/LRCLK
    // 音频数据
    input  wire         sd_in1_i,           // SDIN1 (TDM/I2S CH1+2)
    input  wire         sd_in2_i,           // SDIN2 (I2S CH3+4)
    // 模式配置
    input  wire [1:0]   fs_sample,          // 采样率: 00=44.1k,01=48k,10=96k
    input  wire [2:0]   sap_mode,           // 格式: 000=RJ24, 100=I2S, 101=LJ, 110=DSP
    input  wire         tdm_slot_sel,       // TDM时隙选择
    input  wire         tdm_slot_size,      // 0=24/32bit, 1=16bit
    input  wire         tdm_swap,           // TDM交换
    input  wire         hpf_bypass,         // 高通滤波器旁路
    input  wire [3:0]   hpf_corner,         // 高通滤波器截止频率
    // 通道使能 (影响数据转发)
    input  wire [3:0]   ch_en_vec,          // CH1~4使能 (关闭时数据=0)
    // 音频数据输出 (24bit × 4通道)
    output reg  [23:0]  audio_data_ch1,
    output reg  [23:0]  audio_data_ch2,
    output reg  [23:0]  audio_data_ch3,
    output reg  [23:0]  audio_data_ch4,
    output reg          audio_valid,        // 数据有效脉冲
    // 时钟状态 (供clock_monitor)
    output wire         mclk_active,
    output wire         sclk_active,
    output wire         fsync_active
);
```

**内部处理链**:
```
SCLK/FSYNC → 2DFF同步 → 边沿检测 → 模式解码 → SDIN移位采样 → 通道锁存 → 24bit输出
```

---

### 2.6 pwm_generator

```verilog
module pwm_generator (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 音频数据 (24bit × 4通道)
    input  wire [23:0]  audio_data_ch1,
    input  wire [23:0]  audio_data_ch2,
    input  wire [23:0]  audio_data_ch3,
    input  wire [23:0]  audio_data_ch4,
    input  wire         audio_valid,
    // 通道控制 (来自channel_fsm)
    input  wire [3:0]   ch_en,              // CH1~4使能
    input  wire [3:0]   ch_mute_mode,       // CH1~4静音
    // 模式配置
    input  wire [1:0]   fs_sample,          // 采样率
    input  wire [2:0]   pwm_freq,           // PWM频率选择
    input  wire [2:0]   output_phase,       // 相位编码 {phase_msb, output_phase_lsb}
    input  wire [1:0]   gain_level,         // 增益: 00=7.5V,01=15V,10=21V,11=29V
    input  wire         pbtl_ch12,          // PBTL模式 CH1/2
    input  wire         pbtl_ch34,          // PBTL模式 CH3/4
    // 扩频控制 (预留)
    input  wire [7:0]   ss_ctrl1,
    input  wire [7:0]   ss_ctrl2,
    input  wire [7:0]   ss_ctrl3,
    // PWM输出 (8路: 4通道 × 正/反相)
    output reg          out_1p, out_1m,
    output reg          out_2p, out_2m,
    output reg          out_3p, out_3m,
    output reg          out_4p, out_4m
);
```

---

### 2.7 diagnostic_ctrl

```verilog
module diagnostic_ctrl (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 诊断触发/完成
    input  wire         diag_trigger,       // 启动诊断
    input  wire [3:0]   ch_diag_active,     // 哪些通道在诊断中
    output reg          diag_done,          // 诊断完成脉冲
    // DC诊断控制
    input  wire [7:0]   dc_diag_ctrl1,      // 0x09
    input  wire [7:0]   dc_diag_ctrl2,      // 0x0A
    input  wire [7:0]   dc_diag_ctrl3,      // 0x0B
    // AC诊断控制
    input  wire [7:0]   ac_diag_ctrl1,      // 0x15
    input  wire [7:0]   ac_diag_ctrl2,      // 0x16
    // 诊断输入 (来自模拟前端)
    input  wire [3:0]   s2g_ch,             // CH1~4 对地短路 (模拟前端测量)
    input  wire [3:0]   s2p_ch,             // CH1~4 对电源短路
    input  wire [3:0]   ol_ch,              // CH1~4 开路
    input  wire [3:0]   sl_ch,              // CH1~4 负载短路
    input  wire [3:0]   lo_ch,              // CH1~4 线路输出
    // 诊断报告输出 → register_file (硬件写入)
    output reg  [7:0]   dc_diag_rpt1,       // 0x0C (CH1+CH2)
    output reg  [7:0]   dc_diag_rpt2,       // 0x0D (CH3+CH4)
    output reg  [7:0]   dc_diag_rpt3,       // 0x0E (Line Output)
    output reg  [7:0]   ac_diag_rpt_ch1,    // 0x17
    output reg  [7:0]   ac_diag_rpt_ch2,    // 0x18
    output reg  [7:0]   ac_diag_rpt_ch3,    // 0x19
    output reg  [7:0]   ac_diag_rpt_ch4,    // 0x1A
    output reg  [7:0]   ac_phase_high,      // 0x1B
    output reg  [7:0]   ac_phase_low,       // 0x1C
    output reg  [7:0]   ac_sti_high,        // 0x1D
    output reg  [7:0]   ac_sti_low,         // 0x1E
    // 硬件写控制
    output reg          hw_wr_en,
    output reg  [7:0]   hw_wr_addr,
    output reg  [7:0]   hw_wr_data
);
```

---

### 2.8 fault_monitor

```verilog
module fault_monitor (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 清除故障
    input  wire         clear_fault,        // 来自reg 0x21 bit7
    // 保护后的故障信号 (来自protection, 已去毛刺)
    input  wire         otw_int,
    input  wire         otsd_int,
    input  wire [3:0]   otw_ch_int,
    input  wire [3:0]   otsd_ch_int,
    input  wire         vbat_uv_int,
    input  wire         vbat_ov_int,
    input  wire         pvdd_uv_int,
    input  wire         pvdd_ov_int,
    // 通道故障 (直接输入)
    input  wire [3:0]   oc_ch,              // CH1~4 过流
    input  wire [3:0]   dc_ch,              // CH1~4 DC偏移
    // 时钟故障
    input  wire         clock_lost,         // 来自clock_monitor
    // POR
    input  wire         por_vdd,            // VDD POR
    // 故障输出 → 状态机
    output wire         global_fault_irq,   // 全局故障中断
    output wire [3:0]   ch_fault,           // CH1~4 通道故障
    // 故障/警告 → 引脚控制
    output wire         fault_trigger,      // FAULT引脚触发
    output wire         warn_trigger,       // WARN引脚触发
    // 硬件写 → 寄存器文件
    output wire [7:0]   hw_ch_faults,       // 0x10
    output wire [7:0]   hw_global_fault1,   // 0x11
    output wire [7:0]   hw_global_fault2,   // 0x12
    output wire [7:0]   hw_warnings,        // 0x13
    output reg          hw_wr_en,
    output reg  [7:0]   hw_wr_addr,
    output reg  [7:0]   hw_wr_data
);
```

**故障锁存逻辑**:
- 所有故障在触发时锁存
- 仅通过`clear_fault`信号清除
- `clock_lost`是唯一自动清除的故障（时钟恢复后自动解除）

---

### 2.9 pin_control

```verilog
module pin_control (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 硬件引脚 (异步输入)
    input  wire         standby_n_i,        // STANDBY引脚
    input  wire         mute_n_i,           // MUTE引脚
    // 故障/警告触发
    input  wire         fault_trigger,      // 来自fault_monitor
    input  wire         warn_trigger,       // 来自fault_monitor
    // 遮罩控制
    input  wire [7:0]   pin_ctrl,           // 0x14 寄存器
    // 清除
    input  wire         clear_fault,        // 清除锁存
    // 引脚输出 (开漏模拟)
    output wire         fault_n_o,          // FAULT输出
    output wire         warn_n_o,           // WARN输出
    // 去抖后输出 (供状态机)
    output wire         standby_n_db,       // 去抖后的STANDBY
    output wire         mute_n_db           // 去抖后的MUTE
);
```

**去抖动实现**:

```verilog
// STANDBY/MUTE去抖计数器
// 使用饱和计数器: 输入=1时递增, 输入=0时递减
// 达到DEBOUNCE_CYCLES时输出=1, 为0时输出=0
// DEBOUNCE_CYCLES = 500 → 50us @10MHz
reg [9:0] standby_debounce_cnt;
reg standby_stable;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        standby_debounce_cnt <= 0;
        standby_stable <= 1'b0;
    end else begin
        if (standby_n_i) begin
            if (standby_debounce_cnt < DEBOUNCE_CYCLES)
                standby_debounce_cnt <= standby_debounce_cnt + 1'b1;
            if (standby_debounce_cnt == DEBOUNCE_CYCLES)
                standby_stable <= 1'b1;
        end else begin
            if (standby_debounce_cnt > 0)
                standby_debounce_cnt <= standby_debounce_cnt - 1'b1;
            if (standby_debounce_cnt == 0)
                standby_stable <= 1'b0;
        end
    end
end
```

---

### 2.10 clock_monitor

```verilog
module clock_monitor (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 音频时钟 (已同步)
    input  wire         mclk_sync,          // 同步后的MCLK
    input  wire         sclk_sync,          // 同步后的SCLK
    input  wire         fsync_sync,         // 同步后的FSYNC
    // 使能
    input  wire         monitor_en,         // 非STANDBY时使能
    // 时钟丢失输出
    output reg          clock_lost,         // 时钟丢失 (任一)
    output reg          mclk_lost,
    output reg          sclk_lost,
    output reg          fsync_lost
);
```

**超时检测**:
```verilog
// MCLK活动检测计数器
reg [23:0] mclk_timeout_cnt;
wire mclk_edge_detected;  // MCLK翻转边沿

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        mclk_timeout_cnt <= 0;
    else if (!monitor_en)
        mclk_timeout_cnt <= 0;
    else if (mclk_edge_detected)
        mclk_timeout_cnt <= 0;             // 有活动→清零
    else if (mclk_timeout_cnt < CLK_TIMEOUT_CYCLES)
        mclk_timeout_cnt <= mclk_timeout_cnt + 1'b1;
    // 达到超时→保持
end

assign mclk_lost = (mclk_timeout_cnt >= CLK_TIMEOUT_CYCLES);
```

---

### 2.11 protection

```verilog
module protection (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 原始故障输入
    input  wire         otw_raw,            // 全局过温警告
    input  wire         otsd_raw,           // 全局过温关断
    input  wire [3:0]   otw_ch_raw,         // CH1~4 通道过温警告
    input  wire [3:0]   otsd_ch_raw,        // CH1~4 通道过温关断
    input  wire         vbat_uv_raw,        // VBAT欠压
    input  wire         vbat_ov_raw,        // VBAT过压
    input  wire         pvdd_uv_raw,        // PVDD欠压
    input  wire         pvdd_ov_raw,        // PVDD过压
    // 控制
    input  wire         clear_fault,        // 清除故障
    input  wire         otsd_auto_recovery, // OTSD自动恢复使能
    // 去毛刺后输出
    output wire         otw_int,
    output wire         otsd_int,
    output wire [3:0]   otw_ch_int,
    output wire [3:0]   otsd_ch_int,
    output wire         vbat_uv_int,
    output wire         vbat_ov_int,
    output wire         pvdd_uv_int,
    output wire         pvdd_ov_int
);
```

**去毛刺实现**:
```verilog
// 通用去毛刺模块
// 信号需连续稳定FAULT_DEGLITCH_CYCLES个周期才确认
// 计数器在信号翻转时复位
reg [9:0] deglitch_cnt;  // FAULT_DEGLITCH_CYCLES = 100

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        deglitch_cnt <= 0;
    else if (!raw_signal)  // 信号无效时清零
        deglitch_cnt <= 0;
    else if (deglitch_cnt < FAULT_DEGLITCH_CYCLES)
        deglitch_cnt <= deglitch_cnt + 1'b1;
end

assign debounced_signal = (deglitch_cnt >= FAULT_DEGLITCH_CYCLES);
```

**OTSD自动恢复**:
```verilog
// OTSD自动恢复冷却计时器 (仅当otsd_auto_recovery=1)
// OTSB_RECOVERY_CYCLES ≈ 16s @10MHz
reg [31:0] otsd_recovery_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        otsd_recovery_cnt <= 0;
    else if (otsd_int && otsd_auto_recovery)
        otsd_recovery_cnt <= 0;  // 关断时启动计时
    else if (otsd_recovery_cnt < OTSD_RECOVERY_CYCLES)
        otsd_recovery_cnt <= otsd_recovery_cnt + 1'b1;
end

assign otsd_recovered = (otsd_recovery_cnt >= OTSD_RECOVERY_CYCLES);
```

---

## 3. 信号连接汇总表

### 3.1 顶层内部连线清单

| 类别 | 数量 | 信号组 |
|------|------|--------|
| I2C→寄存器 | 5 | reg_wr_en,addr,data; reg_rd_en,addr; + rd_data |
| 寄存器→各模块 | ~40 | 各配置信号 |
| 状态机控制 | 5 | chip_state(3), diag_trigger, diag_done |
| 通道控制 (×4) | 6×4=24 | ch_state, ch_en, ch_mute, ch_diag_active, ch_fault, ch_fault_latched |
| 音频数据 | 10 | audio_data×4(24bit), audio_valid, ch_en_vec |
| 故障/保护 | ~24 | 各种去毛刺后信号 |
| 硬件写 | 3 | hw_wr_en, hw_wr_addr, hw_wr_data |
| 引脚控制 | 6 | standby_n_db, mute_n_db, fault_trigger, warn_trigger, fault_n_o, warn_n_o |
| 时钟监控 | 4 | mclk/sclk/fsync_sync/lost, clock_lost |
| **总计** | **~120** | — |

---

## 4. 设计检查清单

- [ ] 所有模块端口是否都有明确的位宽定义
- [ ] 输入/输出方向是否与数据流一致
- [ ] 顶层端口是否覆盖所有datasheet引脚
- [ ] 开漏输出引脚(fault_n/warn_n)是否正确建模
- [ ] 双向I2C SDA是否使用inout正确建模
- [ ] 异步输入是否在子模块内部正确同步
- [ ] 硬件写入是否有仲裁机制避免冲突
- [ ] 诊断报告输出是否正确路由到寄存器文件
