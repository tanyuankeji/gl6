# TAS6424E-Q1 模块功能详细设计文档

> **版本**: v1.0.0  
> **日期**: 2026-07-14  
> **状态**: 待审核  
> **关联文档**: `architecture_design_v2.md`、`module_interface_design.md`、`fsm_design.md`

---

## 1. 模块功能概述

本文档详细描述每个RTL模块的内部功能实现算法、数据结构、关键计数器设计和内部信号处理流程。

---

## 2. I2C从机模块 (i2c_slave)

### 2.1 功能描述

实现标准I2C从机协议，支持：
- 4个设备地址 (由I2C_ADDR引脚选择)
- 100kbps标准模式和400kbps快速模式
- 随机/顺序读写
- START/STOP/RESTART条件检测

### 2.2 内部信号与寄存器

```
┌──────────────────────────────────────────────────┐
│              i2c_slave 内部结构                    │
│                                                    │
│  scl_i ──►[2DFF同步]──► scl_sync ──►[边沿检测]    │
│                                          │         │
│  sda_i ──►[2DFF同步]──► sda_sync ──►[START/STOP]  │
│                                          │         │
│                                   ┌──────▼──────┐  │
│                                   │   I2C FSM   │  │
│                                   │  (9状态)    │  │
│                                   └──┬───┬───┬──┘  │
│                                      │   │   │     │
│                              ┌───────┘   │   └─────│──► reg_wr_en/addr/data
│                              ▼           ▼         │
│                         ┌────────┐ ┌────────┐      │
│                         │ 移位   │ │位计数器 │      │
│                         │ 寄存器 │ │(0-7)   │      │
│                         └────────┘ └────────┘      │
│                                         │          │
│  sda_io ◄──[输出控制]◄── sda_out ──────┘          │
└──────────────────────────────────────────────────┘
```

### 2.3 关键计数器

| 计数器 | 位宽 | 用途 |
|--------|------|------|
| bit_cnt | 3 | 当前字节的位计数 (0-7 → 8位) |
| scl_pos/neg_pulse | 1 | SCL边沿检测单周期脉冲 |
| start_detected | 1 | START条件检测标志 |
| stop_detected | 1 | STOP条件检测标志 |

### 2.4 START/STOP检测逻辑

```verilog
// START条件: SCL高电平期间 SDA下降沿
wire start_cond = scl_sync && sda_sync_d1 && !sda_sync;

// STOP条件: SCL高电平期间 SDA上升沿
wire stop_cond  = scl_sync && !sda_sync_d1 && sda_sync;
```

### 2.5 地址匹配

```verilog
// 7位设备地址 (不含R/W位)
wire [6:0] device_addr;
assign device_addr = (i2c_addr_i == 2'b00) ? 7'h6A :  // 0xD4/0xD5
                     (i2c_addr_i == 2'b01) ? 7'h6B :  // 0xD6/0xD7
                     (i2c_addr_i == 2'b10) ? 7'h6C :  // 0xD8/0xD9
                                              7'h6D;   // 0xDA/0xDB

// 地址匹配: 比较7位地址
wire addr_match = (shift_reg[7:1] == device_addr);
```

---

### 3.0 通道状态组合派生逻辑 (v4.0 纠正)

> **关键纠正**: 非独立FSM。由 `chip_state + reg_04 + ac_diag_en` 组合派生。

**派生算法** (纯组合逻辑, 0寄存器):

```verilog
wire [1:0] ch_state [0:3];

generate
    for (genvar i = 0; i < 4; i = i + 1) begin : gen_ch_state
        // 0x04编码: 00=PLAY, 01=HI_Z, 10=MUTE, 11=DC_DIAG/AC_DIAG
        assign ch_state[i] = (chip_state == CHIP_HI_Z || chip_state == CHIP_STANDBY)
            ? 2'b01  // 强制Hi-Z
            : (chip_state == CHIP_AC_DIAG && ac_diag_en[i])
                ? 2'b11  // AC诊断 (复用11编码)
                : ((chip_state == CHIP_SINGLE_DIAG || chip_state == CHIP_AUTO_DIAG)
                   && reg_04[i*2+:2] == 2'b11)
                    ? 2'b11  // DC诊断
                    : reg_04[i*2+:2];  // 直接使用0x04

        assign ch_en[i]          = (ch_state[i] == 2'b00) || (ch_state[i] == 2'b10);
        assign ch_mute_mode[i]   = (ch_state[i] == 2'b10);
        assign ch_diag_active[i] = (ch_state[i] == 2'b11) && (chip_state != CHIP_AC_DIAG);
        assign ch_ac_active[i]   = (ch_state[i] == 2'b11) && (chip_state == CHIP_AC_DIAG);
    end
endgenerate

// 0x0F寄存器组装
assign ch_state_report = {ch_state[0], ch_state[1], ch_state[2], ch_state[3]};
```

**设计要点**:
- 编码 2'b11 在不同 chip_state 下含义不同 (DC_DIAG vs AC_DIAG)
- Hi-Z/STANDBY 强制覆盖 0x04
- 纯组合逻辑，无时序依赖，无亚稳态风险

---

## 3. 寄存器文件模块 (register_file)

### 3.1 功能描述

维护完整的寄存器空间(0x00-0x79)，管理I2C读写和硬件写入的仲裁。

### 3.2 寄存器阵列结构

```verilog
// 128字节寄存器空间 (0x00-0x7F)
// 分为两个逻辑区域:
//   R/W区域: I2C可读写, 硬件只读
//   R区域:   硬件可写, I2C只读
reg [7:0] reg_array [0:127];
```

### 3.3 读写仲裁逻辑

```verilog
// 地址分类函数
function is_ro_register(input [7:0] addr);
    // 只读寄存器: 0x0C-0x1E (诊断报告), 0x0F-0x13 (状态/故障/警告)
    case (addr)
        8'h0C, 8'h0D, 8'h0E,         // DC诊断报告
        8'h0F,                         // 通道状态报告
        8'h10, 8'h11, 8'h12, 8'h13,   // 故障/警告
        8'h17, 8'h18, 8'h19, 8'h1A,   // AC诊断报告
        8'h1B, 8'h1C, 8'h1D, 8'h1E:   // AC相位/STI报告
            is_ro_register = 1'b1;
        8'h24:                          // Clip Warning (写1清除)
            is_ro_register = 1'b0;      // 特殊: 可写清除
        default:
            is_ro_register = 1'b0;
    endcase
endfunction

// I2C写: 仅R/W寄存器
always @(posedge clk) begin
    if (reg_wr_en && !is_ro_register(reg_wr_addr))
        reg_array[reg_wr_addr] <= reg_wr_data;
end

// 硬件写: 仅R寄存器
always @(posedge clk) begin
    if (hw_wr_en && is_ro_register(hw_wr_addr))
        reg_array[hw_wr_addr] <= hw_wr_data;
end
```

### 3.4 特殊位处理

```verilog
// soft_reset (0x00 bit7): 自清除
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        reg_array[8'h00][7] <= 1'b0;
    else if (reg_wr_en && reg_wr_addr == 8'h00 && reg_wr_data[7])
        reg_array[8'h00][7] <= 1'b0;  // 写入1后下一周期自清除
    else if (reg_wr_en && reg_wr_addr == 8'h00)
        reg_array[8'h00][7] <= reg_wr_data[7];  // 正常写入0
end

// clear_fault (0x21 bit7): 脉冲生成
reg clear_fault_d;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_array[8'h21][7] <= 1'b0;
        clear_fault_d <= 1'b0;
    end else begin
        if (reg_wr_en && reg_wr_addr == 8'h21 && reg_wr_data[7]) begin
            reg_array[8'h21][7] <= 1'b0;  // 自清除
            clear_fault_d <= 1'b1;          // 指示清除脉冲
        end else begin
            clear_fault_d <= 1'b0;
        end
    end
end
assign clear_fault = clear_fault_d;  // 1周期脉冲
```

---

## 4. 音频接口模块 (audio_interface)

### 4.1 功能描述

处理串行音频数据输入，支持多格式解码：
- I2S (24bit, FSYNC=0→左通道)
- Left-Justified (24bit, FSYNC=1→左通道)
- Right-Justified (16/18/20/24bit)
- DSP模式
- TDM4/TDM8 (SDIN1承载多通道数据)

### 4.2 模式解码算法

```
┌─────────────────────────────────────────────────────────┐
│                  音频接口处理链                          │
│                                                          │
│  SCLK ──►[同步+边沿]──► sclk_neg_pulse ──┐               │
│                                           │               │
│  SDIN ──►[同步]──────► sdin_sync ────────┼──►[移位寄存器]│
│                                           │     ↓         │
│  FSYNC──►[同步+边沿]──► fsync_rising ────┼──►[位计数器]  │
│                                           │     ↓         │
│  sap_mode ───────────────────────────────┼──►[模式解码]  │
│                                           │     ↓         │
│                                           ├──►[数据锁存] │
│                                           │     ↓         │
│                                      audio_data_ch[1:4]  │
└─────────────────────────────────────────────────────────┘
```

### 4.3 I2S模式解码算法

```verilog
// I2S模式关键状态
reg        i2s_left_phase;       // 当前在左通道相位
reg [4:0]  i2s_bit_cnt;         // 当前帧内位计数 (0-63 @64×fs)
reg [23:0] i2s_shift_reg;       // 24位移位寄存器

// FSYNC边沿: 切换到左通道
always @(posedge clk) begin
    if (fsync_rising_pulse) begin
        i2s_left_phase <= 1'b1;    // 左通道开始
        i2s_bit_cnt    <= 5'd0;
    end
end

// 在SCLK下降沿采样 (使用sclk_neg_pulse)
always @(posedge clk) begin
    if (sclk_neg_pulse) begin
        // 移位: MSB优先
        i2s_shift_reg <= {i2s_shift_reg[22:0], sdin_sync};
        i2s_bit_cnt <= i2s_bit_cnt + 1'b1;
        
        // 在第24位后切换相位
        if (i2s_bit_cnt == 5'd23) begin
            i2s_left_phase <= !i2s_left_phase;  // 切换到右通道
        end
        
        // 数据锁存: I2S的MSB在bit_cnt=1 (延迟1个SCLK)
        if (i2s_bit_cnt == 5'd0) begin
            if (i2s_left_phase)
                // 锁存左通道数据 (1个SCLK前的)
                latch_left_channel();
            else
                latch_right_channel();
        end
    end
end
```

### 4.4 LJ模式关键区别

```verilog
// LJ模式: 无延迟, FSYNC边沿同时开始MSB
// FSYNC=1 → 左通道 (与I2S相反!)
// 直接采样sdin_sync到MSB位
```

### 4.5 TDM模式处理

```verilog
// TDM模式: SDIN1承载最多8个通道数据
// FSYNC为短脉冲, 每个帧包含8个32-SCLK时隙
// 根据tdm_slot_sel选择前4或后4个时隙映射到CH1~4
```

### 4.6 位计数器设计

| 模式 | 帧内SCLK数 | bit_cnt范围 | 数据有效位 |
|------|-----------|-------------|-----------|
| I2S/LJ/RJ (32×fs) | 64 | 0-63 | 根据格式决定 |
| I2S/LJ/RJ (64×fs) | 128 | 0-127 | 根据格式决定 |
| TDM4 (32bit×4) | 128 | 0-127 | 各时隙开始 |
| TDM8 (32bit×8) | 256 | 0-255 | 各时隙开始 |

---

## 5. PWM生成器模块 (pwm_generator)

### 5.1 功能描述

将24位PCM音频数据转换为BTL PWM开关信号。

### 5.2 三角波载波设计

```
PWM三角波载波 (向上/向下计数器):

计数值 ──┐
         │    /\      /\      /\      /\
         │   /  \    /  \    /  \    /  \
         │  /    \  /    \  /    \  /    \
         │ /      \/      \/      \/      \
         └──────────────────────────────────► 时间

载波生成算法:
- 计数器从0向上计数到PWM_MAX，然后向下计数到0
- PWM_MAX = clk_freq / (2 × pwm_freq)
- 方向: 到达PWM_MAX后翻转为向下, 到达0后翻转为向上
```

### 5.3 PWM_MAX计算

```verilog
// PWM频率与PWM_MAX对应表 (clk=10MHz)
// PWM_FREQ = 8×fs  = 384kHz  → PWM_MAX = 10M/(2×384k) ≈ 13.02 → 取整
// PWM_FREQ = 44×fs = 2.11MHz → PWM_MAX = 10M/(2×2.11M) ≈ 2.37

// 实际实现: 使用相位累加器 + 比较器
// 以更高精度逼近2.11MHz载波

reg [23:0] carrier_phase;  // 24位相位累加器
reg [23:0] phase_step;     // 相位步进值

// phase_step = (2^24 * pwm_freq) / clk_freq
// 2.11MHz @10MHz: phase_step = (16777216 * 2110000) / 10000000 ≈ 3540

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        carrier_phase <= 0;
    else if (pwm_enable)
        carrier_phase <= carrier_phase + phase_step;
end

// 三角波: 使用carrier_phase最高位判断方向
wire carrier_direction = carrier_phase[23];  // 0=向上, 1=向下
wire [22:0] triangle_value = carrier_direction ?
    ~carrier_phase[22:0] :  // 向下: 反转
    carrier_phase[22:0];    // 向上: 直接

// 三角波缩放到24位有符号范围
wire signed [23:0] triangle_wave = {carrier_direction ? 1'b0 : 1'b1, triangle_value[22:0]};
```

### 5.4 PWM比较器

```verilog
// 每通道独立比较器
// audio_data_chX: 24位有符号音频数据
// 与三角波比较生成PWM信号

// BTL输出: out_p和out_m互为反相
// audio_data > 0: out_p高电平时间更长 → 正向电流
// audio_data = 0: out_p和out_m各50%占空比 → 零差动输出
// audio_data < 0: out_m高电平时间更长 → 反向电流

wire signed [23:0] pwm_threshold_ch1;
assign pwm_threshold_ch1 = audio_data_ch1;  // 缩放后

// 比较器
reg out_1p, out_1m;
always @(posedge clk) begin
    // out_p: audio > triangle → high
    out_1p <= (pwm_threshold_ch1 > {{1{1'b0}}, triangle_wave[22:0]});
    // out_m: -audio > triangle → high (即 audio < -triangle)
    out_1m <= (-pwm_threshold_ch1 > {{1{1'b0}}, triangle_wave[22:0]});
end
```

### 5.5 Hi-Z与MUTE处理

```verilog
// Hi-Z: 输出强制为0
// MUTE: 50%占空比方波 (与audio_data=0相同)
// PLAY: 正常PWM调制

always @(posedge clk) begin
    if (!ch_en[i])
        {out_p[i], out_m[i]} <= 2'b00;     // Hi-Z
    else if (ch_mute_mode[i])
        {out_p[i], out_m[i]} <= 2'b10;     // MUTE (50%占空比)
    else
        // PLAY: 正常比较器结果
        out_p[i] <= comparator_p_result;
        out_m[i] <= comparator_m_result;
end
```

### 5.6 通道相位偏移

```verilog
// 每个通道的PWM相位可独立偏移
// phase_table[phase_sel][channel] = 偏移量 (度数)
// 示例: phase_sel=110 → CH1=0°, CH2=225°, CH3=90°, CH4=315°

// 实现: 为每个通道维护独立的载波相位
reg [23:0] carrier_phase_ch[0:3];

always @(posedge clk) begin
    carrier_phase_ch[0] <= carrier_phase_ch[0] + phase_step;  // CH1: 参考
    carrier_phase_ch[1] <= carrier_phase_ch[0] + phase_offset_ch2;
    carrier_phase_ch[2] <= carrier_phase_ch[0] + phase_offset_ch3;
    carrier_phase_ch[3] <= carrier_phase_ch[0] + phase_offset_ch4;
end
```

---

## 6. 故障监控器模块 (fault_monitor)

### 6.1 故障锁存机制

```verilog
// 锁存型故障 (需clear_fault清除):
//   - 全局: OV, UV, OTSD (全局+通道)
//   - 通道: OC, DC
// 非锁存型故障:
//   - clock_lost (自动恢复)
//   - OTW (仅WARN, FAULT引脚, 自动恢复)
//   - POR (VDD恢复后自动清除)

reg global_fault_latch [6:0];   // 全局故障锁存
reg ch_fault_latch [3:0][1:0];  // 通道故障锁存 (OC, DC)

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        global_fault_latch <= 0;
        ch_fault_latch <= 0;
    end else if (clear_fault) begin
        global_fault_latch <= 0;
        ch_fault_latch <= 0;
    end else begin
        // 锁存: 故障触发时置位
        if (pvdd_ov_int)   global_fault_latch[0] <= 1'b1;
        if (vbat_ov_int)   global_fault_latch[1] <= 1'b1;
        if (pvdd_uv_int)   global_fault_latch[2] <= 1'b1;
        if (vbat_uv_int)   global_fault_latch[3] <= 1'b1;
        if (otsd_int)      global_fault_latch[4] <= 1'b1;
        // clock_lost: 非锁存, 直接使用clock_lost信号
        for (i = 0; i < 4; i++) begin
            if (oc_ch[i])  ch_fault_latch[i][0] <= 1'b1;
            if (dc_ch[i])  ch_fault_latch[i][1] <= 1'b1;
            if (otsd_ch_int[i]) ch_fault_latch[i][2] <= 1'b1;
        end
    end
end
```

### 6.2 寄存器编码逻辑

```verilog
// 0x10 通道故障寄存器
assign hw_ch_faults = {oc_ch_latch, dc_ch_latch};

// 0x11 全局故障1
assign hw_global_fault1 = {3'b000, clock_lost, pvdd_ov_latch,
                           vbat_ov_latch, pvdd_uv_latch, vbat_uv_latch};

// 0x12 全局故障2
assign hw_global_fault2 = {3'b000, otsd_global_latch, otsd_ch_latch[3:0]};

// 0x13 警告
assign hw_warnings = {2'b00, por_flag, otw_int, otw_ch_int[3:0]};
```

### 6.3 中断生成

```verilog
// global_fault_irq: 任何全局故障或通道故障触发
assign global_fault_irq = (|global_fault_latch) ||
                          (|ch_fault_latch) ||
                          clock_lost;

// fault_trigger (FAULT引脚): 受遮罩控制
assign fault_trigger_raw = global_fault_irq;
// pin_mask在pin_control模块中应用

// warn_trigger (WARN引脚): OTW/POR/CLIP
assign warn_trigger_raw = otw_int || por_vdd || (|clip_warning);
```

---

## 7. 保护电路模块 (protection)

### 7.1 去毛刺实现

```verilog
// 通用参数化去毛刺模块
// 信号需在FAULT_DEGLITCH_CYCLES内持续有效才确认

module deglitch_filter #(
    parameter DEGLITCH_CYCLES = 100  // 10us @10MHz
) (
    input  wire clk, rst_n,
    input  wire sig_raw,
    output wire sig_filtered
);
    reg [$clog2(DEGLITCH_CYCLES+1)-1:0] cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 0;
        else if (!sig_raw)
            cnt <= 0;  // 信号无效, 立即清零
        else if (cnt < DEGLITCH_CYCLES)
            cnt <= cnt + 1'b1;
    end
    
    assign sig_filtered = (cnt >= DEGLITCH_CYCLES);
endmodule
```

### 7.2 OTSD自动恢复

```verilog
// 当otsd_auto_recovery=1时
// OTSD触发后启动冷却计时器
// 冷却时间达OTSD_RECOVERY_CYCLES后自动清除

reg [31:0] otsd_recovery_timer;
reg        otsd_auto_clear;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        otsd_recovery_timer <= 0;
        otsd_auto_clear <= 1'b0;
    end else begin
        otsd_auto_clear <= 1'b0;  // 默认
        if (otsd_int && otsd_auto_recovery) begin
            // OTSD触发, 启动计时器
            if (otsd_recovery_timer < OTSD_RECOVERY_CYCLES)
                otsd_recovery_timer <= otsd_recovery_timer + 1'b1;
            else
                otsd_auto_clear <= 1'b1;  // 自动清除
        end else if (!otsd_int) begin
            // OTSD恢复后清除
            otsd_recovery_timer <= 0;
        end
    end
end

// otsd_auto_clear连接到clear_fault逻辑
```

---

## 8. 诊断控制器模块 (diagnostic_ctrl)

> **重要**: 本节基于doc_src原始状态机图（DC诊断的状态跳转.jpg、AC诊断的状态跳转.jpg）重写。

### 8.1 DC诊断状态机（15个状态）

```
IDLE ──► OBSERVATION ──► CH1_S2GP ──► CH2_S2GP ──► CH3_S2GP ──► CH4_S2GP
            ↑                                                    │
            │                                                    ▼
            │        CH1_SLICK ◄── CH2_SLICK ◄── CH3_SLICK ◄── CH4_SLICK
            │          │             │             │             │
            │          └─────────────┴─────────────┴─────────────┘
            │                                       │
            │                                       ▼
            │        CH1_LO  ◄──  CH2_LO  ◄──  CH3_LO  ◄──  CH4_LO
            │                                                    │
            └──────────────── DONE ───────────────────────────────┘
```

#### 8.1.1 状态编码

```verilog
// 4位状态编码
localparam DC_DIAG_IDLE        = 4'd0;
localparam DC_DIAG_OBSERVATION = 4'd1;  // 启动准备
localparam DC_DIAG_CH1_S2GP    = 4'd2;  // CH1 S2G+S2P测试
localparam DC_DIAG_CH2_S2GP    = 4'd3;
localparam DC_DIAG_CH3_S2GP    = 4'd4;
localparam DC_DIAG_CH4_S2GP    = 4'd5;
localparam DC_DIAG_CH1_SLICK   = 4'd6;  // CH1 SL+OL测试
localparam DC_DIAG_CH2_SLICK   = 4'd7;
localparam DC_DIAG_CH3_SLICK   = 4'd8;
localparam DC_DIAG_CH4_SLICK   = 4'd9;
localparam DC_DIAG_CH1_LO      = 4'd10; // CH1 LO测试
localparam DC_DIAG_CH2_LO      = 4'd11;
localparam DC_DIAG_CH3_LO      = 4'd12;
localparam DC_DIAG_CH4_LO      = 4'd13;
localparam DC_DONE             = 4'd14;
```

#### 8.1.2 状态转换逻辑

```verilog
// 15状态FSM - 顺序执行三个测试阶段
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dc_diag_state <= DC_DIAG_IDLE;
    end else if (dc_ldg_abort) begin
        // 中止诊断
        dc_diag_state <= DC_DIAG_IDLE;
    end else begin
        case (dc_diag_state)
            DC_DIAG_IDLE:
                if (ch_diagnostic_any)
                    dc_diag_state <= DC_DIAG_OBSERVATION;
                else
                    dc_diag_state <= DC_DIAG_IDLE;
            DC_DIAG_OBSERVATION:
                if (obs_timer_done)
                    dc_diag_state <= DC_DIAG_CH1_S2GP;
            DC_DIAG_CH1_S2GP:
                if (ch1_s2gp_done)
                    dc_diag_state <= DC_DIAG_CH2_S2GP;
            DC_DIAG_CH2_S2GP:
                if (ch2_s2gp_done)
                    dc_diag_state <= DC_DIAG_CH3_S2GP;
            DC_DIAG_CH3_S2GP:
                if (ch3_s2gp_done)
                    dc_diag_state <= DC_DIAG_CH4_S2GP;
            DC_DIAG_CH4_S2GP:
                if (ch4_s2gp_done)
                    dc_diag_state <= DC_DIAG_CH1_SLICK;
            DC_DIAG_CH1_SLICK:
                if (ch1_slick_done)
                    dc_diag_state <= DC_DIAG_CH2_SLICK;
            DC_DIAG_CH2_SLICK:
                if (ch2_slick_done)
                    dc_diag_state <= DC_DIAG_CH3_SLICK;
            DC_DIAG_CH3_SLICK:
                if (ch3_slick_done)
                    dc_diag_state <= DC_DIAG_CH4_SLICK;
            DC_DIAG_CH4_SLICK:
                if (ch4_slick_done)
                    dc_diag_state <= DC_DIAG_CH1_LO;
            DC_DIAG_CH1_LO:
                if (ch1_lo_done)
                    dc_diag_state <= DC_DIAG_CH2_LO;
            DC_DIAG_CH2_LO:
                if (ch2_lo_done)
                    dc_diag_state <= DC_DIAG_CH3_LO;
            DC_DIAG_CH3_LO:
                if (ch3_lo_done)
                    dc_diag_state <= DC_DIAG_CH4_LO;
            DC_DIAG_CH4_LO:
                if (ch4_lo_done)
                    dc_diag_state <= DC_DONE;
            DC_DONE:
                dc_diag_state <= DC_DIAG_IDLE;  // 1clk后返回
        endcase
    end
end
```

#### 8.1.3 通道使能信号生成 (ch1_en~ch4_en, ch1_ol~ch4_ol, ch1_lo~ch4_lo)

```verilog
// 阶段1: S2GP测试 - ch1_en~ch4_en 顺序触发
assign ch1_en = (dc_diag_state == DC_DIAG_CH1_S2GP);
assign ch2_en = (dc_diag_state == DC_DIAG_CH2_S2GP);
assign ch3_en = (dc_diag_state == DC_DIAG_CH3_S2GP);
assign ch4_en = (dc_diag_state == DC_DIAG_CH4_S2GP);

// 阶段2: SLICK测试 - ch1_ol~ch4_ol 顺序触发
assign ch1_ol = (dc_diag_state == DC_DIAG_CH1_SLICK);
assign ch2_ol = (dc_diag_state == DC_DIAG_CH2_SLICK);
assign ch3_ol = (dc_diag_state == DC_DIAG_CH3_SLICK);
assign ch4_ol = (dc_diag_state == DC_DIAG_CH4_SLICK);

// 阶段3: LO测试 - ch1_lo~ch4_lo 顺序触发
assign ch1_lo = (dc_diag_state == DC_DIAG_CH1_LO);
assign ch2_lo = (dc_diag_state == DC_DIAG_CH2_LO);
assign ch3_lo = (dc_diag_state == DC_DIAG_CH3_LO);
assign ch4_lo = (dc_diag_state == DC_DIAG_CH4_LO);

assign done = (dc_diag_state == DC_DIAG_CH4_LO && ch4_lo_timer_done);
```

#### 8.1.4 DC诊断报告编码

```verilog
// 0x0C: DC Load Diagnostic Report 1 (CH1+CH2)
assign dc_diag_rpt1 = {s2g_ch[0], s2p_ch[0], ol_ch[0], sl_ch[0],
                       s2g_ch[1], s2p_ch[1], ol_ch[1], sl_ch[1]};

// 0x0D: DC Load Diagnostic Report 2 (CH3+CH4) — 同上格式
// 0x0E: DC Load Diagnostic Report 3 (Line Output)
assign dc_diag_rpt3 = {4'b0000, lo_ch[3:0]};
```

#### 8.1.5 关键设计注释

1. **启动chN_diagnostic完成时，可重新开始**（IDLE可接收新触发）
2. **SL_G包含了S2G, SL_P, S2P的诊断**（S2GP阶段实际测试3项）
3. **OL不检查短到电源的诊断, S2P不检查SL**
4. **自动诊断情况则执行SL_G/OL**（跳过LO）
5. **每阶段内部使用4个顺序子状态**

### 8.2 AC诊断状态机（6个状态）

```
IDLE ──► CH1_AC ──► CH2_AC ──► CH3_AC ──► CH4_AC ──► DONE ──► IDLE
```

#### 8.2.1 状态编码

```verilog
localparam AC_DIAG_IDLE = 3'd0;
localparam CH1_AC       = 3'd1;
localparam CH2_AC       = 3'd2;
localparam CH3_AC       = 3'd3;
localparam CH4_AC       = 3'd4;
localparam AC_DONE      = 3'd5;
```

#### 8.2.2 状态转换逻辑

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ac_diag_state <= AC_DIAG_IDLE;
    end else if (ac_ldg_abort) begin
        ac_diag_state <= AC_DIAG_IDLE;
    end else begin
        case (ac_diag_state)
            AC_DIAG_IDLE:
                if (ac_diag_en[0])  // CH1使能
                    ac_diag_state <= CH1_AC;
            CH1_AC:
                if (ch1_ac_done)
                    ac_diag_state <= CH2_AC;
            CH2_AC:
                if (ch2_ac_done)
                    ac_diag_state <= CH3_AC;
            CH3_AC:
                if (ch3_ac_done)
                    ac_diag_state <= CH4_AC;
            CH4_AC:
                if (ch4_ac_done)
                    ac_diag_state <= AC_DONE;
            AC_DONE:
                ac_diag_state <= AC_DIAG_IDLE;  // 1clk后返回
        endcase
    end
end
```

#### 8.2.3 通道使能信号生成

```verilog
// AC诊断每通道顺序执行
assign ch1_en_ac = (ac_diag_state == CH1_AC);
assign ch2_en_ac = (ac_diag_state == CH2_AC);
assign ch3_en_ac = (ac_diag_state == CH3_AC);
assign ch4_en_ac = (ac_diag_state == CH4_AC);
```

### 8.3 诊断计时器

```verilog
// DC诊断计时器
reg [23:0] dc_diag_timer;
wire dc_diag_done = (dc_diag_timer >= DIAG_TIMEOUT_CYCLES);

// 支持加倍计时 (2x_SETTLE/2x_RAMP)
wire [23:0] timer_limit = dc_diag_ctrl1[6] ?
    {DIAG_TIMEOUT_CYCLES[22:0], 1'b0} :  // 2倍
    DIAG_TIMEOUT_CYCLES;
```

### 8.4 诊断时间分配

| 诊断类型 | 总时间 | 单项时间 | 通道数 | 阶段数 |
|---------|--------|---------|--------|--------|
| DC完整诊断 | ~230ms (typ) | ~19ms | 4 | 3 (S2GP/SLICK/LO) |
| AC顺序诊断 | ~520ms (typ) | ~130ms | 4 | 1 (顺序) |

---

## 9. 设计检查清单

- [ ] I2C从机是否正确生成1clk宽度的读写脉冲
- [ ] 寄存器读写仲裁是否正确 (R寄存器不允许I2C写)
- [ ] 音频接口在各种模式下bit_cnt是否正确定义
- [ ] PWM相位累加器精度是否满足载波频率要求
- [ ] BTL输出逻辑是否正确 (正反相互补)
- [ ] 故障锁存器是否正确响应clear_fault
- [ ] 去毛刺计数器在信号消失时是否立即清零
- [ ] OTSD自动恢复计时器是否只在auto_recovery=1时工作
- [ ] 诊断报告编码是否与datasheet寄存器定义一致
- [ ] 所有计数器在rst_n复位后是否回到正确初始值
