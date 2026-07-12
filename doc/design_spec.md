# TAS6424E-Q1 RTL 设计规格说明

## 1. 概述

本文件描述基于TI TAS6424E-Q1数据手册的RTL设计规格。TAS6424E-Q1是一款4通道数字输入D类汽车音频放大器，支持2.1MHz PWM开关频率，4.5V-26.4V电源，I2C控制，具备负载诊断和多重保护功能。

## 2. 顶层接口

### 2.1 引脚定义

| 引脚名 | 方向 | 位宽 | 描述 |
|--------|------|------|------|
| `clk` | input | 1 | 系统时钟（内部振荡器或外部） |
| `rst_n` | input | 1 | 异步复位，低有效 |
| `pad_rst_n` | input | 1 | POR复位信号 |
| `i2c_scl` | inout | 1 | I2C时钟线 |
| `i2c_sda` | inout | 1 | I2C数据线 |
| `i2c_addr0` | input | 1 | I2C地址选择位0 |
| `i2c_addr1` | input | 1 | I2C地址选择位1 |
| `mclk` | input | 1 | 音频主时钟 |
| `sclk` | input | 1 | 音频位时钟（BCLK） |
| `fsync` | input | 1 | 音频帧同步（LRCLK） |
| `sdin1` | input | 1 | 音频数据输入1 |
| `sdin2` | input | 1 | 音频数据输入2 |
| `standby_n` | input | 1 | 待机控制引脚（低有效） |
| `mute_n` | input | 1 | 静音控制引脚（低有效） |
| `fault_n` | output | 1 | 故障指示引脚（开漏，低有效） |
| `warn_n` | output | 1 | 警告指示引脚（开漏，低有效） |
| `out_1p` | output | 1 | 通道1正输出 |
| `out_1m` | output | 1 | 通道1负输出 |
| `out_2p` | output | 1 | 通道2正输出 |
| `out_2m` | output | 1 | 通道2负输出 |
| `out_3p` | output | 1 | 通道3正输出 |
| `out_3m` | output | 1 | 通道3负输出 |
| `out_4p` | output | 1 | 通道4正输出 |
| `out_4m` | output | 1 | 通道4负输出 |
| `otw` | input | 1 | 过温警告输入（模拟前端） |
| `otsd` | input | 1 | 过温关断输入（模拟前端） |
| `vbat_uv` | input | 1 | VBAT欠压输入（模拟前端） |
| `vbat_ov` | input | 1 | VBAT过压输入（模拟前端） |
| `pvdd_uv` | input | 1 | PVDD欠压输入（模拟前端） |
| `pvdd_ov` | input | 1 | PVDD过压输入（模拟前端） |
| `oc_ch1` | input | 1 | 通道1过流输入（模拟前端） |
| `oc_ch2` | input | 1 | 通道2过流输入（模拟前端） |
| `oc_ch3` | input | 1 | 通道3过流输入（模拟前端） |
| `oc_ch4` | input | 1 | 通道4过流输入（模拟前端） |
| `dc_ch1` | input | 1 | 通道1直流检测输入（模拟前端） |
| `dc_ch2` | input | 1 | 通道2直流检测输入（模拟前端） |
| `dc_ch3` | input | 1 | 通道3直流检测输入（模拟前端） |
| `dc_ch4` | input | 1 | 通道4直流检测输入（模拟前端） |

## 3. 寄存器映射

### 3.1 寄存器地址表

| 地址 | 寄存器名 | 默认值 | 类型 | 描述 |
|------|----------|--------|------|------|
| 0x00 | Mode Control | 0x00 | R/W | RESET, PBTL, LO_MODE |
| 0x01 | Misc Control 1 | 0x32 | R/W | HPF, OTW_CTRL, OC_CTRL, VOL_RATE, GAIN |
| 0x02 | Misc Control 2 | 0x62 | R/W | PWM_FREQ, SDM_OSR, OUT_PHASE |
| 0x03 | SAP Control | 0x04 | R/W | 音频接口模式选择 |
| 0x04 | Channel State Control | 0x55 | R/W | 每通道2位状态控制 |
| 0x05-0x08 | Ch1-4 Volume | 0xCF | R/W | 通道音量控制 |
| 0x09-0x0B | DC Diag Ctrl 1-3 | - | R/W | DC诊断控制 |
| 0x0C-0x0E | DC Diag Report 1-3 | - | R | DC诊断报告 |
| 0x0F | Channel State Reporting | 0x55 | R | 实时通道状态 |
| 0x10 | Channel Faults | 0x00 | R | OC/DC通道故障 |
| 0x11 | Global Faults 1 | 0x00 | R | 时钟/电压故障 |
| 0x12 | Global Faults 2 | 0x00 | R | 过温故障 |
| 0x13 | Warnings | 0x20 | R | POR/OTW警告 |
| 0x14 | Pin Control | 0x00 | R/W | 引脚控制配置 |
| 0x15-0x16 | AC Diag Ctrl 1-2 | - | R/W | AC诊断控制 |
| 0x17-0x1A | AC Diag Report | - | R | AC诊断报告 |
| 0x21 | Misc Control 3 | 0x00 | R/W | CLEAR_FAULT, OTSD_AUTO_RECOVERY |
| 0x22 | Clip Control | 0x01 | R/W | 削波检测控制 |
| 0x23 | Clip Window | 0x14 | R/W | 削波窗口 |
| 0x24 | Clip Warning | 0x00 | R/W | 削波警告 |
| 0x25 | ILIMIT Status | 0x00 | R/W | 限流状态 |
| 0x26 | Misc Control 4 | 0x40 | R/W | 杂项控制4 |
| 0x28 | Misc Control 5 | 0x0A | R/W | 杂项控制5 |
| 0x77-0x79 | Spread Spectrum | - | R/W | 扩频控制 |

### 3.2 关键寄存器字段定义

#### 0x00 - Mode Control
- bit[7]: RESET - 软件复位
- bit[5]: PBTL_CH34 - 通道3/4 PBTL模式
- bit[4]: PBTL_CH12 - 通道1/2 PBTL模式
- bit[3:0]: CH1-4_LO_MODE - 负载开路检测模式

#### 0x04 - Channel State Control
- bit[7:6]: CH4_STATE (00=PLAY, 01=Hi-Z, 10=MUTE, 11=DC_DIAG)
- bit[5:4]: CH3_STATE
- bit[3:2]: CH2_STATE
- bit[1:0]: CH1_STATE

#### 0x11 - Global Faults 1
- bit[4]: INVALID_CLOCK - 时钟错误
- bit[3]: PVDD_OV - PVDD过压
- bit[2]: VBAT_OV - VBAT过压
- bit[1]: PVDD_UV - PVDD欠压
- bit[0]: VBAT_UV - VBAT欠压

#### 0x21 - Misc Control 3
- bit[7]: CLEAR_FAULT - 清除锁存故障
- bit[3]: OTSD_AUTO_RECOVERY - 过温自动恢复

## 4. 状态机设计

### 4.1 主状态机状态

| 状态 | 编码 | 描述 |
|------|------|------|
| STANDBY | 3'b000 | 待机：FETs高阻，振荡器关闭，I2C活跃 |
| HI_Z | 3'b001 | Hi-Z：FETs高阻，振荡器工作，I2C工作 |
| MUTE | 3'b010 | 静音：FETs 50%占空比开关 |
| PLAY | 3'b011 | 播放：FETs音频调制开关 |
| DIAG | 3'b100 | DC负载诊断 |

### 4.2 状态转换条件

#### 正常工作流程
1. 上电/POR → STANDBY
2. STANDBY + standby_n=1 → HI_Z
3. HI_Z + 0x04配置(非11) → MUTE/PLAY
4. MUTE/PLAY + 0x04配置=11 → DIAG
5. DIAG完成 → HI_Z
6. 任意状态 + standby_n=0 → STANDBY

#### 故障处理流程
1. 任意状态 + 全局故障(POR/UV/OV/OTSD) → HI_Z
2. HI_Z + 全局故障 → 0x04指示 + 自诊断
3. 自诊断完成 → HI_Z
4. 通道故障(OC/DC) → 对应通道进入Hi-Z，其他通道不变
5. CLEAR_FAULT(0x21 bit7) → 清除锁存故障

## 5. 模块接口

### 5.1 i2c_slave
- I2C协议从机，7位地址（由i2c_addr0/1选择）
- 输出：reg_wr_en, reg_wr_addr, reg_wr_data, reg_rd_en, reg_rd_addr, reg_rd_data
- 支持100/400kbps，时钟同步，START/STOP检测

### 5.2 register_file
- 地址空间0x00-0x79
- I2C写接口 + I2C读接口
- 内部硬件写接口（故障/诊断/状态报告寄存器）
- 内部硬件读接口（配置寄存器输出到各模块）

### 5.3 state_machine
- 输入：standby_n引脚, 0x04寄存器, 故障信号, 诊断完成信号
- 输出：chip_state[2:0], 诊断触发信号
- 两段式FSM：状态寄存器 + 组合逻辑下一状态

### 5.4 channel_fsm
- 4个实例，每通道独立
- 输入：chip_state, ch_state_ctrl[1:0], ch_fault, clear_fault
- 输出：ch_state[1:0], ch_en(通道使能), ch_diag_req

### 5.5 audio_interface
- 输入：MCLK, SCLK, FSYNC, SDIN1, SDIN2, sap_mode[2:0]
- 输出：audio_data_ch1~4 [23:0]
- 支持8种模式（I2S/LJ/DSP/TDM等）

### 5.6 pwm_generator
- 输入：audio_data_ch1~4, ch_en, ch_state, pwm_freq[2:0]
- 输出：out_1p/1m ~ out_4p/4m
- PLAY态：音频数据PWM调制
- MUTE态：50%占空比方波

### 5.7 diagnostic_ctrl
- DC诊断：开路/短路/接地短路/电池短路检测
- AC诊断：阻抗/相位测量
- 输出：dc_diag_report, ac_diag_report, diag_done

### 5.8 fault_monitor
- 监控：OC/DC/OTW/OTSD/UV/OV/CLOCK
- 故障锁存 + CLEAR_FAULT清除
- 输出：hw_ch_faults, hw_global_fault1/2, hw_warnings, fault_irq

### 5.9 pin_control
- STANDBY/MUTE引脚去抖动处理
- FAULT/WARN开漏输出驱动
- 输出：standby_det, mute_det, fault_n, warn_n

### 5.10 clock_monitor
- 监控MCLK/SCLK/FSYNC存在性
- 检测时钟频率异常
- 输出：clock_lost, clock_invalid

### 5.11 protection
- 过温/过压/欠压阈值检测
- OTSD自动恢复控制
- 输出：otw_int, otsd_int, uv_int, ov_int

## 6. 设计规范

### 6.1 时钟与复位
- 统一使用上升沿触发
- 异步复位，同步释放（rst_n低有效）
- 所有状态机复位到STANDBY/IDLE态
- POR(pad_rst_n)触发全局复位

### 6.2 编码规范
- 模块名：小写+下划线
- 信号名：小写+下划线
- 参数名：全大写+下划线
- 寄存器信号：_reg后缀
- 组合逻辑输出：_next后缀
- 4空格缩进
- 避免锁存器，避免组合逻辑环路

### 6.3 测试场景
1. **正常流程**：POR → STANDBY → HI_Z → PLAY → MUTE → HI_Z
2. **I2C读写**：所有寄存器读写验证
3. **DC诊断**：触发诊断并检查报告
4. **故障注入**：OC/DC/UV/OV/OTSD/时钟丢失
5. **故障恢复**：CLEAR_FAULT后恢复到正常状态
6. **引脚控制**：STANDBY/MUTE引脚响应
7. **音频播放**：I2S输入→PWM输出验证
